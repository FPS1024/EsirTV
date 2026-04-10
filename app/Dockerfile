FROM node:20-alpine AS web-build

WORKDIR /opt/esirtv/web

COPY web/package.json ./
RUN npm install --no-audit --no-fund

COPY web ./
RUN npm run build

FROM node:20-alpine

WORKDIR /opt/esirtv/server

COPY server/package.json server/package-lock.json ./
RUN apk add --no-cache --virtual .gyp python3 make g++ \
  && npm install --omit=dev --no-audit --no-fund \
  && apk del .gyp

COPY server/server.js ./
COPY --from=web-build /opt/esirtv/web/dist ../web/dist
COPY docker-entrypoint.sh ./

RUN mkdir -p /data \
  && chown -R node:node /opt/esirtv /data

ENV NODE_ENV=production
ENV PORT=8080
ENV SETTINGS_FILE=/data/settings.json
ENV DB_FILE=/data/esirtv.db

EXPOSE 8080

RUN apk add --no-cache su-exec

ENTRYPOINT ["sh", "./docker-entrypoint.sh"]
