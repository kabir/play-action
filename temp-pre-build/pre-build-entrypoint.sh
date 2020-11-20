#!/bin/sh -e

set -x

# This one comes from the quay.io/overbaard/ob-ci-action-tooling Docker image
source /ci-tool-common.sh

############################################################
# Input variables and validation
############################################################
IS_BUILD_JOB=${INPUT_BUILD}
IS_CUSTOM_COMPONENT=${INPUT_CUSTOM}

echo "IS_BUILD_JOB: ${IS_BUILD_JOB}"
echo "IS_CUSTOM_COMPONENT: ${IS_CUSTOM_COMPONENT}"


if [[ "${IS_BUILD_JOB}" != "0" && "${IS_BUILD_JOB}" != "1" ]]; then
  echo "DEBUG bad 'build arg'"
  logError "expected 0 or 1 for 'build' input!"
  exit 1
fi
if [[ "${IS_CUSTOM_COMPONENT}" != "0" && "${IS_CUSTOM_COMPONENT}" != "1" ]]; then
  echo "DEBUG bad 'component arg'"
  logError "expected 0 or 1 for 'custom' input!"
  exit 1
fi
if [[ "${IS_BUILD_JOB}" == "0" && "${IS_CUSTOM_COMPONENT}" == "0" ]]; then
  echo "DEBUG bad 'build and custom combo'"

  logError "build=0 and custom=0 is an invalid combination!"
  exit 1
fi

############################################################
# Functions
############################################################
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
    echo "Adding '::1 localhost' to /etc/hosts"
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
    TMP=$(/multi-repo-ci-tool-runner grab-maven-project-version ./pom.xml)
    echo "::set-output name=version::${TMP}"
    echo "set 'version' output variable to ${TMP}"
  fi
}

refreshStorageCache() {
  echo "Refreshing storage cache"
  cd .ci-tools
  TMP=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
  git fetch origin ${TMP}
  git rebase origin/${TMP}
  cd "${GITHUB_WORKSPACE}"
}

# Keep this in case the mounting of ~/.m2/repository to .m2-repo-mount in the runner bends too many rules
# tarDownloadedSnapshots() {
#   # We don't have access to the runner's .m2/ directory from here, so work around that
#   # by using a temporary directory that we will move into the $GITHUB_WORKSPACE
#   if [[ -d ".ci-tools/repo-backups" && -n "$(ls -A .ci-tools/repo-backups)" ]]; then
#     tmp="$(mktemp -d)"

#     echo "Overlaying snapshots from previous jobs"
#     /multi-repo-ci-tool-runner overlay-backed-up-maven-artifacts ${tmp} .ci-tools/repo-backups

#     # Create the tar
#     cd "${tmp}"

#     # TMP
#     echo "In tmp folder ${tmp}. Directory contents:"
#     ls -al
#     echo "Trying to tar"

#     tar cvfz "${GITHUB_WORKSPACE}/.snapshots.tgz" .
#     echo "Tarred"
#     cd "${GITHUB_WORKSPACE}"
#     echo "Back in workspace"
#     rm -rf "${tmp}"
#     echo "Removed tmp dir"
#     # If we reintroduce this we need to add snapshots-tar as an output variable to action.yml again
#     echo "::set-output name=snapshots-tar::.snapshots.tgz"
#     echo "Output variable set"
#   fi
# }
overlayDownloadedSnapshots() {
  # We don't have access to the runner's .m2/ directory from here, so work around that
  # by using a temporary directory that we will move into the $GITHUB_WORKSPACE
  if [[ -d ".ci-tools/repo-backups" && -n "$(ls -A .ci-tools/repo-backups)" ]]; then
    echo "Overlaying snapshots from previous jobs to .ci-tools/repo-backups"
    /multi-repo-ci-tool-runner overlay-backed-up-maven-artifacts .m2-repo-mount .ci-tools/repo-backups
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

    if [[ ! -d "${OB_STATUS_TEXT} " ]]; then
      echo "No \$OB_STATUS_TEXT file found, creating it"
      touch "${OB_STATUS_TEXT}"
    fi
  fi
}

mergeLargeFilesInArtifactsDirectory() {
  if [[ "${IS_CUSTOM_COMPONENT}" == "1" ]]; then
    echo "Merging split files in \$OB_ARTIFACTS_DIR"
    /multi-repo-ci-tool-runner merge-large-files-in-directory "${OB_ARTIFACTS_DIR}"
  fi
}

############################################################
# Main code
############################################################

echo Performing pre-build preparation work

# Temporary
cat ${GITHUB_EVENT_PATH}
echo "========="
echo ENVIRONMENT:
env
echo "========="

checkCheckedOutRepo

refreshStorageCache
#tarDownloadedSnapshots - replaced by overlayDownloadedSnapshots
overlayDownloadedSnapshots
setProjectVersionOutputVariable
setSha1OutputVariable
addIPv6LocalhostToEtcHosts
makeObArtifactsAndStatusAbsolutePaths
mergeLargeFilesInArtifactsDirectory

echo "Action done!"
# Disable the EXIT trap set by /ci-tool-common.sh
trap - EXIT

# Temp stuff
echo "OB_ARTIFACTS_DIR: ${OB_ARTIFACTS_DIR}"