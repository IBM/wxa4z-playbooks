### Role Description
Installs IBM Software Hub (Cloud Pak for Data) using `cpd-cli`. Creates namespaces, downloads CASE bundles, authorises namespace permissions, creates MCG and image pull secrets, then runs `cpd-cli manage install-components`. Finishes with operator/operand health checks and prints the initial admin credentials.

### Var Configuration

#### Must Configure
| Variable | Description |
|---|---|
| `entitlement_key` | IBM Entitlement Key for `cp.icr.io` |
| `path_cpd_cli_workspace` | Absolute path to your local `cpd-cli` workspace |

#### Optional
| Variable | Default | Description |
|---|---|---|
| `cpd_version` | `5.3.1` | Software Hub release version |
| `cpd_operators_ns` | `cpd-operators` | Operators namespace |
| `cpd_instance_ns` | `cpd-instance-1` | Instance namespace |
| `cpd_scheduler_ns` | `ibm-cpd-scheduler` | Scheduler namespace (x86_64 only) |
| `software_hub_components` | `cpd_platform` | Components to install |
| `software_hub_case_components` | `cpd_platform,cpfs,zen,watsonx_orchestrate` | CASE packages to download |
| `software_hub_license_types` | `EE` | License type |
| `software_hub_image_pull_prefix` | `icr.io` | Registry prefix |

### Tags

| Tag | Effect |
|---|---|
| `install` | Full install: namespaces → CASE download → permissions → secrets → `install-components` → health check |
| `uninstall` | Delete pull secrets, MCG secrets, namespaces, and remove finalizers; waits for pod termination |

### How-to-run

Uncomment `- software-hub` in [`install-wxa4z.yml`](../../install-wxa4z.yml), then:

```bash
# Install
ansible-playbook install-wxa4z.yml --tags install

# Uninstall
ansible-playbook install-wxa4z.yml --tags uninstall
```
