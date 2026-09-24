### Role Description
Installs the OpenShift cert-manager operator via OLM. Creates the namespace, OperatorGroup, and Subscription, then waits for the CSV to reach `Succeeded`.

### Var Configuration

#### Must Configure
_None — all defaults are pre-set for the standard Red Hat cert-manager operator._

#### Optional
All defaults are in [`defaults/main.yml`](defaults/main.yml). Common overrides:

| Variable | Default | Description |
|---|---|---|
| `cert_manager_namespace` | `cert-manager-operator` | Namespace for the operator |
| `cert_manager_channel` | `stable-v1` | OLM subscription channel |
| `cert_manager_source` | `redhat-operators` | CatalogSource name |
| `cert_manager_install_plan_approval` | `Automatic` | `Automatic` or `Manual` |

### Tags

| Tag | Effect |
|---|---|
| `install` | Create namespace, OperatorGroup, Subscription; wait for CSV |
| `uninstall` | Delete Subscription, CSV, OperatorGroup, and namespace |

### How-to-run

Uncomment `- cert-manager-operator` in [`install-wxa4z.yml`](../../install-wxa4z.yml), then:

```bash
# Install
ansible-playbook install-wxa4z.yml --tags install

# Uninstall
ansible-playbook install-wxa4z.yml --tags uninstall
```
