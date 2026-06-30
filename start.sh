#!/bin/bash
set -e

echo "Starting Azure DevOps Agent..."

cd /azp

# validation
if [ -z "$AZP_URL" ] || [ -z "$AZP_TOKEN" ]; then
  echo "ERROR: AZP_URL or AZP_TOKEN missing"
  exit 1
fi

AZP_POOL=${AZP_POOL:-Default}
AZP_AGENT_NAME=${AZP_AGENT_NAME:-$(hostname)}

echo "Downloading Azure DevOps agent..."

curl -fSL -o agent.tar.gz \
  https://download.agent.dev.azure.com/agent/3.246.0/vsts-agent-linux-x64-3.246.0.tar.gz

tar -xzf agent.tar.gz
rm agent.tar.gz

echo "Configuring agent..."

./config.sh --unattended \
  --url "$AZP_URL" \
  --auth pat \
  --token "$AZP_TOKEN" \
  --pool "$AZP_POOL" \
  --agent "$AZP_AGENT_NAME" \
  --acceptTeeEula \
  --replace

cleanup() {
  echo "Removing agent..."
  ./config.sh remove --unattended --auth pat --token "$AZP_TOKEN" || true
}

trap cleanup EXIT

echo "Running agent..."
./run.sh
