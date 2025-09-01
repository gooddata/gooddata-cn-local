# GoodData.CN Sandbox

Spin up a self‑contained GoodData.CN sandbox in minutes.
Great for demos, PoCs, or learning the platform.

> **This deployment is strictly for testing and exploration – not production.**
> It spins up a lightweight Kubernetes cluster and installs GoodData.CN so you
> can kick the tires in ~15 minutes on any machine that can run Docker.

## How It Works

* A small **bootstrap** container holds the tools (`k3d`, `kubectl`, etc.).
* This container creates a K3s cluster using **k3d** which runs **on the host**, not inside the
  bootstrap container.

## Quickstart

> **Note**: This Helm chart pulls Docker images from Docker Hub, which is [rate limited](https://www.docker.com/increase-rate-limit). If you encounter 429 errors when pulling images and you have a Docker account, you can optionally pass your Docker username and password/PAT during setup.

### 1. **Prerequisites**

  - macOS or Linux
  - Docker (allocate at least 14 GB of memory to the Docker Engine)
  - `curl`, `git`, and (optionally) `lsof`
  - Host ports **80**, **5001**, and **6443** free

  Here's an example on how to configure these prerequisites on a clean Debian Linux installation:

  ```bash
  # Install packages
  sudo apt update && sudo apt install -y curl git lsof

  # Install Docker
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker $USER
  newgrp docker

  # Verify ports are unused (output of command is blank)
  lsof -nP -iTCP:80   -sTCP:LISTEN
  lsof -nP -iTCP:5001 -sTCP:LISTEN
  lsof -nP -iTCP:6443 -sTCP:LISTEN
  ```

### 2. **Clone & launch setup**

```bash
git clone https://github.com/gooddata/gooddata-cn-local.git
cd gooddata-cn-local
./shell.sh up
```

`./shell.sh up` builds (or re‑attaches to) the bootstrap container and drops you into an interactive shell that already has **k3d**, **kubectl**, **helm**, and other utilities installed.

### 3. **Create the cluster**

Inside the bootstrap container, run:

```bash
./setup.sh
```

The script will ask you for a few details about the POC setup.

**Note:** This POC is configured to serve requests on HTTP only. If running remotely, it's recommended to access the instance via some secure method (i.e. VPN or SSH port forwarding).

This script spins up a K3d cluster called **gdcluster** and installs GoodData.CN into it.

### 4. **Open the UI**

Navigate to the hostname you configured (defaults to [`http://localhost`](http://localhost)) and log in with the credentials you provided during setup.

### 5. Everyday Commands (inside the toolbox shell)

| Action | Command | Description |
|--------|---------|-------------|
| Create cluster from scratch | `./setup.sh` | Interactive setup: creates k3d cluster and installs GoodData.CN |
| Stop cluster | `k3d cluster stop gdcluster` | Stops the k3d cluster |
| Start cluster | `k3d cluster start gdcluster` | Starts the k3d cluster |
| Delete cluster | `k3d cluster delete gdcluster` | Deletes the k3d cluster and its resources |
| Re‑enter toolbox shell from host | `./shell.sh up` | Attaches to (or creates) the toolbox container and opens a shell |
| Stop toolbox container | `./shell.sh stop` | Stops the toolbox container if it is running |
| Remove toolbox container | `./shell.sh rm` | Confirms, then stops and removes the toolbox container (not the cluster) |

### 6. Upgrade GoodData.CN

If you want to upgrade to a newer GoodData.CN version:

1. Look for the latest releases in the [release notes](https://www.gooddata.com/docs/cloud-native/latest/whats-new-cn/) and note any breaking changes.
1. Make any changes to the `./setup/values-gdcn.yaml`.
1. Run the upgrade (replacing RELEASE_VERSION with a version like `3.36.0`):

    ```bash
    helm repo update
    GDCN_VERSION=<RELEASE_VERSION>
    helm upgrade --namespace gooddata-cn \
      --version $GDCN_VERSION \
      -f ./values-gdcn.yaml \
      gooddata-cn gooddata/gooddata-cn
    ```

**Pro tip:** Before upgrading, you can preview what will change in your deployment by using the Helm Diff plugin:
  ```bash
  helm plugin install https://github.com/databus23/helm-diff

  # Show a colorized diff of the upgrade
  helm repo update
  GDCN_VERSION=<RELEASE_VERSION>
  helm diff upgrade --color --namespace gooddata-cn \
    --version $GDCN_VERSION \
    -f values-gdcn.yaml \
    gooddata-cn gooddata/gooddata-cn
  ```
