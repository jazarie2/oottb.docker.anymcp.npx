FROM node:20-alpine

# Install required tools: git for cloning, tini for proper signal handling
RUN apk add --no-cache git tini bash ca-certificates python3 make g++ && update-ca-certificates

ENV NODE_ENV=production \
    APP_HOME=/app

WORKDIR ${APP_HOME}

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Ensure non-root execution (node user exists in node:alpine)
RUN mkdir -p ${APP_HOME} && chown -R node:node ${APP_HOME}
USER node

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]

# Default: no CMD. The entrypoint script performs the clone and starts the server.

