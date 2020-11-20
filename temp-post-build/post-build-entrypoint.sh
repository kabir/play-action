#!/bin/sh -e

set -x

# This one comes from the quay.io/overbaard/ob-ci-action-tooling Docker image
source /ci-tool-common.sh

############################################################
# Input variables and validation
############################################################
COMPONENT="${INPUT_COMPONENT}"
IS_BUILD_JOB="${INPUT_BUILD}"
IS_CUSTOM_COMPONENT="${INPUT_CUSTOM}"
IS_WORKFLOW_END_JOB="${IS_WORKFLOW_END_JOB}"

echo "COMPONENT: ${COMPONENT}"
echo "IS_BUILD_JOB: ${IS_BUILD_JOB}"
echo "IS_CUSTOM_COMPONENT: ${IS_CUSTOM_COMPONENT}"
echo "IS_WORKFLOW_END_JOB: ${IS_WORKFLOW_END_JOB}"


if [[ -z "${COMPONENT}" ]]; then
  logError "'component' input can not be empty!"
  exit 1
fi
if [[ "${IS_BUILD_JOB}" != "0" && "${IS_BUILD_JOB}" != "1" ]]; then
  logError "expected 0 or 1 for 'build' input!"
  exit 1
fi
if [[ "${IS_CUSTOM_COMPONENT}" != "0" && "${IS_CUSTOM_COMPONENT}" != "1" ]]; then
  logError "expected 0 or 1 for 'custom' input!"
  exit 1
fi
if [[ ${IS_WORKFLOW_END_JOB} != 1 && "${IS_BUILD_JOB}" == "0" && "${IS_CUSTOM_COMPONENT}" == "0" ]]; then
  logError "build=0 and custom=0 is an invalid combination for non workflow end jobs!"
  exit 1
fi
if [[ "${IS_WORKFLOW_END_JOB}" == "1" ]]; then
  if [[ "${IS_BUILD_JOB}" == "1" || "${IS_CUSTOM_COMPONENT}" == "1" ]]; then
    logError "For workflow end jobs 'build' and 'custom' should both be 0!"
    exit 1
  fi
else
  # For normal jobs we clone out the tools repo to .ci_tools/, while for
  # workflow end jobs we clone it to the root workspace directory
  CI_TOOLS=".ci-tools/"
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
    cd "${CI_TOOLS}"
    TMP=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
    git fetch origin ${TMP}
    git rebase origin/${TMP}
    cd "${GITHUB_WORKSPACE}"
  fi
}

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
    artifacts_absolute="${GITHUB_WORKSPACE}/${OB_ARTIFACTS_DIR}"
    ci_tools_absolute="$GITHUB_WORKSPACE/${CI_TOOLS}"
    what_to_add="$(realpath --relative-to=${ci_tools_absolute} ${artifacts_absolute})"
  fi

  if [[ -n "${what_to_add}" ]]; then
    cd "${CI_TOOLS}"
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

# Keep this old version in case the mounting of ~/.m2/repository to .m2-repo-mount in the runner bends too many rules
# copySnapshotsToCache() {
#   if [[ "$IS_BUILD_JOB" == 1 ]]; then
#     # If we reintroduce this we need to add this input variable in action.yml again and parse $INPUT_SNAPSHOTS
#     snapshots="${GITHUB_WORKSPACE}/${SNAPSHOTS}"

#     if [[ -f ${snapshots} ]]; then
#       temp_repo="$(mktemp -d)"
#       cd "${temp_repo}"

#       echo "Untarring ${snapshots} to ${temp_repo}"

#       tar xfzv "${snapshots}"
#       cd "${GITHUB_WORKSPACE}"
#       rm "${snapshots}"
#       # This does some further trimming just for our snapshots, but might not be needed if we just do them all in one go
#       /multi-repo-ci-tool-runner backup-maven-artifacts ./pom.xml "${temp_repo}" ${CI_TOOLS}/repo-backups/${COMPONENT}
#     else
#       echo "No file containing snapshots found: ${snapshots}"
#     fi
#   fi
# }
copySnapshotsToCache() {
  if [[ "$IS_BUILD_JOB" == 1 ]]; then
    # This does some further trimming just for our snapshots, but might not be needed if we just do them all in one go

    # Temp
    echo Contents of .m2-repo-mount
    ls -al .m2-repo-mount

    echo Backing up our snapshots from .m2-repo-mount to ${CI_TOOLS}/repo-backups/${COMPONENT}
    /multi-repo-ci-tool-runner backup-maven-artifacts ./pom.xml .m2-repo-mount ${CI_TOOLS}/repo-backups/${COMPONENT}
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

echo "OB_CI_ARTIFACTS_DIR:  ${OB_ARTIFACTS_DIR}"
echo "OB_STATUS_TEXT:  ${OB_STATUS_TEXT}"


checkCheckedOutRepo

splitLargeFilesInArtifactsDirectory
copySnapshotsToCache
pushToCache


echo "Action done!"
# Disable the EXIT trap set by /ci-tool-common.sh
trap - EXIT

myFunc() {
  echo hello
}

echo one
myFunc
echo two