#!/bin/bash
# -----------------------------------------------------------------------------
# watsonx Orchestrate 5.3.1 Hotfix
# - Verifies watsonx Orchestrate version from .status.versionStatus.status.
# - Images of Operators are replaced with the image from hotfix script.
#   * HOTFIX_LABEL_VALUE for hotfix 3 is 5.3.1.4
#   * If an existing label value matches x.x.x.x and is higher than HOTFIX_LABEL_VALUE,
#     the script exits early after informing you
# - Deletes a fixed set of Jobs in the operands namespace and waits for all to reappear with
#   new UIDs and succeed
# -----------------------------------------------------------------------------

# -----------------------------
# Helpers
# -----------------------------
ts() { date +"%Y-%m-%d %H:%M:%S"; }

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[$(ts)] Missing required command: $1"; exit 1; }
}
get_wo_version() {
  ns="$1"
  oc get wo -n "$ns" -o jsonpath='{.items[0].status.versionStatus.status}' 2>/dev/null || true
}

get_wo_cr_version() {
  ns="$1"
  oc get wo -n "$ns" -o jsonpath='{.items[0].spec.version}' 2>/dev/null || true
}


# -----------------------------
# Patch operator deployment images
# -----------------------------

OPERATOR_IMAGES="icr.io/cpopen/ibm-watsonx-orchestrate-operator@sha256:5e75fea5876911150642c2701fd4a67f63cf3d43adfc3c78cdbd7e8ed94b952c
icr.io/cpopen/ibm-wxo-component-operator@sha256:c8bcd00b379fd85db5861c966358b536cd2da89c002fe3b58035b7c46c1f270a"

if [ -z "${PROJECT_CPD_INST_OPERATORS:-}" ]; then
  echo "[ERROR] PROJECT_CPD_INST_OPERATORS is not set. Exiting."
  exit 1
fi

# Required WO version
REQUIRED_WO_VERSION="${REQUIRED_WO_VERSION:-5.3.1}"
REQUIRED_WO_CR_VERSION="${REQUIRED_WO_CR_VERSION:-7.1.0}"

# -----------------------------
# Validations and version check
# -----------------------------
require oc

# Make sure oc login is done
if ! oc whoami &>/dev/null; then
    echo "[$(ts)] Error: Not logged in to OpenShift"
    exit 1
fi

echo "[$(ts)] Checking wo.status.versionStatus.status in ${PROJECT_CPD_INST_OPERANDS}"
WO_VER="$(get_wo_version "$PROJECT_CPD_INST_OPERANDS")"
WO_CR_VER="$(get_wo_cr_version "$PROJECT_CPD_INST_OPERANDS")"

# Check if versions match required versions
if [ "$WO_VER" != "$REQUIRED_WO_VERSION" ] || [ "$WO_CR_VER" != "$REQUIRED_WO_CR_VERSION" ]; then
    echo "[$(ts)] Error: Version mismatch!"
    echo "[$(ts)] WO Version: $WO_VER (required: $REQUIRED_WO_VERSION)"
    echo "[$(ts)] WO CR Version: $WO_CR_VER (required: $REQUIRED_WO_CR_VERSION)"
    exit 1
else
    echo "[$(ts)] Version check passed: $WO_VER , CR version: $WO_CR_VER"
fi

# Hotfix label configuration
HOTFIX_LABEL_KEY="${HOTFIX_LABEL_KEY:-hotfix}"
HOTFIX_LABEL_VALUE="${HOTFIX_LABEL_VALUE:-5.3.1.4}"
WO_CR_NAME=wo

is_semver4() {
  v="$1"
  printf '%s' "$v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}

# Backup dir for deployments
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="$(oc whoami --show-console | sed 's/.*console-openshift-console\.apps\.\([^.]*\)\..*/\1/')"
BACKUP_DIR="${SCRIPT_DIR}/wxo_deployment_backups/$CLUSTER_NAME"
mkdir -p "$BACKUP_DIR"

if [ -n "${OPERATOR_IMAGES:-}" ]; then
  echo "[$(ts)] Updating operator deployment images in ${PROJECT_CPD_INST_OPERATORS}"

  patched_deps=""

  # Use a here-document to avoid subshell so patched_deps is preserved
  while IFS= read -r img; do
    [ -z "$img" ] && continue

    # Extract base image name (e.g., ibm-wxo-component-operator)
    base="$(basename "$img" | cut -d'@' -f1)"

    echo "[$(ts)] Processing image: $img (base=$base)"

    dep=""

    case "$base" in
      ibm-watsonx-orchestrate-operator)
        dep="wo-operator"
        ;;

      ibm-wxo-component-operator)
        dep="ibm-wxo-componentcontroller-manager"
        ;;

      *)
        dep="$(oc -n "$PROJECT_CPD_INST_OPERATORS" get deploy --no-headers 2>/dev/null \
               | grep "$base" | awk 'NR==1{print $1}')"
        ;;
    esac

    # Skip bundle/catalog images if they ever slip in
    if echo "$base" | grep -Eq 'bundle|catalog'; then
      echo "[$(ts)]   Skipping $base (bundle/catalog image – not tied to deployment)"
      continue
    fi

    if [ -z "$dep" ]; then
      echo "[$(ts)]   WARNING: no matching deployment found for $base — skipping"
      continue
    fi

    # -----------------------------
    # Backup deployment YAML
    # -----------------------------
    backup_file="${BACKUP_DIR}/${dep}-$(date +%Y%m%d%H%M%S).yaml"
    if oc -n "$PROJECT_CPD_INST_OPERATORS" get deploy "$dep" -o yaml > "$backup_file" 2>/dev/null; then
      echo "[$(ts)]   Backed up deployment/$dep → $backup_file"
    else
      echo "[$(ts)]   WARNING: failed to back up deployment/$dep"
    fi

    # Determine container name (assume first container is operator)
    cname="$(oc -n "$PROJECT_CPD_INST_OPERATORS" get deploy "$dep" \
             -o jsonpath='{.spec.template.spec.containers[0].name}' 2>/dev/null)"

    if [ -z "$cname" ]; then
      echo "[$(ts)]   WARNING: cannot determine container name for $dep — skipping"
      continue
    fi

    echo "[$(ts)]   Patching deployment/$dep container '$cname' → $img"

    if oc -n "$PROJECT_CPD_INST_OPERATORS" set image "deployment/$dep" "$cname=$img" >/dev/null 2>&1; then
      echo "[$(ts)]   ✓ Image updated for $dep"
      patched_deps="$patched_deps $dep"
    else
      echo "[$(ts)]   ✗ ERROR: failed to patch $dep"
    fi

  done <<EOF
$OPERATOR_IMAGES
EOF

# -----------------------------
# Label WO CR with configurable label and value
# -----------------------------
if [ -n "$WO_CR_NAME" ]; then
  current_label="$(oc -n "$PROJECT_CPD_INST_OPERANDS" get wo "$WO_CR_NAME" -o jsonpath="{.metadata.labels.${HOTFIX_LABEL_KEY}}" 2>/dev/null || true)"
  if [ "$current_label" = "$HOTFIX_LABEL_VALUE" ]; then
    echo "[$(ts)] WO CR ${WO_CR_NAME} already labeled ${HOTFIX_LABEL_KEY}=${HOTFIX_LABEL_VALUE}"
  else
    echo "[$(ts)] Setting label ${HOTFIX_LABEL_KEY}=${HOTFIX_LABEL_VALUE} on WO CR ${WO_CR_NAME} in ns ${PROJECT_CPD_INST_OPERANDS}"
    oc -n "$PROJECT_CPD_INST_OPERANDS" label wo "$WO_CR_NAME" "${HOTFIX_LABEL_KEY}=${HOTFIX_LABEL_VALUE}" --overwrite >/dev/null 2>&1 || true
    new_label="$(oc -n "$PROJECT_CPD_INST_OPERANDS" get wo "$WO_CR_NAME" -o jsonpath="{.metadata.labels.${HOTFIX_LABEL_KEY}}" 2>/dev/null || true)"
    if [ "$new_label" = "$HOTFIX_LABEL_VALUE" ]; then
      echo "[$(ts)] Label set: ${HOTFIX_LABEL_KEY}=${HOTFIX_LABEL_VALUE}"
    else
      echo "[$(ts)] WARNING: could not confirm ${HOTFIX_LABEL_KEY}=${HOTFIX_LABEL_VALUE} label was set"
    fi
  fi
else
  echo "[$(ts)] No WO CR found in ns ${PROJECT_CPD_INST_OPERANDS}, skipping label."
fi


  # -----------------------------
  # Verify patched deployments are healthy (1/1 or 2/2)
  # -----------------------------
  if [ -n "${patched_deps// /}" ]; then
    echo "[$(ts)] Verifying rollout status for patched deployments..."

    for dep in $patched_deps; do
      echo "[$(ts)] Checking deployment/$dep..."

      # Wait for rollout to complete
      if oc -n "$PROJECT_CPD_INST_OPERATORS" rollout status deploy/"$dep" --timeout=300s; then
        # Check Ready/Desired replica ratio
        ratio="$(oc -n "$PROJECT_CPD_INST_OPERATORS" get deploy "$dep" \
                 -o jsonpath='{.status.readyReplicas}/{.status.replicas}' 2>/dev/null || echo '0/0')"
        echo "[$(ts)]   Ready/Desired: $ratio"

        if [ "$ratio" = "1/1" ] || [ "$ratio" = "2/2" ]; then
          echo "[$(ts)]   ✓ Deployment $dep is healthy (pods up and running)."
        else
          echo "[$(ts)]   ⚠ WARNING: Deployment $dep is not at 1/1 or 2/2; current $ratio"
        fi
      else
        echo "[$(ts)]   ✗ ERROR: rollout status for deployment/$dep did not complete successfully."
      fi
    done
  else
    echo "[$(ts)] No deployments were patched; skipping health verification."
  fi

else
  echo "[$(ts)] No OPERATOR_IMAGES specified — skipping operator image patch."
fi

# Let's delete the redis cronjob and and allow the operator to create a new equivalent one. 
oc delete cronjob wo-watson-orchestrate-redis-cronjob --ignore-not-found

# -----------------------------
# Final message
# -----------------------------
echo "------------------------------------------------------------------"
echo "[$(ts)] 5.3.1 Hotfix4 steps completed."
echo "Backups saved under ${BACKUP_DIR}"
echo "Monitor the watsonx Orchestrate CR status by running:"
echo " oc get wo -n ${PROJECT_CPD_INST_OPERANDS} -o yaml | grep -E 'watsonxOrchestrateStatus|${HOTFIX_LABEL_KEY}'"
echo "Ensure the watsonx Orchestrate CR status is 'Completed' and label ${HOTFIX_LABEL_KEY}=${HOTFIX_LABEL_VALUE} is present."
echo "It will take another 15–20 minutes for the updated components to be applied and restarted."
echo "------------------------------------------------------------------"