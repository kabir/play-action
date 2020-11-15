#!/bin/sh -l

# cat ${GITHUB_EVENT_PATH}

# For now assume the user cloned the repo using the checkout 
if [[ ! -d ".git" ]]; then
  echo Before using this action you need to use the checkout action as follows:
  echo
  echo - uses: actions/checkout@v2
  echo     with:
  echo       # The personal access token must be something which has the workflow permissions
  echo       # (I also used repo, admin:repo_hook and user)
  echo       token: ${{ secrets.OB_MULTI_CI_PAT }}
  
  exit 1
fi
