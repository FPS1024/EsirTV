FROM node:20-alpine

WORKDIR /opt/esirtv/server

COPY server/package.json server/package-lock.json ./
RUN npm install --omit=dev

COPY server/server.js ./
COPY www ../www

RUN mkdir -p /data

ENV PORT=8080
ENV SETTINGS_FILE=/data/settings.json
ENV DB_FILE=/data/esirtv.db

EXPOSE 8080

CMD ["node", "server.js"]
