FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl git jq ca-certificates unzip tar \
    libssl3 libicu70 libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# agent user (nem root!)
RUN useradd -m -d /azp agent
WORKDIR /azp

# copy entrypoint
COPY start.sh /azp/start.sh
RUN chmod +x /azp/start.sh

USER agent

ENTRYPOINT ["/azp/start.sh"]
