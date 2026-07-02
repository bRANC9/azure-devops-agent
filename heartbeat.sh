#!/bin/bash
# Periodically writes a "last seen" timestamp for this agent's pool into an
# Azure DevOps variable group, so pipelines can decide whether to target the
# self-hosted pool or fall back to a Microsoft-hosted one.
#
# Known limitation: updates are GET-modify-PUT, not compare-and-swap, so a
# concurrent editor of the variable group could theoretically be clobbered.
# This is acceptable here because the only field this script ever touches is
# the heartbeat timestamp itself, and any two concurrent heartbeat writers
# are both trying to set it to "now" anyway.
set -uo pipefail

API_VERSION="7.1"

log() {
  echo "[heartbeat] $*" >&2
}

urlencode() {
  jq -rn --arg v "$1" '$v | @uri'
}

derive_org() {
  local url="${1%/}"
  if [[ "$url" =~ ^https?://dev\.azure\.com/([^/]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$url" =~ ^https?://([^./]+)\.visualstudio\.com$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

if [[ -z "${AZP_PROJECT:-}" || -z "${AZP_VARIABLE_GROUP:-}" ]]; then
  log "AZP_PROJECT/AZP_VARIABLE_GROUP not set, heartbeat disabled"
  exit 0
fi

AZP_ORG_NAME="$(derive_org "${AZP_URL:-}")"
if [[ -z "$AZP_ORG_NAME" ]]; then
  log "could not derive organization from AZP_URL='${AZP_URL:-}', heartbeat disabled"
  exit 0
fi

SANITIZED_POOL="$(echo "${AZP_POOL:-default}" | tr -c 'A-Za-z0-9_' '_' | tr '[:lower:]' '[:upper:]')"
HEARTBEAT_VAR="${AZP_HEARTBEAT_VARIABLE:-AGENT_POOL_${SANITIZED_POOL}_LAST_HEARTBEAT}"
INTERVAL="${AZP_HEARTBEAT_INTERVAL:-60}"
VG_BASE="https://dev.azure.com/$(urlencode "$AZP_ORG_NAME")/$(urlencode "$AZP_PROJECT")/_apis/distributedtask/variablegroups"

resolve_group_id() {
  local response
  response="$(curl -sS -G -u ":${AZP_TOKEN}" \
    --data-urlencode "groupName=${AZP_VARIABLE_GROUP}" \
    --data-urlencode "api-version=${API_VERSION}" \
    "$VG_BASE")" || return 1
  echo "$response" | jq -er '.value[0].id'
}

write_heartbeat() {
  local group_id="$1" value="$2"
  local group_json put_body status
  group_json="$(curl -sS -u ":${AZP_TOKEN}" "${VG_BASE}/${group_id}?api-version=${API_VERSION}")" || return 1
  put_body="$(echo "$group_json" | jq -e --arg k "$HEARTBEAT_VAR" --arg v "$value" \
    '.variables[$k] = {"value": $v, "isSecret": false}')" || return 1
  status="$(curl -sS -o /dev/null -w '%{http_code}' -u ":${AZP_TOKEN}" \
    -X PUT -H "Content-Type: application/json" \
    -d "$put_body" \
    "${VG_BASE}/${group_id}?api-version=${API_VERSION}")" || return 1
  [[ "$status" =~ ^2[0-9][0-9]$ ]]
}

if [[ "${1:-}" == "--clear" ]]; then
  group_id="$(resolve_group_id)" || { log "clear: failed to resolve variable group '${AZP_VARIABLE_GROUP}'"; exit 0; }
  if write_heartbeat "$group_id" "0"; then
    log "cleared $HEARTBEAT_VAR"
  else
    log "clear: failed to update variable group"
  fi
  exit 0
fi

GROUP_ID=""
while true; do
  if [[ -z "$GROUP_ID" ]]; then
    GROUP_ID="$(resolve_group_id)" || {
      log "failed to resolve variable group '${AZP_VARIABLE_GROUP}' in project '${AZP_PROJECT}', retrying"
      GROUP_ID=""
    }
  fi

  if [[ -n "$GROUP_ID" ]]; then
    if write_heartbeat "$GROUP_ID" "$(date -u +%s)"; then
      log "sent heartbeat for $HEARTBEAT_VAR"
    else
      log "failed to write heartbeat, will retry"
      GROUP_ID=""
    fi
  fi

  sleep "$((INTERVAL + RANDOM % 5))"
done
