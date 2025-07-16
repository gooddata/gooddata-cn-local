#!/usr/bin/env sh
set -e

CONTAINER=gdcn-local-bootstrap

# If the bootstrap container already exists just (re)attach to it
if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "Found existing container: $CONTAINER"
  # Start it if it's not running
  if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" != "true" ]; then
    echo "Starting container $CONTAINER ..."
    docker start "$CONTAINER"
  fi
  echo "Attaching to $CONTAINER ..."
  docker exec -it "$CONTAINER" bash
  exit 0
fi

# Build the base image
docker build -t gdcn-local-base:latest .

# Create a fresh bootstrap container and run cluster setup
docker run -d --privileged \
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
