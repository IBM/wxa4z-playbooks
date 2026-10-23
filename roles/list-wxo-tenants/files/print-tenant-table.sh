#!/usr/bin/env bash
# print-tenant-table.sh — pretty-prints the WxO tenant discovery table.
#
# Usage: print-tenant-table.sh <cpd_url> <tenants_json> [title]
#
# title defaults to "WxO Tenants — <cpd_url>" when omitted.
# Called via `bash` from Ansible so no execute bit is required.

set -euo pipefail

CPD_URL="$1"
TENANTS_JSON="$2"
TITLE="${3:-}"

python3 - "$CPD_URL" "$TENANTS_JSON" "$TITLE" <<'PY'
import json, sys

cpd_url    = sys.argv[1]
tenants    = json.loads(sys.argv[2])
# When a custom title is given the caller owns the footer; omit the
# target_tenants hint so it only appears in the list-wxo-tenants context.
custom_title = sys.argv[3]
title        = custom_title or f"WxO Tenants \u2014 {cpd_url}"

rows = [
    (
        str(t["name"]),
        str(t["id"]),
        str(t.get("current_model") or "(none)")
    )
    for t in tenants
]

nw = max(4,  max((len(r[0]) for r in rows), default=0))
iw = max(2,  max((len(r[1]) for r in rows), default=0))
total = nw + iw + 13 + 6

print("=" * total)
print(title)
print("=" * total)
print(f"{'NAME':<{nw}}  {'ID':<{iw}}  DEFAULT MODEL")
print("-" * total)
for name, tid, model in rows:
    print(f"{name:<{nw}}  {tid:<{iw}}  {model}")
print("=" * total)
print(f"{len(rows)} tenant(s) found.")

if not custom_title:
    print()
    print("To configure the model gateway for specific tenants, set in vars/global.yaml:")
    print("  target_tenants:")
    for name, _, _ in rows:
        print(f"    - {name}")
    print("Then run:")
    print("  ansible-playbook install-wxa4z.yml --tags aio|rhaiis|ifm")
PY
