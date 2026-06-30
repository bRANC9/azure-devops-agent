#!/bin/bash
set -e

cd /azp

if [ -z "$AZP_URL" ] || [ -z "$AZP_TOKEN" ]; then
  echo "Missing AZP_URL or AZP_TOKEN"
  exit 1
fi

AZP_POOL=${AZP_POOL:-Default}
AZP_AGENT_NAME=${AZP_AGENT_NAME:-$(hostname)}

./config.sh --unattended \
  --url "$AZP_URL" \
  --auth pat \
  --token "$AZP_TOKEN" \
  --pool "$AZP_POOL" \
  --agent "$AZP_AGENT_NAME" \
  --acceptTeeEula \
  --replace

cleanup() {
  ./config.sh remove --unattended --auth pat --token "$AZP_TOKEN" || true
}

trap cleanup EXIT

./run.sh
