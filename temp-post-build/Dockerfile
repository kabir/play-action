FROM quay.io/overbaard/ob-ci-action-tooling:dev

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# ENTRYPOINT ["/entrypoint.sh"]
# Allows variable substitution
ENTRYPOINT ["sh", "-c", "/post-build-entrypoint.sh $*"]
