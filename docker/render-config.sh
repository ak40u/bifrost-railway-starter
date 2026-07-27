#!/bin/sh
# Renders Bifrost's config.json from environment variables, then starts the
# gateway.
#
# Bifrost reads its configuration from a file in APP_DIR at boot. On a platform
# where the database address and password are injected as variables, that file
# has to be produced at start time - baking it into the image would mean baking
# in a password.
set -eu

APP_DIR="${APP_DIR:-/app/data}"
CONFIG="$APP_DIR/config.json"

mkdir -p "$APP_DIR"

if [ -z "${PGHOST:-}" ]; then
  echo "PGHOST is not set. Bifrost needs a Postgres to store its configuration." >&2
  exit 1
fi

# Both stores point at the same database. The config store holds providers and
# keys - without it the UI has nowhere to save what you configure; the log store
# holds request history, which is what makes the dashboard useful.
cat > "$CONFIG" <<JSON
{
  "\$schema": "https://www.getbifrost.ai/schema",
  "config_store": {
    "enabled": true,
    "type": "postgres",
    "config": {
      "host": "${PGHOST}",
      "port": "${PGPORT:-5432}",
      "user": "${PGUSER:-postgres}",
      "password": "${PGPASSWORD}",
      "db_name": "${PGDATABASE:-railway}",
      "ssl_mode": "${PGSSLMODE:-disable}"
    }
  },
  "logs_store": {
    "enabled": true,
    "type": "postgres",
    "config": {
      "host": "${PGHOST}",
      "port": "${PGPORT:-5432}",
      "user": "${PGUSER:-postgres}",
      "password": "${PGPASSWORD}",
      "db_name": "${PGDATABASE:-railway}",
      "ssl_mode": "${PGSSLMODE:-disable}"
    }
  }
}
JSON

exec /app/docker-entrypoint.sh "$@"
