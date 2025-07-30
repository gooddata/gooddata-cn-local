FROM debian:bullseye

ARG K3D_VERSION=v5.6.3
ARG TINKEY_VERSION=1.11.0
ARG K9S_VERSION=v0.50.9
ARG KUBECTL_MAJOR_MINOR=1.33
ARG K9S_VERSION=v0.50.9

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
        openjdk-17-jre-headless \
        iputils-ping \
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

# Install kubectl & Helm
RUN curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBECTL_MAJOR_MINOR}/deb/Release.key" | \
      gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] \
          https://pkgs.k8s.io/core:/stable:/v${KUBECTL_MAJOR_MINOR}/deb/ /" \
          > /etc/apt/sources.list.d/kubernetes.list && \
    curl -fsSL https://baltocdn.com/helm/signing.asc | \
      gpg --dearmor -o /etc/apt/keyrings/helm.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/helm.gpg] \
          https://baltocdn.com/helm/stable/debian/ all main" \
          > /etc/apt/sources.list.d/helm.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        kubectl \
        helm \
    && rm -rf /var/lib/apt/lists/*

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

# Container acts as a long‑running bootstrap target
CMD ["sleep", "infinity"]
