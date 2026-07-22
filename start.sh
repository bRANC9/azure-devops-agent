#!/bin/bash
set -euo pipefail

echo "Getting latest Azure DevOps agent version..."

API_RESPONSE=$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: azure-devops-agent" \
    https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest)

AGENT_VERSION=$(echo "$API_RESPONSE" | jq -r '.tag_name' | sed 's/^v//')

if [ -z "$AGENT_VERSION" ] || [ "$AGENT_VERSION" = "null" ]; then
    echo "ERROR: Failed to determine latest Azure DevOps agent version"
    echo "$API_RESPONSE"
    exit 1
fi

echo "Latest version detected: $AGENT_VERSION"

# VSTS agent (teljes csomag)
AGENT_URL="https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz"

# Ha inkább a kisebb pipelines-agent kell, ezt használd:
# AGENT_URL="https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/pipelines-agent-linux-x64-${AGENT_VERSION}.tar.gz"

echo "Downloading agent from:"
echo "$AGENT_URL"

mkdir -p /azp/agent

curl -fsSL "$AGENT_URL" -o /tmp/agent.tar.gz

tar -xzf /tmp/agent.tar.gz -C /azp/agent

rm /tmp/agent.tar.gz

cd /azp/agent

cleanup() {
    echo "Removing Azure DevOps agent..."

    if [ -f ./config.sh ]; then
        ./config.sh remove \
            --unattended \
            --auth pat \
            --token "$AZP_TOKEN" || true
    fi
}

trap cleanup EXIT INT TERM

./config.sh \
    --unattended \
    --replace \
    --acceptTeeEula \
    --url "$AZP_URL" \
    --auth pat \
    --token "$AZP_TOKEN" \
    --pool "$AZP_POOL" \
    --agent "${AZP_AGENT_NAME:-$(hostname)}" \
    --work _work

exec ./run.sh
