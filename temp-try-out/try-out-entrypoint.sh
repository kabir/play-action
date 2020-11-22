#!/bin/sh -e

set -x

# This one comes from the quay.io/overbaard/ob-ci-action-tooling Docker image
source /ci-tool-common.sh


mkdir -p .m2-repo-mount/try-out
echo From docker >> .m2-repo-mount/try-out/txt

echo Created file, current perms
ls -al .m2-repo-mount/try-out

echo Change perms
sudo chown -R runner  ~/.m2/
sudo chgrp -R docker
ls -al .m2-repo-mount/try-out
