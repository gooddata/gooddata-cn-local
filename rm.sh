#!/usr/bin/env sh
set -e

CONTAINER=gdcn-local-bootstrap

echo "This will stop and remove the bootstrap container '$CONTAINER'."
printf "Are you sure you want to continue? [y/N]: "
read -r confirm

case "$confirm" in
[yY][eE][sS] | [yY])
  if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
    echo "Stopping and removing '$CONTAINER'..."
    docker rm -f "$CONTAINER"
    echo "Container '$CONTAINER' removed."
  else
    echo "Container '$CONTAINER' does not exist."
  fi
  ;;
*)
  echo "Aborted."
  ;;
esac
