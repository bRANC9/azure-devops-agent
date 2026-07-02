#!/bin/bash
# Periodically writes a "last seen" timestamp for this agent's pool into an
# Azure DevOps variable group, so pipelines can decide whether to target the
# self-hosted pool or fall back to a Microsoft-hosted one.
#
# Alongside the timestamp it also flips an EnableSelfHosted flag to 1 while the
# agent is running and to 0 when it stops, so pipelines have a simple boolean
# gate in addition to the freshness check.
#
# Known limitation: updates are GET-modify-PUT, not compare-and-swap, so a
# concurrent editor of the variable group could theoretically be clobbered.
# This is acceptable here because the only fields this script ever touches are
# the heartbeat timestamp and the EnableSelfHosted flag, and any two concurrent
# heartbeat writers are both trying to set them to the same values anyway.
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
ENABLE_VAR="${AZP_ENABLE_SELF_HOSTED_VARIABLE:-EnableSelfHosted}"
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

# write_variables GROUP_ID KEY VALUE [KEY VALUE ...]
# Applies all given key/value pairs to the variable group in a single
# GET-modify-PUT so the heartbeat and EnableSelfHosted flag stay consistent.
write_variables() {
  local group_id="$1"; shift
  local group_json put_body status
  group_json="$(curl -sS -u ":${AZP_TOKEN}" "${VG_BASE}/${group_id}?api-version=${API_VERSION}")" || return 1
  put_body="$group_json"
  while [[ $# -ge 2 ]]; do
    put_body="$(echo "$put_body" | jq -e --arg k "$1" --arg v "$2" \
      '.variables[$k] = {"value": $v, "isSecret": false}')" || return 1
    shift 2
  done
  status="$(curl -sS -o /dev/null -w '%{http_code}' -u ":${AZP_TOKEN}" \
    -X PUT -H "Content-Type: application/json" \
    -d "$put_body" \
    "${VG_BASE}/${group_id}?api-version=${API_VERSION}")" || return 1
  [[ "$status" =~ ^2[0-9][0-9]$ ]]
}

if [[ "${1:-}" == "--clear" ]]; then
  group_id="$(resolve_group_id)" || { log "clear: failed to resolve variable group '${AZP_VARIABLE_GROUP}'"; exit 0; }
  if write_variables "$group_id" "$HEARTBEAT_VAR" "0" "$ENABLE_VAR" "0"; then
    log "cleared $HEARTBEAT_VAR and set $ENABLE_VAR=0"
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
    if write_variables "$GROUP_ID" "$HEARTBEAT_VAR" "$(date -u +%s)" "$ENABLE_VAR" "1"; then
      log "sent heartbeat for $HEARTBEAT_VAR and set $ENABLE_VAR=1"
    else
      log "failed to write heartbeat, will retry"
      GROUP_ID=""
    fi
  fi

  sleep "$((INTERVAL + RANDOM % 5))"
done
