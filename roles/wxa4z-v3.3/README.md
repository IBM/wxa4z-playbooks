# wxa4z-v3.3

### Role Description
Deploys IBM watsonx Assistant for Z (WxA4Z) v3.3 on OpenShift. Installs the cluster-scoped OLM operator, applies the `ZAssistantDeploy` CR (NATS, OpenSearch, wrapper, ingestion manager, bootstrapper, tenant manager), and optionally deploys the `AIOpsIntegration` CR for z/OS AIOps. All three sub-components are independently addressable by tag.

### Var Configuration

> **Note:** All LLM/inferencing credentials are configured in the unified **"Inferencing / LLM Credentials"** section of `vars/global.yaml`. The role automatically derives `llm_base_url` and `llm_api_key` from the appropriate source (AIO, RHAIIS, or WatsonX) based on your `model_runtime` setting. You only need to configure the credentials relevant to your chosen inferencing stack.

#### Must Configure

**LLM / Inferencing Credentials** (in `vars/global.yaml`):

| Variable | Description |
|---|---|
| `model_runtime` | **REQUIRED.** LLM runtime type. Options: `openai_protocol`, `on-prem`, `cloud` |
| `watsonx_model_id` | **REQUIRED.** Model to use (e.g., `ibm/granite-4.1-8b`, `meta-llama/llama-3-3-70b-instruct`) |
| `cpd_username` | CPD/cpadmin username (default: `cpadmin`) |

**For AIO deployments** (`model_runtime: openai_protocol`):
| Variable | Description |
|---|---|
| `aio_cluster_ip` | IP or hostname of AIO LPAR (no ports/paths). Example: `192.168.1.100` |
| `aio_api_key` | API key from AIO LPAR |

**For RHAIIS deployments** (`model_runtime: openai_protocol`):
| Variable | Description |
|---|---|
| `rhaiis_inferencing_endpoint` | Full RHAIIS endpoint URL (no /v1 suffix) |
| `rhaiis_api_key` | RHAIIS API key |

**For WatsonX deployments** (`model_runtime: on-prem` or `cloud`):
| Variable | Description |
|---|---|
| `watsonx_url` | Software Hub (on-prem) or SaaS wxai (cloud) URL |
| `watsonx_api_key` | Software Hub (on-prem) or IAM (cloud) API key |
| `watsonx_model_id` | Model to use (e.g., `ibm/granite-4.1-8b`, `meta-llama/llama-3-3-70b-instruct`) |
| `watsonx_space_id` | Deployment space ID |
| `watsonx_project_id` | Project ID (optional) |

**`zad` / `install` — ZAssistantDeploy secrets** (populate in `vars/global.yaml`):

| Variable | Description |
|---|---|
| `nats_public_key` | NATS worker public key |
| `nats_user_seed_key` | NATS worker user seed |
| `nats_jwt_token` | NATS worker JWT token |
| `nats_signing_seed` | NATS signing seed |
| `nats_operator_fingerprint` | NATS operator fingerprint |
| `ingestion_api_key` | Ingestion API key |

**`aiops` / `install` — AIOpsIntegration** (in `vars/global.yaml`):

| Variable | Description |
|---|---|
| `smu_hostname` | SMU hostname |
| `smu_username` / `smu_password` | SMU credentials |
| `smu_admin_username` / `smu_admin_password` | SMU admin credentials |
| `zws_hostname` | z/OS Workload Scheduler hostname |
| `zws_username` / `zws_password` | ZWS credentials |
| `aiops_username` / `aiops_password` | AIOps login credentials |

#### Optional
| Variable | Default | Description |
|---|---|---|
| `opensearch_username` | `admin` | OpenSearch admin username |
| `opensearch_client_password` | `admin` | OpenSearch client password |
| `smu_port` | `16311` | SMU port |
| `zws_port` | `22443` | ZWS port |

### Tags
| Tag | Description |
|---|---|
| `install` | Run all three sub-components (operator + zad + aiops) |
| `operator` | Install the wxa4z OLM operator only |
| `zad` | Apply ZAssistantDeploy CR and all supporting secrets |
| `aiops` | Apply AIOpsIntegration CR |
| `uninstall` | Remove all wxa4z resources |

### How-to-run
```bash
# Full install
ansible-playbook install-wxa4z.yml --tags install

# Individual components
ansible-playbook install-wxa4z.yml --tags operator
ansible-playbook install-wxa4z.yml --tags zad
ansible-playbook install-wxa4z.yml --tags aiops

# Uninstall
ansible-playbook install-wxa4z.yml --tags uninstall
```
Ensure the `wxa4z-v3.3` role is uncommented in the playbook's role list before running.
