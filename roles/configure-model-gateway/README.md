# configure-model-gateway

### Role Description
Configures the WatsonX Orchestrate Model Gateway via the `orchestrate` CLI for one or more tenants. Discovers all WxO tenants on the CPD deployment, displays a table of tenant names, IDs, and current default models, then configures each eligible tenant. Supports three inferencing backends — **IFM** (IBM Foundation Models, x86), **AIO** (AI Optimizer, s390x), and **RHAIIS** (Red Hat AI Inference Server) — selected by tag. Also supports teardown via the `uninstall` tag.

> **Prerequisites:** `orchestrate` CLI installed and in PATH; logged into the OpenShift cluster (`oc login`)

### How It Works

1. **Discover** all WxO tenants on the CPD deployment via the zen-data API.
2. **Filter** to `target_tenants` (default: all tenants).
3. **Detect** the current default model per tenant by activating each tenant's ADK environment.
4. **Print** a discovery table:

   | TENANT NAME | TENANT ID | DEFAULT MGW MODEL |
   |---|---|---|
   | wo-prod | id123 | `granite-4.1-8b-instruct` |
   | wo-dev  | id456 | `(none)` |

5. **Configure** each tenant in scope. Tenants that already have a default model configured are **automatically skipped** — run `--tags uninstall` first to clear them before reconfiguring.
6. **Print** a run summary listing which tenants were configured and which were skipped (with reason).

### Var Configuration

> **Note:** All credentials are configured in the unified **"Inferencing / LLM Credentials"** section of `vars/global.yaml`. Only configure the variables relevant to your chosen inferencing stack.

#### Required (stack-specific)

| Tag | Variable | Description |
|---|---|---|
| `aio` | `aio_cluster_ip` | IP of the AI Optimizer LPAR (no ports/paths) |
| `aio` | `aio_api_key` | API key from the AIO LPAR |
| `rhaiis` | `rhaiis_inferencing_endpoint` | RHAIIS inference endpoint URL (no /v1 suffix) |
| `rhaiis` | `rhaiis_api_key` | API key for RHAIIS authentication |
| `ifm` | `watsonx_space_id` | WatsonX deployment space ID |
| `ifm` | `watsonx_project_id` | WatsonX project ID (optional) |

#### Tenant Targeting

| Variable | Default | Description |
|---|---|---|
| `target_tenants` | `["wo-prod", "wo-dev"]` | Which tenants to configure. Accepts a single tenant name/ID string, a YAML list of names and/or IDs (case-insensitive, can mix names and IDs), or `-1` to target every discovered tenant. |

Examples:
```yaml
target_tenants: -1            # configure every tenant

target_tenants: "wo-prod"     # single tenant by name

target_tenants: "1653802146084"  # single tenant by ID

target_tenants:               # specific set of tenants (names, IDs, or mixed)
  - wo-prod
  - wo-dev

target_tenants:               # mixed IDs and names
  - 1653802146084
  - wo-dev
```

#### Retry Tuning

| Variable | Default | Description |
|---|---|---|
| `mgw_max_retries` | `3` | Number of retry attempts for each `orchestrate` CLI command |
| `mgw_retry_delay` | `10` | Seconds to wait between retries |

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

To target a specific subset of tenants, set `target_tenants` in `vars/global.yaml` before running:
```yaml
target_tenants:
  - wo-prod
  - wo-dev
```

Ensure the `configure-model-gateway` role is uncommented in the playbook's role list before running.

### Skip Logic

If a tenant already has a default model configured, it is **skipped** during configure runs (`aio`/`rhaiis`/`ifm` tags). The run summary will list skipped tenants and the reason. To reconfigure a tenant:

```bash
# 1. Uninstall the existing model gateway config for that tenant (set in vars/global.yaml)
# target_tenants: "wo-prod"
ansible-playbook install-wxa4z.yml --tags uninstall

# 2. Re-run with the desired stack tag
ansible-playbook install-wxa4z.yml --tags aio
```

The `uninstall` tag never skips tenants — it processes all tenants in scope regardless of current model state.
