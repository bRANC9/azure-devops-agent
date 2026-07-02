#!/bin/bash
set -e

echo "Getting latest Azure DevOps agent version..."

AGENT_VERSION=$(curl -s https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest \
  | grep '"tag_name"' \
  | cut -d '"' -f 4 \
  | sed 's/v//')

echo "Latest version detected: $AGENT_VERSION"

AGENT_URL="https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz"

echo "Downloading agent from: $AGENT_URL"

curl -LsS "$AGENT_URL" -o agent.tar.gz

mkdir -p /azp/agent
tar -zxf agent.tar.gz -C /azp/agent

cd /azp/agent

./config.sh --unattended \
  --replace \
  --url "$AZP_URL" \
  --auth pat \
  --token "$AZP_TOKEN" \
  --pool "$AZP_POOL" \
  --agent "$AZP_AGENT_NAME" \
  --work _work

/azp/heartbeat.sh &
HEARTBEAT_PID=$!

cleanup() {
  kill "$HEARTBEAT_PID" 2>/dev/null || true
  timeout 10 /azp/heartbeat.sh --clear || true
}
trap cleanup EXIT INT TERM

./run.sh
