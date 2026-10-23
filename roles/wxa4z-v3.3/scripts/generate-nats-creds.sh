#!/usr/bin/env bash
# Called by install-test-nats-creds.yml (and wxa4z-v3.3 role).
# $1 = path to nsc binary
# Outputs 4 newline-separated values: operator_jwt, operator_seed, sys_jwt, sys_seed
set -e

NSC_BIN="${1:?Usage: generate-nats-creds.sh <nsc_bin>}"

NSC_HOME="/tmp/nsc-data-$$"
NKEYS_PATH="/tmp/nkeys-$$"
export NSC_HOME NKEYS_PATH
export XDG_DATA_HOME="/tmp/.local/share-$$"
export XDG_CONFIG_HOME="/tmp/.config-$$"
mkdir -p "$NSC_HOME" "$NKEYS_PATH" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"

"$NSC_BIN" add operator wxa4z-operator >/dev/null 2>&1
"$NSC_BIN" add account SYS >/dev/null 2>&1
"$NSC_BIN" edit operator --system-account SYS >/dev/null 2>&1

operator_jwt=$("$NSC_BIN" describe operator -R 2>/dev/null)
sys_jwt=$("$NSC_BIN" describe account SYS -R 2>/dev/null)

_jwt_sub() {
  local jwt="$1"
  local payload
  payload=$(echo "$jwt" | cut -d. -f2)
  local mod=$(( ${#payload} % 4 ))
  if [ "$mod" -eq 2 ]; then payload="${payload}=="; fi
  if [ "$mod" -eq 3 ]; then payload="${payload}="; fi
  echo "$payload" | base64 -d 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sub',''))"
}

operator_key=$(_jwt_sub "$operator_jwt")
sys_key=$(_jwt_sub "$sys_jwt")

operator_seed=$(find "$NKEYS_PATH" -name "${operator_key}.nk" -exec cat {} \; 2>/dev/null)
sys_seed=$(find "$NKEYS_PATH" -name "${sys_key}.nk" -exec cat {} \; 2>/dev/null)

if [ -z "$operator_jwt" ] || [ -z "$operator_seed" ] || [ -z "$sys_jwt" ] || [ -z "$sys_seed" ]; then
  echo "ERROR: Failed to generate NATS credentials" >&2
  rm -rf "$NSC_HOME" "$NKEYS_PATH" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
  exit 1
fi

printf '%s\n%s\n%s\n%s' "$operator_jwt" "$operator_seed" "$sys_jwt" "$sys_seed"

rm -rf "$NSC_HOME" "$NKEYS_PATH" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
