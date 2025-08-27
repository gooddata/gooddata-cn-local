#!/usr/bin/env sh
set -e

CONTAINER=gdcn-local-bootstrap

if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
  if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = "true" ]; then
    echo "Stopping '$CONTAINER'..."
    docker stop "$CONTAINER" >/dev/null
    echo "Container '$CONTAINER' stopped."
  else
    echo "Container '$CONTAINER' is not running."
  fi
else
  echo "Container '$CONTAINER' does not exist."
fi
