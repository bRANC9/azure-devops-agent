#!/bin/bash
set -euo pipefail

echo "Getting latest Azure DevOps agent version..."

echo "Calling GitHub API..."
curl -v \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: azure-devops-agent" \
  https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest

API_RESPONSE=$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: azure-devops-agent" \
    https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest)

AGENT_VERSION=$(echo "$API_RESPONSE" | jq -r '.tag_name' | sed 's/^v//')

if [ -z "$AGENT_VERSION" ] || [ "$AGENT_VERSION" = "null" ]; then
    echo "Failed to determine latest Azure DevOps agent version"
    echo "$API_RESPONSE"
    exit 1
fi

DOWNLOAD_URL=$(echo "$API_RESPONSE" | jq -r '
    .assets[]
    | select(
        (.name | startswith("pipelines-agent-linux-x64-")) or
        (.name | startswith("vsts-agent-linux-x64-"))
      )
    | .browser_download_url
' | head -n1)

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    echo "Failed to determine download URL"
    echo "$API_RESPONSE"
    echo "$DOWNLOAD_URL"
    exit 1
fi

echo "Latest version detected: $AGENT_VERSION"
echo "Downloading agent from: $DOWNLOAD_URL"

mkdir -p /azp/agent

curl -fsSL "$DOWNLOAD_URL" | tar -xz -C /azp/agent

cd /azp/agent

./config.sh --unattended \
  --replace \
  --url "$AZP_URL" \
  --auth pat \
  --token "$AZP_TOKEN" \
  --pool "$AZP_POOL" \
  --agent "$AZP_AGENT_NAME" \
  --work _work

exec ./run.sh
