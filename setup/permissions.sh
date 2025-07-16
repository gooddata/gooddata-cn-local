#!/usr/bin/env bash
set -euo pipefail

###
# Align in-container permissions for user to access the host Docker socket
###
DOCKER_SOCK_GID=$(stat -c '%g' /var/run/docker.sock)
if [[ "$DOCKER_SOCK_GID" -eq 0 ]]; then
  echo ">> Adjusting Docker socket permissions..."
  sudo chmod 666 /var/run/docker.sock
else
  if ! getent group docker >/dev/null 2>&1; then
    sudo groupadd -g "${DOCKER_SOCK_GID}" docker
  else
    sudo groupmod -g "${DOCKER_SOCK_GID}" docker
  fi
  sudo usermod -aG docker "$(id -un)"
fi
