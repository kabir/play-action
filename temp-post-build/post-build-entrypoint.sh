#!/bin/sh -e

# This one comes from the quay.io/overbaard/ob-ci-action-tooling Docker image
source /ci-tool-common.sh

############################################################
# Input variables and validation
############################################################
COMPONENT="${1}"
IS_BUILD_JOB="${2}"
IS_CUSTOM_COMPONENT="${3}"

if [[ -z "${COMPONENT}" ]]; then
  logError "'component' input can not be empty!"
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

pushArtifactsBranch() {
  echo "Backng up artifacts"
  cd .ci-tools
  git config --local user.name "CI Action"
  git config --local user.email "ci@example.com"

  ${OB_STATUS_TEXT}
  if [[ -f "${OB_STATUS_TEXT}" ]] && [[ ! -s "${OB_STATUS_TEXT}" ]] ; then
    echo "Removing empty \$OB_STATUS_TEXT file"
    rm "${OB_STATUS_TEXT}"
  fi

  git add -A
  branch_status=$(git status --porcelain)
  if [[ -n "${branch_status}" ]]; then
    echo "Committing artifact changes"
    git commit -m "Back up the artifacts created by wildfly-core"

    TMP=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')

    echo "Fetching origin ${TMP} branch..."
    git fetch origin ${TMP}

    echo "Rebasing on origin/${TMP}..."
    git rebase origin/${TMP}

    echo "Pushing origin ${TMP}..."
    git push origin ${TMP}
  else
     echo "No changes"
  fi
}

############################################################
# Main code
############################################################
echo Performing pre-build preparation work

# Temporary
cat ${GITHUB_EVENT_PATH}
checkCheckedOutRepo

# Split large files
/multi-repo-ci-tool-runner split-large-files-in-directory ${OB_ARTIFACTS_DIR}
if [[ "$IS_BUILD_JOB" == 1 ]]; then
  /multi-repo-ci-tool.jar backup-maven-artifacts ./pom.xml .m2/repository .ci-tools/repo-backups/${COMPONENT}
fi

# Push the branch with the a
# Run multi-repo-ci-tool 'split-large-files-in-directory' command
# Backup maven artifacts (builds only)
# Git command-line work (push the .citools stuff)
