FROM quay.io/overbaard/ob-ci-action-tooling:dev

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY generator-entrypoint.sh /generator-entrypoint.sh

ENTRYPOINT ["/generator-entrypoint.sh"]
