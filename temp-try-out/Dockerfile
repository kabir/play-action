FROM quay.io/overbaard/ob-ci-action-tooling:dev

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY try-out-entrypoint.sh /try-out-entrypoint.sh

ENTRYPOINT ["/try-out-entrypoint.sh"]
