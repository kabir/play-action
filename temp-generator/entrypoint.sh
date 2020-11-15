#!/bin/sh -l

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

############################################################
# Main code

cat ${GITHUB_EVENT_PATH}
checkCheckedOutRepo

# Get parameters from the event
issue_body="$(jq '.issue.body' ${GITHUB_EVENT_PATH})"
issue_number="$(jq '.issue.number' ${GITHUB_EVENT_PATH})"
issue_title="$(jq '.issue.title' ${GITHUB_EVENT_PATH})"
issue_url="$(jq '.issue.url' ${GITHUB_EVENT_PATH})"

branch="multi-repo-ci-branch-${issue_number}"

############################################################
# Checkout
git checkout -b "${branch}"

############################################################
# Get the issue body into config.yml
touch config.yml
echo "${issue_body}" > config.yml
echo config.yml contents
cat config.yml

############################################################
# Generate the workflow
/multi-repo-ci-tool-runner generate-workflow --workflow-dir=.github/workflows --yaml=config.yml --issue=${issue_number} --branch=${branch}

############################################################
# Update the issue-data.json created by the tool to:
# 1) Contain the user who updated the issue
tmpfile=$(mktemp)
jq --arg user "${GITHUB_ACTOR}" '.["trigger"]["user"]=$user' issue-data.json > "${tmpfile}"
mv "${tmpfile}" issue-data.json
# 2) Contain the url of the issue triggering the workflow
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
fi

############################################################
# Commit and push the workflow to the branch
git add -A
git commit -m "Generated Workflow: #${issue_number} - ${issue_title}"
git push --force origin "${branch}"

