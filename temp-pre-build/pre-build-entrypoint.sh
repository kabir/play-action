#!/bin/sh -e

# This one comes from the quay.io/overbaard/ob-ci-action-tooling Docker image
source /ci-tool-common.sh

############################################################
# Input variables and validation
IS_BUILD_JOB="${1}"
IS_CUSTOM_COMPONENT="${1}"

if [[ "${IS_BUILD_JOB}" != "0" && "${IS_BUILD_JOB}" != "1" ]]; then
  logError expected 0 or 1 for 'build' input!
  exit 1
fi
if [[ "${IS_CUSTOM_COMPONENT}" != "0" && "${IS_CUSTOM_COMPONENT}" != "1" ]]; then
  logError expected 0 or 1 for 'custom' input!
  exit 1
fi
if [[ "${IS_BUILD_JOB}" == "0" && "${IS_CUSTOM_COMPONENT}" == "0" ]]; then
  logError build=0 and custom=0 is an invalid combination!
  exit 1
fi

############################################################
# Functions

checkCheckedOutRepo() {
  echo Checking we have checked out ${GITHUB_ACTION_REPOSITORY}...
  if [[ ! -d ".git" ]]; then
    echo "Before using this action you need to use the checkout action as follows:"
    echo
    echo "- uses: actions/checkout@v2"
    echo "    with:"
    echo "      token: \${{ secrets.OB_MULTI_CI_PAT }}"

    exit 1
  else
    echo Have checked out ${GITHUB_ACTION_REPOSITORY}.
  fi
}

addIPv6LocalhostToEtcHosts() {
  echo "Checking if /etc/hosts has the '::1 localhost' mapping. GitHub's runners miss this entry"
  set +e
  TMP=$(grep localhost /etc/hosts)
  TMP=$(echo ${TMP} | grep "^::1\s")
  set -e

  if [[ -n "${TMP}" ]]; then
    sudo bash -c 'echo ::1 localhost >> /etc/hosts'
  fi
}

setSha1OutputVariable() {
  if [[ ${IS_BUILD_JOB} == "1" ]]; then
    echo "Parsing SHA-1 into \$git-sha output variable"
    TMP=$(git rev-parse HEAD)
    echo "::set-output name=git-sha::${TMP}"
    echo set 'git-sha' output variable to ${TMP}
    # TODO This might be better to do later on for the workflow as a whole
    # tmpfile=$(mktemp)
    # jq --arg sha "${TMP}" '.components["wildfly-core"].sha=$sha' "${OB_ISSUE_DATA_JSON}" > "${tmpfile}"
    # mv "${tmpfile}" "${OB_ISSUE_DATA_JSON}"
  fi
}

setProjectVersionOutputVariable() {
  if [[ ${IS_BUILD_JOB} == "1" ]]; then
    echo "Parsing project version"
    TMP=/multi-repo-ci-tool-runner grab-maven-project-version ./pom.xml
    echo "::set-output name=version::${TMP}"
    echo set 'version' output variable to ${TMP}
  fi
}

refreshStorageCache() {
  if [[ -z "${OB_MAVEN_DEPENDENCY_VERSIONS}" ]]; then
    echo "Refreshing storage cache"
    cd .ci-tools
    TMP=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
    git fetch origin ${TMP}
    git rebase origin/${TMP}
    cd "${GITHUB_WORKSPACE}"
  fi
}

overlaySnapshotsOnLocalMavenRepo() {
  if [[ -z "${OB_MAVEN_DEPENDENCY_VERSIONS}" ]]; then
    echo "Overlaying snapshots from previous jobs "
    /multi-repo-ci-tool-runner overlay-backed-up-maven-artifacts ${GITHUB_WORKSPACE}/.m2/repository .ci-tools/repo-backups
  fi
}

makeObArtifactsAndStatusAbsolutePaths() {
  if [[ ${IS_CUSTOM_COMPONENT} == "1" ]]; then
    echo "Converting \$OB_ARTIFACTS_DIR and \$OB_STATUS_TEXT to absolute paths"

    echo "OB_ARTIFACTS_DIR=${GITHUB_WORKSPACE}/${OB_ARTIFACTS_DIR}" >> "${GITHUB_ENV}"
    echo "OB_STATUS_TEXT=${GITHUB_WORKSPACE}/${OB_STATUS_TEXT}" >> "${GITHUB_ENV}"

    if [[ ! -d "${OB_ARTIFACTS_DIR}" ]]; then
      echo "No \$OB_ARTIFACTS_DIR directory found, creating it"
      mkdir -p "${OB_ARTIFACTS_DIR}"
    fi

    if [[ ! -d "${{OB_STATUS_TEXT}} " ]]; then
      echo "No \$OB_STATUS_TEXT file found, creating it"
      touch "${OB_STATUS_TEXT}"
    fi
  fi
}

mergeLargeFilesInArtifactsDirectory() {
  if [[ "${IS_CUSTOM_COMPONENT}" == "1" ]]; then
    /multi-repo-ci-tool-runner merge-large-files-in-directory "${OB_ARTIFACTS_DIR}"
  fi
}

############################################################
# Main code


echo Performing pre-build preparation work

# Temporary
cat ${GITHUB_EVENT_PATH}
checkCheckedOutRepo

refreshStorageCache
overlaySnapshotsOnLocalMavenRepo
setProjectVersionOutputVariable
setSha1OutputVariable
addIPv6LocalhostToEtcHosts
makeObArtifactsAndStatusAbsolutePaths
mergeLargeFilesInArtifactsDirectory
