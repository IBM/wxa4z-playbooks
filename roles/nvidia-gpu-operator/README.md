### Role Description
Installs the NVIDIA GPU Operator on OpenShift (**x86_64 only** — silently skips on other architectures). Creates the namespace, OperatorGroup, and Subscription; approves the InstallPlan; waits for the CSV and `ClusterPolicy` to be ready; and verifies CDI is disabled.

> **Prerequisites:** `node-feature-discovery` must be installed first.

### Var Configuration

#### Must Configure
| Variable | Description |
|---|---|
| `nvidia_gpu_enabled` | Must be `true` — role aborts immediately if false |

```yaml
# vars/global.yaml
nvidia_gpu_enabled: true
```

#### Optional
_None — all manifests are static files in [`files/`](files/)._

### Tags

| Tag | Effect |
|---|---|
| `install` | Deploy operator + ClusterPolicy; verify CDI config (x86_64 only) |
| `uninstall` | Delete ClusterPolicy, CSV, Subscription, OperatorGroup, and namespace (x86_64 only) |

> The `nvidia_gpu_enabled` guard runs on tag `always` — it fires regardless of which tag is selected.

### How-to-run

Uncomment `- nvidia-gpu-operator` in [`install-wxa4z.yml`](../../install-wxa4z.yml), then:

```bash
# Install
ansible-playbook install-wxa4z.yml --tags install

# Uninstall
ansible-playbook install-wxa4z.yml --tags uninstall
```
