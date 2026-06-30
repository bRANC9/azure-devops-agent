FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl git jq ca-certificates unzip tar \
    libssl3 libicu70 libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /azp agent
WORKDIR /azp

RUN curl -Ls https://vstsagentpackage.azureedge.net/agent/3.246.0/vsts-agent-linux-x64-3.246.0.tar.gz \
    | tar -xz

COPY start.sh .
RUN chmod +x start.sh

USER agent

ENTRYPOINT ["./start.sh"]
