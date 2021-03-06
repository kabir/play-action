#!/bin/sh -e

source /ci-tool-common.sh

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

############################################################
# Main code
############################################################
cat ${GITHUB_EVENT_PATH}

echo "========="
echo ENVIRONMENT:
env
echo "========="

# echo "Current directory & contents:"
# pwd
# ls -al

checkCheckedOutRepo
initGit

############################################################
# Get parameters from the event
echo Parsing parameters...

issue_number="$(jq --raw-output '.issue.number' ${GITHUB_EVENT_PATH})"
echo "Issue number: ${issue_number}"
if [[ -z "${issue_number}" ]]; then
  logError "Could not determine issue number"
  exit 1
fi

issue_title="$(jq --raw-output '.issue.title' ${GITHUB_EVENT_PATH})"
echo "Issue title (\$issue_title): ${issue_title}"

issue_url="$(jq --raw-output '.issue.url' ${GITHUB_EVENT_PATH})"
echo "Issue URL (\$issue_url): ${issue_url}"

issue_body="$(jq --raw-output '.issue.body' ${GITHUB_EVENT_PATH})"
# unescape issue body (it contains \r\n entries)
issue_body=$(printf '%b\n' "${issue_body}")
echo "Issue body (\$issue_body):"
echo "${issue_body}"

branch="multi-repo-ci-branch-${issue_number}"
echo "Branch (\$branch): ${branch}"

############################################################
# Checkout and configure
echo "Creating branch ${branch}"
git checkout -b "${branch}"
# git config --global user.email "ci@example.com"
# git config --global user.name "CI Action"


############################################################
# Get the issue body into config.yml
echo "Saving issue body into config.yml"
touch config.yml
echo "${issue_body}" > config.yml
echo "config.yml contents:"
cat config.yml

############################################################
# Generate the workflow
echo "Generating workflow"
# Tmp stuff
echo "Folder: $(pwd) and contents"
ls -al

echo Calling workflow genenerator with arguments:
echo     --workflow-dir=.github/workflows
echo     --yaml=config.yml
echo     --issue=${issue_number}
echo     --branch=${branch}
echo     --working-dir=.

/multi-repo-ci-tool-runner generate-workflow --workflow-dir=.github/workflows --yaml=config.yml --issue=${issue_number} --branch=${branch} --working-dir=.

echo "Workflow genenerator done!"

############################################################
# Update the issue-data.json created by the tool to:
# 1) Contain the user who updated the issue
echo "Set trigger/user=${GITHUB_ACTOR} in issue-data.json"
tmpfile=$(mktemp)
jq --arg user "${GITHUB_ACTOR}" '.["trigger"]["user"]=$user' issue-data.json > "${tmpfile}"
mv "${tmpfile}" issue-data.json
# 2) Contain the url of the issue triggering the workflow
echo "Set trigger/issue=${issue_url} in issue-data.json"
tmpfile=$(mktemp)
jq --arg url "${issue_url}" '.["trigger"]["issue"]=$url' issue-data.json > "${tmpfile}"
mv "${tmpfile}" issue-data.json

############################################################
# Make sure .gitignore exists and that it contains .ci-tools.
# The generated workflow clones the branch from this repository
# into a sub-folder containing it into a sub-folder with this
# name which in turn gives some warnings we don't ignore that
# sub-folder
if [[ ! -f .gitignore ]]; then
  # Make sure .gitignore exists
  touch .gitignore
fi
if ! grep -q .ci-tools .gitignore; then
  # Add .ci-tools to .gitignore
  echo .ci-tools >> .gitignore
  # Add .m2-repo-mount to .gitignore (this will be used to mount the runner ~/.m2/repo
  #for use in our actions )
  echo .m2-repo-mount >> .gitignore
fi

############################################################
# Commit and push the workflow to the branch
echo "Committing generated workflow..."
git add -A
git commit -m "Generated Workflow: #${issue_number} - ${issue_title}"
echo "Pushing to origin ${branch}"
git push --force origin "${branch}"

# Disable the EXIT trap set by /ci-tool-common.sh
echo "Action done!"
trap - EXIT
