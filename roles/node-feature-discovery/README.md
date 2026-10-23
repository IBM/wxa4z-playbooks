### Role Description
Installs the OpenShift Node Feature Discovery (NFD) operator and creates an `nfd-instance` CR, which auto-labels nodes with their hardware capabilities (PCI devices, CPU features, etc.). After install it validates that nodes carry exactly one of the expected GPU PCI labels (`pci-1014` for Spyre, `pci-10de` for NVIDIA) and fails if none are found or both appear on the same node.

> **Note:** This role is a prerequisite for the `nvidia-gpu-operator` role.

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
| `install` | Deploy NFD operator + instance CR; validate PCI node labels |
| `uninstall` | Delete Subscription, OperatorGroup, and `openshift-nfd` namespace |

> The `nvidia_gpu_enabled` guard runs on tag `always` — it fires regardless of which tag is selected.

### How-to-run

Uncomment `- node-feature-discovery` in [`install-wxa4z.yml`](../../install-wxa4z.yml), then:

```bash
# Install
ansible-playbook install-wxa4z.yml --tags install

# Uninstall
ansible-playbook install-wxa4z.yml --tags uninstall
```
