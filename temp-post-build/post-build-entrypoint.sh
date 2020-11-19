#!/bin/sh -e

set -x

# This one comes from the quay.io/overbaard/ob-ci-action-tooling Docker image
source /ci-tool-common.sh

############################################################
# Input variables and validation
############################################################
COMPONENT="${INPUT_COMPONENT}"
IS_BUILD_JOB=${INPUT_BUILD}
IS_CUSTOM_COMPONENT=${INPUT_CUSTOM}
SNAPSHOTS=${INPUT_SNAPSHOTS}

echo "COMPONENT: ${COMPONENT}"
echo "IS_BUILD_JOB: ${IS_BUILD_JOB}"
echo "IS_CUSTOM_COMPONENT: ${IS_CUSTOM_COMPONENT}"
echo "SNAPSHOTS: ${SNAPSHOTS}"


if [[ -z "${COMPONENT}" ]]; then
  logError "'component' input can not be empty!"
fi
if [[ -z "${SNAPSHOTS}" ]]; then
  logError "'snapshots' input can not be empty!"
fi
if [[ "${IS_BUILD_JOB}" != "0" && "${IS_BUILD_JOB}" != "1" ]]; then
  logError "expected 0 or 1 for 'build' input!"
  exit 1
fi
if [[ "${IS_CUSTOM_COMPONENT}" != "0" && "${IS_CUSTOM_COMPONENT}" != "1" ]]; then
  logError "expected 0 or 1 for 'custom' input!"
  exit 1
fi
if [[ "${IS_BUILD_JOB}" == "0" && "${IS_CUSTOM_COMPONENT}" == "0" ]]; then
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

# makeObArtifactsAndStatusAbsolutePaths() {
#   if [[ ${IS_CUSTOM_COMPONENT} == "1" ]]; then
#     echo "Converting \$OB_ARTIFACTS_DIR and \$OB_STATUS_TEXT to absolute paths"

#     echo "OB_ARTIFACTS_DIR=${GITHUB_WORKSPACE}/${OB_ARTIFACTS_DIR}" >> "${GITHUB_ENV}"
#     echo "OB_STATUS_TEXT=${GITHUB_WORKSPACE}/${OB_STATUS_TEXT}" >> "${GITHUB_ENV}"

#     if [[ ! -d "${OB_ARTIFACTS_DIR}" ]]; then
#       echo "No \$OB_ARTIFACTS_DIR directory found, creating it"
#       mkdir -p "${OB_ARTIFACTS_DIR}"
#     fi

#     if [[ ! -d "${{OB_STATUS_TEXT}} " ]]; then
#       echo "No \$OB_STATUS_TEXT file found, creating it"
#       touch "${OB_STATUS_TEXT}"
#     fi
#   fi
# }

# pushArtifactsBranch() {
#   echo "Backng up artifacts"
#   cd .ci-tools
#   git config --local user.name "CI Action"
#   git config --local user.email "ci@example.com"

#   ${OB_STATUS_TEXT}
#   if [[ -f "${OB_STATUS_TEXT}" ]] && [[ ! -s "${OB_STATUS_TEXT}" ]] ; then
#     echo "Removing empty \$OB_STATUS_TEXT file"
#     rm "${OB_STATUS_TEXT}"
#   fi

#   git add -A
#   branch_status=$(git status --porcelain)
#   if [[ -n "${branch_status}" ]]; then
#     echo "Committing artifact changes"
#     git commit -m "Back up the artifacts created by wildfly-core"

#     TMP=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')

#     echo "Fetching origin ${TMP} branch..."
#     git fetch origin ${TMP}

#     echo "Rebasing on origin/${TMP}..."
#     git rebase origin/${TMP}

#     echo "Pushing origin ${TMP}..."
#     git push origin ${TMP}
#   else
#      echo "No changes"
#   fi
# }

splitLargeFilesInArtifactsDirectory() {
  if [[ ${IS_CUSTOM_COMPONENT} == "1" ]]; then
    /multi-repo-ci-tool-runner split-large-files-in-directory ${OB_ARTIFACTS_DIR}
  fi
}

pushToCache() {
  if [[ "${IS_BUILD_JOB}" == "1" ]]; then
    what_to_add="-A"
  elif [[ "${IS_CUSTOM_COMPONENT}" == "1" ]]; then
    # For custom component non-build jobs we only back up the $OB_ARTIFACTS_DIR directory
    what_to_add="${OB_ARTIFACTS_DIR}"
  fi

  if [[ -n "${what_to_add}" ]]; then
    cd .ci-tools
    git config --global user.email "you@example.com"
    git config --global user.name "Your Name"

    git add "${what_to_add}"
    branch_status=$(git status --porcelain)
    if [[ -n ${branch_status} ]]; then
      git commit -m "Store any artifacts copied to \${OB_ARTIFACTS_DIR} by wildfly-core-ts-smoke"
      TMP=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
      git fetch origin ${TMP}
      git rebase origin/${TMP}
      git push origin ${TMP}
    else
     echo "No changes"
    fi
    cd ${GITHUB_WORKSPACE}
  fi
}

copySnapshotsToCache() {
  if [[ "$IS_BUILD_JOB" == 1 ]]; then

    # Temp
    echo "It is build job"
    echo "ls -al"
    ls -al
    echo "ls -al ${GITHUB_WORKSPACE}"
    ls -al ${GITHUB_WORKSPACE}


    snapshots="${GITHUB_WORKSPACE}/${SNAPSHOTS}"

    if [[ -f ${snapshots} ]]; then
      temp_repo="$(mktemp -d)"
      cd "${temp_repo}"

      echo "Untarring ${snapshots} to ${temp_repo}"

      tar xfzv "${snapshots}"
      cd "${GITHUB_WORKSPACE}"
      rm "${snapshots}"
      # This does some further trimming just for our snapshots, but might not be needed if we just do them all in one go
      /multi-repo-ci-tool-runner backup-maven-artifacts ./pom.xml "${temp_repo}" .ci-tools/repo-backups/${COMPONENT}
    else
      echo "No file containing snapshots found: ${snapshots}"
    fi
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
echo "Current directory $(pwd) contents":
ls -al


checkCheckedOutRepo

splitLargeFilesInArtifactsDirectory
copySnapshotsToCache
pushToCache


echo "Action done!"
# Disable the EXIT trap set by /ci-tool-common.sh
trap - EXIT
