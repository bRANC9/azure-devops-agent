FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Base packages
RUN apt-get update && \
    apt-get install -y \
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
        libssl3 \
        libicu70 \
        libstdc++6 && \
    rm -rf /var/lib/apt/lists/*

# Microsoft repository
RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb

# Microsoft tools
RUN apt-get update && \
    apt-get install -y \
        powershell \
        azure-cli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify installations
RUN pwsh -Version && \
    az version && \
    git --version && \
    python3 --version && \
    curl --version

# Agent user (non-root)
RUN useradd -m -d /azp agent

WORKDIR /azp

COPY start.sh /azp/start.sh
RUN chmod +x /azp/start.sh

USER agent

ENTRYPOINT ["/azp/start.sh"]
