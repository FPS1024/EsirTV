#!/bin/sh
set -e

DATA_DIR="/data"

mkdir -p "$DATA_DIR" 2>/dev/null || true
chown -R node:node "$DATA_DIR" 2>/dev/null || true

exec su-exec node node server.js

