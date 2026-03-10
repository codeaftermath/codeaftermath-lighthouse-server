FROM node:20-alpine

RUN apk add --no-cache tini

RUN npm install -g @lhci/server@0.13.0 && \
    npm cache clean --force

RUN addgroup -S lhci && adduser -S -G lhci lhci

RUN mkdir -p /data && chown lhci:lhci /data

USER lhci

VOLUME ["/data"]

EXPOSE 9001

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:9001/v1/version || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["lhci", "server", \
     "--port=9001", \
     "--storage.storageMethod=sql", \
     "--storage.sqlDialect=sqlite", \
     "--storage.sqlDatabasePath=/data/lhci.db"]
