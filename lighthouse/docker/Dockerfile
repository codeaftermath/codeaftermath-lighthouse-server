FROM node:24-alpine

# Use tini as PID 1 so signals are forwarded correctly and child processes are reaped.
RUN apk add --no-cache tini

# Install Lighthouse CI server + CLI (provides the `lhci` command) and sqlite bindings.
RUN npm install -g @lhci/server@0.15.1 @lhci/cli@0.15.1 sqlite3@5.1.7 && \
    npm cache clean --force

# Persist SQLite database files in /data and grant ownership to the runtime user.
RUN mkdir -p /data && chown node:node /data

# Drop root privileges for runtime.
USER node

# Declare persistent storage mount point.
VOLUME ["/data"]

# Lighthouse CI server listens on port 9001 in the container.
EXPOSE 9001

# Healthcheck endpoint exposed by lhci server.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:9001/version || exit 1

# Start with tini, then run lhci server using SQLite at /data/lhci.db.
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["lhci", "server", \
     "--port=9001", \
     "--storage.storageMethod=sql", \
     "--storage.sqlDialect=sqlite", \
     "--storage.sqlDatabasePath=/data/lhci.db"]
