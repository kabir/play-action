#!/bin/sh -l

# cat ${GITHUB_EVENT_PATH}
checkCheckedOutRepo()


# Functions

function checkCheckedOutRepo() {
  if [[ ! -d ".git" ]]; then
    echo Before using this action you need to use the checkout action as follows:
    echo
    echo "- uses: actions/checkout@v2"
    echo "    with:"
    echo "      token: $\{\{ secrets.OB_MULTI_CI_PAT \}\}"

    exit 1
  fi
}


