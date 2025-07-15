###
# Build stage
###
FROM debian:bullseye AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG TINKEY_VERSION=1.11.0
ARG KUBECTL_VERSION=1.33
ARG HELM_VERSION=3.15.0-1
ARG K3D_VERSION=v5.6.3

# Install  build‑time utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        bash \
        sudo \
        gnupg \
        dirmngr \
        openssl \
        apt-transport-https && \
    mkdir -p /etc/apt/keyrings && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl & Helm (track latest patch in specified minor series)
RUN set -eux; \
    # Add Kubernetes apt repo for the desired minor version (e.g. 1.33)
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBECTL_VERSION}/deb/Release.key" | \
      gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] \
          https://pkgs.k8s.io/core:/stable:/v${KUBECTL_VERSION}/deb/ /" \
          > /etc/apt/sources.list.d/kubernetes.list; \
    \
    # Add Helm repo key once
    curl -fsSL https://baltocdn.com/helm/signing.asc | \
      gpg --dearmor -o /etc/apt/keyrings/helm.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/helm.gpg] \
          https://baltocdn.com/helm/stable/debian/ all main" \
          > /etc/apt/sources.list.d/helm.list; \
    \
    # Install kubectl (latest patch in the 1.33 series) and a specific Helm version
    apt-get update && \
    apt-get install -y --no-install-recommends \
        kubectl \
        helm=${HELM_VERSION} && \
    \
    # Clean up build-time packages and APT cache
    apt-get purge -y --auto-remove gnupg dirmngr && \
    rm -rf /var/lib/apt/lists/*

# Install k3d (install from official release)
RUN set -eux; \
    # Map host architecture to k3d release architecture (per official install script)
    ARCH=$(uname -m); \
    case "$ARCH" in \
      armv5*)   ARCH="armv5"  ;; \
      armv6*)   ARCH="armv6"  ;; \
      armv7*)   ARCH="arm"    ;; \
      aarch64)  ARCH="arm64"  ;; \
      arm64)    ARCH="arm64"  ;; \
      x86)      ARCH="386"    ;; \
      x86_64)   ARCH="amd64"  ;; \
      i686)     ARCH="386"    ;; \
      i386)     ARCH="386"    ;; \
      *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac; \
    OS=$(uname | tr '[:upper:]' '[:lower:]'); \
    curl --proto "=https" --tlsv1.2 --fail --show-error -fsSL \
      "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-${OS}-${ARCH}" \
      -o /usr/local/bin/k3d; \
    chmod +x /usr/local/bin/k3d

# Install Tinkey
RUN curl -fsSL -o /tmp/tinkey.tgz \
    https://storage.googleapis.com/tinkey/tinkey-${TINKEY_VERSION}.tar.gz && \
    tar -xzf /tmp/tinkey.tgz -C /usr/local/bin tinkey tinkey_deploy.jar && \
    chmod +x /usr/local/bin/tinkey && \
    rm /tmp/tinkey.tgz

###
# Runtime stage
###
FROM debian:bullseye
ARG DEBIAN_FRONTEND=noninteractive

# Install Docker CLI (no dockerd) + minimal runtime deps
RUN apt-get update; \
    # prerequisites for adding Docker’s official repository
    apt-get install -y --no-install-recommends curl gnupg ca-certificates; \
    mkdir -p /etc/apt/keyrings; \
    # add and trust Docker’s GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
         https://download.docker.com/linux/debian bullseye stable" \
         > /etc/apt/sources.list.d/docker.list; \
    # install CLI & other runtime packages
    apt-get update; \
    apt-get install -y --no-install-recommends \
        docker-ce-cli \
        bash \
        sudo \
        curl \
        openssl \
        openjdk-17-jre-headless; \
    # purge build‑only deps (gnupg) and clean up
    apt-get purge -y --auto-remove gnupg; \
    rm -rf /var/lib/apt/lists/*

# Copy compiled binaries from build stage
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/bin/kubectl /usr/local/bin/
COPY --from=builder /usr/bin/helm /usr/local/bin/

# Non‑root user setup (recommended)
RUN useradd -m -s /bin/bash gdcn && \
    echo "gdcn ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/gdcn

WORKDIR /workspace
USER gdcn

# Container acts as a long‑running bootstrap target
CMD ["sleep", "infinity"]
