FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Base packages
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    git \
    git-lfs \
    jq \
    unzip \
    zip \
    tar \
    gzip \
    xz-utils \
    gnupg \
    gpg \
    software-properties-common \
    lsb-release \
    openssh-client \
    rsync \
    make \
    build-essential \
    dnsutils \
    iputils-ping \
    net-tools \
    procps \
    vim \
    nano \
    less \
    tree \
    sudo \
    python3 \
    python3-pip \
    python3-venv \
    libicu74 \
    libssl3 \
    libstdc++6

# -----------------------------------------------------------------------------
# Microsoft repository (PowerShell)
# -----------------------------------------------------------------------------
RUN wget https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb

# -----------------------------------------------------------------------------
# PowerShell
# -----------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y powershell

# -----------------------------------------------------------------------------
# Azure CLI
# -----------------------------------------------------------------------------
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# -----------------------------------------------------------------------------
# Node.js 22 LTS
# -----------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs

# -----------------------------------------------------------------------------
# pnpm (via Corepack, bundled with Node.js)
# Provides the `pnpm` shim used to install project deps (e.g. vite) so
# `pnpm install && pnpm build` works for frontend pipelines. Corepack respects
# a project's `packageManager` field and fetches the matching version on demand.
# -----------------------------------------------------------------------------
RUN corepack enable && \
    corepack prepare pnpm@latest --activate

# -----------------------------------------------------------------------------
# Docker CLI
# -----------------------------------------------------------------------------
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli

# -----------------------------------------------------------------------------
# kubectl
# -----------------------------------------------------------------------------
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl

# -----------------------------------------------------------------------------
# Helm
# -----------------------------------------------------------------------------
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# -----------------------------------------------------------------------------
# Terraform
# -----------------------------------------------------------------------------
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] \
    https://apt.releases.hashicorp.com \
    $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y terraform

# -----------------------------------------------------------------------------
# yq
# -----------------------------------------------------------------------------
RUN wget -qO /usr/local/bin/yq \
    https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

# -----------------------------------------------------------------------------
# Verify tools
# -----------------------------------------------------------------------------
RUN git --version && \
    git lfs version && \
    curl --version && \
    jq --version && \
    yq --version && \
    pwsh -Version && \
    az version && \
    node --version && \
    npm --version && \
    pnpm --version && \
    docker --version && \
    kubectl version --client && \
    helm version && \
    terraform version && \
    python3 --version

# -----------------------------------------------------------------------------
# Azure DevOps agent user
# -----------------------------------------------------------------------------
RUN useradd -m -d /azp -s /bin/bash agent && \
    usermod -aG sudo agent && \
    echo "agent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /azp

COPY start.sh /azp/start.sh
RUN chmod +x /azp/start.sh && \
    chown -R agent:agent /azp

USER agent

ENTRYPOINT ["/azp/start.sh"]
