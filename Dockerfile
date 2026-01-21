FROM debian:trixie

ARG K3D_VERSION=v5.8.3
ARG TINKEY_VERSION=1.12.0
ARG K9S_VERSION=v0.50.9
ARG KUBECTL_VERSION=1.34
ARG HELM_VERSION=v3.18.6
ARG HELM_DIFF_VERSION=v3.12.5

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install base dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        sudo \
        curl \
        ca-certificates \
        gnupg \
        openssl \
        openjdk-21-jre-headless \
        iputils-ping \
        git \
        wget \
        vim && \
    rm -rf /var/lib/apt/lists/*

# Install k3d
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
      armv5*)   ARCH="armv5"  ;; \
      armv6*)   ARCH="armv6"  ;; \
      armv7*)   ARCH="arm"    ;; \
      aarch64|arm64)  ARCH="arm64"  ;; \
      x86)      ARCH="386"    ;; \
      x86_64)   ARCH="amd64"  ;; \
      *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac && \
    OS=$(uname | tr '[:upper:]' '[:lower:]') && \
    curl -fsSL -o /usr/local/bin/k3d \
      "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-${OS}-${ARCH}" && \
    chmod +x /usr/local/bin/k3d

# Install Tinkey
RUN curl -fsSL -o /tmp/tinkey.tgz \
    https://storage.googleapis.com/tinkey/tinkey-${TINKEY_VERSION}.tar.gz && \
    tar -xzf /tmp/tinkey.tgz -C /usr/local/bin tinkey tinkey_deploy.jar && \
    chmod +x /usr/local/bin/tinkey && \
    rm /tmp/tinkey.tgz

# Install Docker CLI (no dockerd) + minimal runtime deps
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
         https://download.docker.com/linux/debian bullseye stable" \
         > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
      amd64) KUBECTL_ARCH="amd64" ;; \
      arm64) KUBECTL_ARCH="arm64" ;; \
      armhf) KUBECTL_ARCH="arm" ;; \
      *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac && \
    curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/v${KUBECTL_VERSION}.0/bin/linux/${KUBECTL_ARCH}/kubectl" && \
    chmod +x /usr/local/bin/kubectl

# Install Helm
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
      amd64) HELM_ARCH="amd64" ;; \
      arm64) HELM_ARCH="arm64" ;; \
      armhf) HELM_ARCH="arm" ;; \
      *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/helm.tar.gz \
      "https://get.helm.sh/helm-${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz" && \
    tar -xzf /tmp/helm.tar.gz -C /tmp && \
    mv /tmp/linux-${HELM_ARCH}/helm /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm && \
    rm -rf /tmp/helm.tar.gz /tmp/linux-${HELM_ARCH}

# Install k9s CLI (latest GitHub release)
RUN apt-get update && \
    ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
      amd64) PKG_ARCH="amd64" ;; \
      arm64) PKG_ARCH="arm64" ;; \
      armhf) PKG_ARCH="armhf" ;; \
      *) echo "Unsupported architecture: $ARCH"; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/k9s.deb \
      "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_linux_${PKG_ARCH}.deb" && \
    dpkg -i /tmp/k9s.deb || apt-get -y -f install && \
    rm /tmp/k9s.deb && \
    rm -rf /var/lib/apt/lists/*

# Non‑root user setup
RUN useradd -m -s /bin/bash gdcn && \
    echo "gdcn ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/gdcn

WORKDIR /workspace
USER gdcn

# Install Helm plugins for the non-root user
RUN helm plugin install https://github.com/databus23/helm-diff --version ${HELM_DIFF_VERSION}

# Container acts as a long‑running bootstrap target
CMD ["sleep", "infinity"]
