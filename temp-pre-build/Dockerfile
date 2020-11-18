FROM quay.io/overbaard/ob-ci-action-tooling:dev

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY pre-build-entrypoint.sh /pre-build-entrypoint.sh

ENTRYPOINT ["/pre-build-entrypoint.sh"]
