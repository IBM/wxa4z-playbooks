# create-wxo-instance

### Role Description
Creates one or more WatsonX Orchestrate service instances via the CPD API. For each instance, it idempotently creates or reuses the instance, collects its tenant ID, and stores all tenant IDs in a `wxo-tenant-ids` ConfigMap. A CPD API key is also generated and stored in a `cpd-api-key` Secret.

### Var Configuration

#### Must Configure
| Variable | Description |
|---|---|
| `cpd_instance_ns` | Namespace where CPD is installed (e.g. `cpd-instance-1`) |
| `cpd_version` | CPD version string (e.g. `5.3.1`) |

#### Optional
| Variable | Default | Description |
|---|---|---|
| `wxo_instances` | `[{name: wo-instance-1}, {name: wo-instance-2}]` | List of instances to create. Each entry takes `name` and an optional `description`. |
| `wxo_regenerate_api_key` | `false` | Set to `true` to force regeneration of the CPD API key even if the secret already exists. |

### Tags
| Tag | Description |
|---|---|
| `install` | Runs the full instance creation flow |

### How-to-run
```bash
ansible-playbook install-wxa4z.yml --tags install
```
Ensure the `create-wxo-instance` role is uncommented in the playbook's role list before running.
