#!/usr/bin/env sh
set -e

CONTAINER=gdcn-local-bootstrap

usage() {
  echo "Usage: $0 {up|stop|rm}"
  exit 1
}

cmd="${1:-}"
if [ -z "$cmd" ]; then
  usage
fi

case "$cmd" in
  up)
    # If the bootstrap container already exists just (re)attach to it
    if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
      echo "Found existing container: $CONTAINER"
      # Start it if it's not running
      if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" != "true" ]; then
        echo "Starting container $CONTAINER ..."
        docker start "$CONTAINER"
      fi
      echo "Attaching to $CONTAINER ..."
      docker exec -it "$CONTAINER" bash -c "./permissions.sh"
      docker exec -it "$CONTAINER" bash
      exit 0
    fi

    # Build the base image
    docker build -t gdcn-local-base:latest .

    # Create a fresh bootstrap container and run cluster setup
    docker run -d --privileged --init \
      --name $CONTAINER \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$(pwd)/setup":/workspace -w /workspace \
      -v "$(pwd)/../../github.com/gooddata/gdc-nas":/gdc-nas \
      -e HOST_PWD="$(pwd)" \
      --add-host=host.docker.internal:host-gateway \
      gdcn-local-base:latest \
      bash -c "sleep infinity"

    docker exec -it "$CONTAINER" bash -c "./permissions.sh"
    docker exec -it "$CONTAINER" bash
    ;;
  stop)
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
    ;;
  rm)
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
    ;;
  *)
    usage
    ;;
esac
