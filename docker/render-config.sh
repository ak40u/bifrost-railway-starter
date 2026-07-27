#!/bin/sh
# Puts the configuration where Bifrost expects it, then starts the gateway.
#
# Bifrost reads config.json from APP_DIR at boot. The file is copied in at start
# rather than baked into the image, so an upgrade of this template actually
# replaces it - and so nothing has to be persisted between deploys: providers,
# keys and logs all live in Postgres.
set -eu

APP_DIR="${APP_DIR:-/app/data}"

if [ -z "${PGHOST:-}" ]; then
  echo "PGHOST is not set. Bifrost stores its configuration in Postgres and cannot start without it." >&2
  exit 1
fi

if [ -z "${BIFROST_ADMIN_PASSWORD:-}" ]; then
  echo "BIFROST_ADMIN_PASSWORD is not set. Refusing to start an unauthenticated gateway on a public address." >&2
  exit 1
fi

mkdir -p "$APP_DIR"
cp /app/config.template.json "$APP_DIR/config.json"

exec /app/docker-entrypoint.sh "$@"
