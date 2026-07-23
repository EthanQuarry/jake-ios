#!/bin/sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
environment_file="$script_directory/.env.local"

if [ ! -f "$environment_file" ]; then
  echo "Missing $environment_file"
  echo "Copy .env.example to .env.local and add the Jake application credentials."
  exit 1
fi

set -a
. "$environment_file"
set +a

exec node "$script_directory/server.mjs"
