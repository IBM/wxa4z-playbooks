#!/usr/bin/env bash
# detect-tenant-model.sh — activates the ADK environment for one WxO tenant
# and detects its currently configured default MGW virtual model.
#
# Usage:
#   bash detect-tenant-model.sh <env_name> <inst_url> <username> <password> <tenant_json>
#
# Outputs a single JSON object to stdout:
#   {
#     "name": "...", "id": "...", "namespace": "...",
#     "env_name": "...", "service_instance_url": "...",
#     "current_model": "virtual-model/..." | null
#   }

ENV_NAME="$1"
INST_URL="$2"
USERNAME="$3"
PASSWORD="$4"
TENANT_JSON="$5"

# ── Add ADK environment (idempotent — ignore errors if already exists) ─────────
echo "y" | orchestrate env add \
  -n "$ENV_NAME" \
  -u "$INST_URL" \
  --type cpd \
  --insecure >/dev/null 2>&1 || true

# ── Activate ADK environment ───────────────────────────────────────────────────
DETECTION_FAILED=0
if ! orchestrate env activate \
     --username="$USERNAME" \
     --password="$PASSWORD" \
     "$ENV_NAME" >/dev/null 2>&1; then
  MODELS_RAW=""
  DETECTION_FAILED=1
else
  MODELS_RAW=$(orchestrate models list --raw 2>/dev/null | grep 'virtual-model' | head -n1 || true)
fi

# ── Emit result JSON (single Python call) ─────────────────────────────────────
python3 - "$TENANT_JSON" "$ENV_NAME" "$INST_URL" "$MODELS_RAW" "$DETECTION_FAILED" <<'PY'
import json, re, sys

t                = json.loads(sys.argv[1])
env_name         = sys.argv[2]
inst_url         = sys.argv[3]
models_raw       = sys.argv[4].strip()
detection_failed = sys.argv[5] == "1"

model = None
if models_raw:
    m = re.search(r'virtual-model/[^:\s]+', models_raw)
    if m:
        model = m.group(0)

print(json.dumps({
    "name":                 t["display_name"],
    "id":                   t["id"],
    "namespace":            t["namespace"],
    "env_name":             env_name,
    "service_instance_url": inst_url,
    "current_model":        model,
    "detection_failed":     detection_failed,
}))
PY
