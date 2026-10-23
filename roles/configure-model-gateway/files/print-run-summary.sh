#!/usr/bin/env bash
# print-run-summary.sh — pretty-prints the Model Gateway run summary.
#
# Usage:
#   print-run-summary.sh <succeeded_json> <skipped_json>             # configure summary
#   print-run-summary.sh <succeeded_json> <skipped_json> --uninstall # uninstall summary
#
# Called via `bash` from Ansible so no execute bit is required.

set -euo pipefail

python3 - "$1" "$2" "${3:-}" <<'PY'
import json, sys

succeeded = json.loads(sys.argv[1])
skipped   = json.loads(sys.argv[2])
mode      = sys.argv[3]

SEP = "=" * 60
print(SEP)
if mode == "--uninstall":
    print("Model Gateway Uninstall \u2014 Run Summary")
else:
    print("Model Gateway Configuration \u2014 Run Summary")
print(SEP)

if succeeded:
    label = "UNINSTALLED" if mode == "--uninstall" else "CONFIGURED"
    print(f"{label} ({len(succeeded)}):")
    for t in succeeded:
        print(f"  \u2713  {t['name']} ({t['id']})")

if skipped:
    print(f"SKIPPED ({len(skipped)}):")
    for t in skipped:
        print(f"  \u26a0  {t['name']} ({t['id']})")
        print(f"     Reason: {t['reason']}")

if not succeeded and not skipped:
    print("No tenants were processed.")

print(SEP)
PY
