FROM quay.io/overbaard/ob-ci-action-tooling:dev

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY post-build-entrypoint.sh /post-build-entrypoint.sh

ENTRYPOINT ["/post-build-entrypoint.sh"]