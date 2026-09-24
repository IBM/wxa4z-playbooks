# configure-model-gateway

### Role Description
Configures the WatsonX Orchestrate Model Gateway via the `orchestrate` CLI. Registers a WxO environment, adds a model connection, and imports a Granite model. Supports three inferencing backends — **IFM** (IBM Foundation Models, x86), **AIO** (AI Optimizer, s390x), and **RHAIIS** (Red Hat AI Inference Server) — selected by tag. Also supports teardown via the `uninstall` tag.

> **Prerequisites:** `orchestrate` CLI installed and in PATH; logged into the OpenShift cluster (`oc login`)

### Var Configuration

> **Note:** All credentials are configured in the unified **"Inferencing / LLM Credentials"** section of `vars/global.yaml`. Only configure the variables relevant to your chosen inferencing stack.

| Tag | Variable | Description |
|---|---|---|
| `aio` | `aio_cluster_ip` | IP of the AI Optimizer LPAR (no ports/paths) |
| `aio` | `aio_api_key` | API key from the AIO LPAR |
| `rhaiis` | `rhaiis_inferencing_endpoint` | RHAIIS inference endpoint URL (no /v1 suffix) |
| `rhaiis` | `rhaiis_api_key` | API key for RHAIIS authentication |
| `ifm` | `watsonx_space_id` | WatsonX deployment space ID |
| `ifm` | `watsonx_project_id` | WatsonX project ID (optional) |

#### Optional
| Variable | Default | Description |
|---|---|---|
| `wxo_tenant_id` | `""` | Override tenant ID; auto-fetched from `wxo-tenant-ids` ConfigMap if empty |
| `cpd_api_key` | _(from `cpd-api-key` secret)_ | CPD API key for IFM; auto-fetched from cluster secret if not set |

### Tags
| Tag | Description |
|---|---|
| `ifm` | Configure Model Gateway for IBM Foundation Models (x86_64) |
| `aio` | Configure Model Gateway for AI Optimizer (s390x) |
| `rhaiis` | Configure Model Gateway for Red Hat AI Inference Server |
| `uninstall` | Remove Model Gateway configuration |

### How-to-run
```bash
# Choose one tag matching your inferencing stack
ansible-playbook install-wxa4z.yml --tags ifm
ansible-playbook install-wxa4z.yml --tags aio
ansible-playbook install-wxa4z.yml --tags rhaiis
ansible-playbook install-wxa4z.yml --tags uninstall
```
Ensure the `configure-model-gateway` role is uncommented in the playbook's role list before running.
