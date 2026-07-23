#!/bin/sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
environment_file="$script_directory/.env.local"

if [ ! -f "$environment_file" ]; then
  environment_file="$script_directory/.env"
fi

if [ ! -f "$environment_file" ]; then
  echo "Missing $script_directory/.env.local or $script_directory/.env"
  echo "Copy .env.example to either filename and add the Jake application credentials."
  exit 1
fi

set -a
. "$environment_file"
set +a

exec node "$script_directory/server.mjs"
