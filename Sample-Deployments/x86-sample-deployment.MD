## x86 Sample Deployment -- Dev Cluster 

#### Disclaimer
This is a sample deployment walkthrough for an x86 cluster. You can reference the steps below as a guide.

#### Prerequisites
1. OCP Cluster with "vanilla" openshift installed, a node configuration that falls under our Infrastructure Requirements (see wxa4z documentation), and 300GB disks attached to at least 3 worker nodes -- a requirement for the Fusion Data Foundation (FDF) Storage solution.
2. Satisfied prerequisites from the README.md file in this repo (prepare your installation workspace).
3. Ensure you have both `cpd-cli` and `orchestrate` installed on your machine before proceeding with the deployment steps below. If not, refer back to the README.md steps in this repo.

#### x86 Deployment Order
| Order | x86 | Time Estimate |
|-------|-------|-------|
| 1 | `pull-secret` | ~3m |
| 2 | `ibm-operator-catalog` | ~3m |
| 3 | `fusion-data-foundation` | ~15-30m |
| 4 | `node-feature-discovery` | ~5-10m |
| 5 | `cert-manager-operator` | ~3-5m |
| 6 | `nvidia-gpu-operator` | ~5-10m |
| 7 | `rhoai-operator` | ~5m |
| 8 | `software-hub` | ~40m - 1hr |
| 9 | `install-wxo` | ~30m - 1hr |
| 10 | `create-wxo-instance` | ~1m |
| 11 | `configure-model-gateway` | ~1m |
| 12 | `wxa4z-v3.3` | ~5-10m |

--- 

### First: Environment Setup
To set up our working environment, we have to do the following:

(1) Run through the `Clone and Setup` steps in README.md. Install all tools and dependencies needed.

(2) Fill in the ocp-login related values in the global vars configuration file, `vars/global.yaml`, to allow for seamless ocp-login when you run any role.
```text
# ----------------------------------------------------------------------------
# OpenShift Cluster Connection (prereq — all roles)
# ----------------------------------------------------------------------------

# Set perform_ocp_login: true to enable automatic login in playbooks
perform_ocp_login: true

# OpenShift API Server URL
# Navigate to OCP UI → top-right user menu → Copy login command → Display Token
# Copy the --server value and paste it here
ocp_server: "https://api.<your-cluster-domain>:6443"

# OpenShift Admin Username
ocp_username: "kubeadmin"

# OpenShift Admin Password
ocp_password: "your-cluster-ocp-password"
```

(3) Next, set your `entitlement_key` variable (same steps are required as a prerequisite for the `pull-secret` role).

```text
# ----------------------------------------------------------------------------
# IBM Entitlement Key (prereq — pull-secret role)
# ----------------------------------------------------------------------------

# IBM ICR Entitlement Key for pulling images
# Get your key from: https://myibm.ibm.com/products-services/containerlibrary
entitlement_key: ""
```

(4) Next, set your `path_cpd_cli_workspace`
```text
# ----------------------------------------------------------------------------
# CPD / Software Hub — shared across software-hub, install-wxo, and cpd-cli roles
# ----------------------------------------------------------------------------

# CPD release version — supported: 5.3.1
cpd_version: "5.3.1"

# Local path where cpd-cli stores its workspace
# This can be any path you choose on your device [ex: "/Users/john-doe/wxa4z-workspace"]
path_cpd_cli_workspace: ""

# OLM Utils image — used by software-hub and CPD installation roles
olm_utils_image: "icr.io/cpopen/cpd/olm-utils-v4:{{ cpd_version }}"
```

(5) Install cpd-cli. To run these playbooks, **cpd-cli must be installed**. 

A container runtime (Podman, Docker, or Rancher Desktop) must be running — cpd-cli requires it

After you confirm that you have a container runtime available (Podman recommended as it has been tested), you can install the tool by running the `install-cpd-cli.yml` playbook first. You can do so with the following command: `ansible-playbook install-cpd-cli.yml`

---

### Role: `pull-secret`
- Task 1: Obtain your entitlement key from the [IBM Container Library](https://myibm.ibm.com/products-services/containerlibrary)
- Task 2: Update the `entitlement_key` in global vars file `vars/global.yaml`
- Task 3: Uncomment the `pull-secret` role from the `install-wxa4z.yml` playbook and run the playbook with: `ansible-playbook install-wxa4z.yml --tags install`
---

### Role: `ibm-operator-catalog`

#### Vars
No variable configuration is required.

Run the `ibm-operator-catalog` role:
- Uncomment the `ibm-operator-catalog` role in `install-wxa4z.yml`
- Ensure that `perform_ocp_login: true` is set, along with the relevant OCP credentials
- Run the following in your terminal: `ansible-playbook install-wxa4z.yml --tags install`

---

### Role: `fusion-data-foundation`

##### **FDF Uninstall Warning**: Do not attempt to use the `--tags uninstall` flag with the `fusion-data-foundation` role. An uninstall path for this role is not supported at this stage, and attempting to uninstall may leave the namespace in a 'Terminating' state with orphaned resources.

Prerequisites: First, ensure that you have attached an extra 300 GB disk to each worker node (for FDF)

#### Set Global Vars
 - Navigate to the OCP UI, in the top right click the user, then "Copy login command", "Display token", and then copy the `--server` value and set the ocp_server variable in the global vars file `vars/global.yaml`
 - Set the ocp_username and ocp_password values and set perform_ocp_login: true -- this will enable the playbooks to perform ocp login at runtime, which is required.

#### Get Disk Paths
For each worker node with an additional "FDF disk" attached, get the device path:
- Log in to your ocp cluster via CLI with: `oc login --server=https://api.your-cluster.com:6443 -u <username> -p <password> --insecure-skip-tls-verify=true`
- Debug into the node: `oc debug node/<worker-node-name>`
- Access host filesystem: `chroot /host`
- Identify the extra disk that has been mounted for FDF by running: `lsblk` -- Output will look as follows:
```txt
vda  252:0    0   250G  0 disk
|-vda1
|    252:1    0     1M  0 part
|-vda2
|    252:2    0   127M  0 part
|-vda3
|    252:3    0   384M  0 part /boot
`-vda4
    252:4    0 249.5G  0 part /var/lib/kubelet/pods/9ca525f9-f4f0-42c7-ae58-786f79bc234d/volume-subpaths/nginx-conf/networking-console-plugin/1
                              /var
                              /sysroot/ostree/deploy/rhcos/var
                              /sysroot
                              /etc
vdb  252:16   0   250G  0 disk
```
Where `vdb` is the added disk (for this dev cluster, it was 250GB disks added). Then we can list device paths in the next step, and look for the path corresponding to `vdb`.

List PCI device paths: `ls -l /dev/disk/by-path/ | grep pci` -- sample output is:
```txt
sh-5.1# ls -l /dev/disk/by-path/ | grep pci
lrwxrwxrwx. 1 root root  9 Jun 29 16:15 pci-0000:00:10.0 -> ../../vda
lrwxrwxrwx. 1 root root 10 Jun 29 16:15 pci-0000:00:10.0-part1 -> ../../vda1
lrwxrwxrwx. 1 root root 10 Jun 29 16:15 pci-0000:00:10.0-part2 -> ../../vda2
lrwxrwxrwx. 1 root root 10 Jun 29 16:15 pci-0000:00:10.0-part3 -> ../../vda3
lrwxrwxrwx. 1 root root 10 Jun 29 16:15 pci-0000:00:10.0-part4 -> ../../vda4
lrwxrwxrwx. 1 root root  9 Jun 29 16:15 pci-0000:00:11.0 -> ../../vdb
lrwxrwxrwx. 1 root root  9 Jun 29 16:15 virtio-pci-0000:00:10.0 -> ../../vda
lrwxrwxrwx. 1 root root 10 Jun 29 16:15 virtio-pci-0000:00:10.0-part1 -> ../../vda1
lrwxrwxrwx. 1 root root 10 Jun 29 16:15 virtio-pci-0000:00:10.0-part2 -> ../../vda2
lrwxrwxrwx. 1 root root 10 Jun 29 16:15 virtio-pci-0000:00:10.0-part3 -> ../../vda3
lrwxrwxrwx. 1 root root 10 Jun 29 16:15 virtio-pci-0000:00:10.0-part4 -> ../../vda4
lrwxrwxrwx. 1 root root  9 Jun 29 16:15 virtio-pci-0000:00:11.0 -> ../../vdb
```
- Identify the extra disk that has been mounted for FDF without partitions (e.g., `pci-0000:00:11.0 -> ../../vdb` or `virtio-pci-0000:00:11.0 -> ../../vdb`)
- Note: Both `pci-0000:00:XX.0` and `virtio-pci-0000:00:XX.0` point to the same device; you can copy the `pci-0000:00:XX.0` path.
- Repeat this process for all worker nodes with extra disks attached.

Update `vars/global.yaml` with the storage node information:
```yaml
ocp_storage_nodes:
  - name: worker0.your-cluster.example.com
    path: /dev/disk/by-path/pci-0000:00:11.0
  - name: worker1.your-cluster.example.com
    path: /dev/disk/by-path/pci-0000:00:11.0
  - name: worker2.your-cluster.example.com
    path: /dev/disk/by-path/pci-0000:00:11.0
  - name: worker3.your-cluster.example.com
    path: /dev/disk/by-path/pci-0000:00:11.0
  - name: worker4.your-cluster.example.com
    path: /dev/disk/by-path/pci-0000:00:11.0
  - name: worker5.your-cluster.example.com
    path: /dev/disk/by-path/pci-0000:00:11.0
```

Before running the role:
- Ensure a container runtime (Docker Desktop, Colima, Podman, or Rancher Desktop) is running before executing the playbook, as cpd-cli requires it. **Podman is recommended**.
- The cpd-cli login step will fail without this condition being satisfied.

Run the `fusion-data-foundation` role:
- Uncomment the `fusion-data-foundation` role in `install-wxa4z.yml`
- Ensure that `perform_ocp_login: true` is set, along with the relevant OCP credentials
- Run the following in your terminal: `ansible-playbook install-wxa4z.yml --tags install`

**NOTE:** An uninstall path for the fusion-data-foundation role is not supported at this stage.

---

### Role: `node-feature-discovery`

Installs the OpenShift Node Feature Discovery (NFD) operator and creates an `nfd-instance` CR. NFD auto-labels cluster nodes with their hardware capabilities (PCI devices, CPU features, etc.). After install, the role validates that at least one node carries an expected GPU PCI label (`pci-1014` for Spyre, `pci-10de` for NVIDIA).

> **Note:** This role is a prerequisite for the `nvidia-gpu-operator` role.

#### Vars: Must Configure
| Variable | Description |
|---|---|
| `nvidia_gpu_enabled` | Must be set to `true` — the role aborts immediately if this is `false` |

Set this in `vars/global.yaml`:
```yaml
nvidia_gpu_enabled: true
```

#### Relevant Vars -- Already Configured
| Variable | Default | Description |
|---|---|---|
| — | — | All manifests are static files; no additional vars required |

#### To run the role:
- Uncomment the `node-feature-discovery` role in `install-wxa4z.yml`
- Ensure that `perform_ocp_login: true` is set, along with the relevant OCP credentials
- Run the following in your terminal: `ansible-playbook install-wxa4z.yml --tags install`

---

### Role: `cert-manager-operator`

#### Vars
No variable configuration is required.

#### To run the role:
- Uncomment the `cert-manager-operator` role in `install-wxa4z.yml`
- Ensure that `perform_ocp_login: true` is set, along with the relevant OCP credentials
- Run the role: `ansible-playbook install-wxa4z.yml --tags install`

---

### Role: `nvidia-gpu-operator`

Installs the NVIDIA GPU Operator on OpenShift (**x86_64 only** — silently skips on other architectures).

> **Prerequisites:** `node-feature-discovery` must be installed first.

#### Vars: Must Configure
| Variable | Description |
|---|---|
| `nvidia_gpu_enabled` | Must be set to `true` — the role aborts immediately if this is `false` |

Set this in `vars/global.yaml`:
```yaml
nvidia_gpu_enabled: true
```

#### Relevant Vars -- Already Configured
| Variable | Default | Description |
|---|---|---|
| — | — | All manifests are static files; no additional vars required |

#### To run the role:
- Uncomment the `nvidia-gpu-operator` role in `install-wxa4z.yml`
- Ensure that `perform_ocp_login: true` is set, along with the relevant OCP credentials
- Run the following in your terminal: `ansible-playbook install-wxa4z.yml --tags install`

---

### Role: `rhoai-operator`

Installs Red Hat OpenShift AI (RHOAI) on x86_64 clusters. 

> **Prerequisites:** `nvidia-gpu-operator` must be installed first.

#### Vars
No variable configuration is required.

#### To run the role:
- Uncomment the `rhoai-operator` role in `install-wxa4z.yml`
- Ensure that `perform_ocp_login: true` is set, along with the relevant OCP credentials
- Run the following in your terminal: `ansible-playbook install-wxa4z.yml --tags install`

---

### Role: `software-hub`

Ensure you have a clean cpd-cli /work directory. If you've done previous software hub installs, you may have existing patch downloads that can interfere with this install. Follow these steps to prevent any such issues:
1. `podman ps` and `podman kill <container-id>` on any previously-running containers containing the olm-utils image.
2. ls `{path-to-cpd-cli-workspace}/work` -- replace the path with whatever path you have set for cpd-cli. If there's content in the **_work_** directory, delete the /work folder, and when you run the `software-hub` playbook, cpd-cli will re-create a fresh one accordingly. 

#### Vars: Must Configure
| Variable | Description |
|---|---|
| `entitlement_key` | IBM Entitlement Key for `cp.icr.io` (ensure you've run the `pull-secret` role as advised in the install order provided) |
| `path_cpd_cli_workspace` | Absolute path to your local `cpd-cli` workspace |

#### Relevant Vars -- Already Configured
| Variable | Default | Description |
|---|---|---|
| `cpd_version` | `5.3.1` | Software Hub release version |
| `olm_utils_image` | `"icr.io/cpopen/cpd/olm-utils-v4:{{ cpd_version }}"` | olm-utils image, used by cpd-cli |
| `cpd_operators_ns` | `cpd-operators` | Operators namespace |
| `cpd_instance_ns` | `cpd-instance-1` | Instance namespace |
| `cpd_scheduler_ns` | `ibm-cpd-scheduler` | Scheduler namespace (x86_64 only) |
| `skip_scheduler` | `false` | Set to `true` to skip the CPD scheduler installation. Use this when deploying on x86_64 but inferencing against **IBM Cloud watsonx.ai IFM** instead of an on-premises GPU cluster — no local IFM means the scheduler is not needed. |
| `software_hub_components` | `cpd_platform` | Components to install |
| `software_hub_case_components` | `cpd_platform,cpfs,zen,watsonx_orchestrate` | CASE packages to download |
| `software_hub_license_types` | `EE` | License type |
| `software_hub_image_pull_prefix` | `icr.io` | Registry prefix |

> **Note for IBM Cloud watsonx.ai IFM deployments:** If your x86_64 cluster is inferencing against IBM Cloud watsonx.ai IFM Services (rather than an on-premises GPU cluster), set `skip_scheduler: true` in `vars/global.yaml`. The scheduler is only required for on-premises GPU/IFM deployments — skipping it has no effect on any other part of the Software Hub installation.

#### To run the role:
1. Comment out any roles that are not `software-hub`.
2. Uncomment the `software-hub` role.
3. Run the playbook with: `ansible-playbook install-wxa4z.yml --tags install`

> **Note:** If you get a sudo password or privilege escalation error while running this role, rerun the playbook with `-K` so Ansible can prompt for your sudo password.

#### Verification

Confirm both the control plane and ZenService are `Completed`:

```bash
cpd-cli manage get-cr-status \
  --cpd_instance_ns=cpd-instance-1 \
  --components=cpd_platform
```

The `cr_status` column for `cpd_platform` must show `Completed`. Alternatively, check the underlying CRs directly:

```bash
oc get ibmcpd -n cpd-instance-1 -o jsonpath='{.items[0].status.controlPlaneStatus}{"\n"}'
oc get zenservice lite-cr -n cpd-instance-1 -o jsonpath='{.status.zenStatus}{"\n"}'
```

**Expected output for both:** `Completed`

**UI access — CPD admin console:** Get the CPD URL with:

```bash
oc get route cpd -n cpd-instance-1 -o jsonpath='{.spec.host}{"\n"}'
```

Navigate to `https://<url>`, select **IBM provided credentials (cpadmin only)**, and log in with the credentials printed by the playbook. You can also retrieve credentials at any time with `ansible-playbook install-wxa4z.yml --tags get-cpd-credentials`.

> **Note:** The watsonx Orchestrate service instance is not yet visible — it becomes accessible after `create-wxo-instance` completes.

---

### Role: `get-cpd-credentials`

Fetches CPD admin credentials and the CPD API key from cluster secrets and prints them to the console. Useful for retrieving credentials after initial installation without logging into the CPD UI.

>**Note**: The cpd-api-key secret is created by the create-wxo-instance role.

#### Vars
No variable configuration is required.

#### To run the role:
1. Comment out any roles that are not `get-cpd-credentials`.
2. Uncomment the `get-cpd-credentials` role.
3. Run the playbook with: `ansible-playbook install-wxa4z.yml --tags get-cpd-credentials`

---

### Role: `install-wxo` [~20-30m]

#### Vars: Must Configure
| Variable | Allowed Values | Description |
|---|---|---|
| `path_cpd_cli_workspace` | Absolute path string | The full local filesystem path to your `cpd-cli` workspace directory (e.g. `/Users/john-doe/wxo-workspace`). The role reads and writes files here during installation. |
| `wxo_inferencing_stack` | `rhaiis` | The inferencing backend to use. On x86, use `rhaiis` for RedHat AI Inferencing Server (RHAIIS) |

#### Relevant Vars: Already Configured
| Variable | Allowed Values | Description |
|---|---|---|
| `cpd_version` | `"5.3.1"` | The CPD release version to install. Must be exactly `5.3.1`. |
| `wxo_install_mode` | `agentic` | The install mode for WatsonX Orchestrate |
| `wxo_size` | `small` | The deployment size for WatsonX Orchestrate. |

#### To run the role:
1. Comment out any roles that are not `install-wxo`.
2. Uncomment the `install-wxo` role.
3. Run the playbook with: `ansible-playbook install-wxa4z.yml --tags install`

#### Verification

Confirm watsonx Orchestrate is `Completed`:

```bash
cpd-cli manage get-cr-status \
  --cpd_instance_ns=cpd-instance-1 \
  --components=watsonx_orchestrate
```

The `cr_status` column for `watsonx_orchestrate` must show `Completed`. Alternatively:

```bash
oc get wo wo -n cpd-instance-1 -o yaml | grep -A2 "versionStatus"
```

**Expected:** `status: <version>` in the `versionStatus` block.

---

### Role: `create-wxo-instance`

#### Vars: Must Configure
| Variable | Allowed Values | Description |
|---|---|---|
| `wxo_instances` | Any name and description | The name(s) and description(s) of the wxo instance(s) you'd like to create. Default values are set in vars/global.yaml. |

#### Relevant Vars: Already Configured
| Variable | Allowed Values | Description |
|---|---|---|
| `cpd_version` | `"5.3.1"` | The CPD release version to install. Must be exactly `5.3.1`. |
| `cpd_instance_ns` | `cpd-instance-1` | Namespace where CPD components are installed.
| `wxo_regenerate_api_key` | Default: `false` | Set to `true` to force a new CPD API key even if one already exists in the cluster. Leave as `false` for a normal first-time install. |



Example for `wxo_instances` (also the default value in `vars/global.yaml`):
```yaml
# WxO instances to create — configure names and descriptions as needed
wxo_instances:
  - name: "wo-prod"
    description: "Production instance"
  - name: "wo-dev"
    description: "Development instance"
```

#### To run the role:
1. Comment out any roles that are not `create-wxo-instance`.
2. Uncomment the `create-wxo-instance` role.
3. Run the playbook with: `ansible-playbook install-wxa4z.yml --tags install`

#### Verification

Confirm the `wxo-tenant-ids` ConfigMap and `cpd-api-key` secret were created:

```bash
oc get configmap wxo-tenant-ids -n cpd-instance-1 -o yaml
oc get secret cpd-api-key -n cpd-instance-1
```

The playbook also prints a **WatsonX Orchestrate Instances Summary** listing each instance name and its tenant ID. If the ConfigMap exists with your instance names, the role completed successfully.

**UI access — watsonx Orchestrate:** Log in to the CPD console (URL from the `software-hub` verification step above). From the main menu or via **Services → Instances** in the side nav, select your watsonx Orchestrate instance (e.g., `wo-prod`).

> **Note:** The watsonx Orchestrate UI is accessible at this point, but **Agent Builder will not be fully functional until after `configure-model-gateway`** completes — a registered LLM model is required.

---

### Role: `configure-model-gateway`

#### Vars: Must Configure
| Variable | Allowed Values | Description |
|---|---|---|
| `rhaiis_inferencing_endpoint` | URL string | Endpoint URL of the Red Hat AI Inference Server (RHAIIS) that serves inferencing requests |
| `rhaiis_api_key` | API key string | API key used to authenticate requests to the RHAIIS endpoint |

#### Relevant Vars: Already Configured
| Variable | Allowed Values | Description |
|---|---|---|
| `wxo_tenant_id` | `""` (auto-fetch) or tenant ID string | Tenant ID for the WxO environment. Leave empty to auto-fetch from the `wxo-tenant-ids` ConfigMap on the cluster. NOTE: if you do so, model gateway (MGW) will be configured for the first tenant fetched. If you're working with multiple tenants, be explicit. |
| `wxo_inferencing_stack` | `rhaiis` | Inferencing backend. Set to `rhaiis` for x86 RHAIIS deployments |

#### To run the role:
1. Configure the necessary variables in `vars/global.yaml`.
2. Comment out any roles that are not `configure-model-gateway`.
3. Uncomment the `configure-model-gateway` role in `install-wxa4z.yml`.
4. Run the playbook with the `rhaiis` tag: `ansible-playbook install-wxa4z.yml --tags rhaiis`

#### Verification

Use the `orchestrate` CLI to confirm the environment, connection, and model are registered:

```bash
orchestrate env list          # Confirm the target WxO environment exists and is active
orchestrate connections list  # Confirm the expected -mgw-credentials connection shows ✅ in Draft and Live; other ❌ rows are normal
orchestrate models list       # Confirm the registered model is present
```

The playbook debug output will also show `Model imported successfully` or `Model already exists and was updated` on a successful run.

**UI access — Agent Builder:** Log in to the watsonx Orchestrate UI and navigate to **Build → Agent Builder**. You can now create agents and test them against the registered model.

---

### Role: `wxa4z-v3.3`

This role deploys IBM watsonx Assistant for Z v3.3 on OpenShift. It installs the cluster-scoped OLM operator, applies the `ZAssistantDeploy` CR (NATS, OpenSearch, wrapper, ingestion manager, bootstrapper, tenant manager), and optionally deploys the `AIOpsIntegration` CR for z/OS AIOps. All three sub-components are independently addressable via tag.

#### Tags
| Tag | What it runs |
|---|---|
| `install` | All three sub-components: operator + ZAssistantDeploy + AIOps |
| `operator` | OLM operator install only |
| `zad` | ZAssistantDeploy CR and all supporting secrets |
| `aiops` | AIOpsIntegration CR |
| `uninstall` | Remove all wxa4z resources |

#### Vars: Must Configure

All variables below are set in `vars/global.yaml`.

**LLM / inferencing credentials** — required for `zad` / `install`:

All credentials are configured in the unified **"Inferencing / LLM Credentials"** section of `vars/global.yaml`.

| Variable | Description | 
|---|---|
| `model_runtime` | LLM runtime type. Options: `openai_protocol`, `on-prem`, `cloud` |
| `watsonx_model_id` | Model to use (e.g., `ibm/granite-4.1-8b`, `meta-llama/llama-3-3-70b-instruct`) |
| `cpd_username` | CPD/cpadmin username (default: cpadmin) |

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

> **Note:** When using RHAIIS (`model_runtime: openai_protocol`), the wxa4z-v3.3 role automatically uses your `rhaiis_inferencing_endpoint` and `rhaiis_api_key` settings. You don't need to manually set `llm_base_url` or `llm_api_key` — the role handles this for you.

**Authorization service secrets** — required for `zad` / `install`:

| Variable | Description |
|---|---|
| `sts_secret` | STS security token for the authorization service |
| `p12_password` | Password for the P12 certificate |
| `jwt_signing_key` | JWT signing key |
| `platform_agent_secret` | Platform agent secret |

**Agent tokens (optional)** — provide only for the specific agents being deployed:

| Variable | Description |
|---|---|
| `cics_agent_token` | CICS agent token |
| `db2_agent_token` | DB2 agent token |
| `ims_agent_token` | IMS agent token |
| `intellimagic_agent_token` | IntelliMagic agent token |
| `omegamon_agent_token` | Omegamon agent token |
| `support_agent_token` | Support agent token |
| `upgrade_agent_token` | Upgrade agent token |

**OpenSearch credentials** — required for `zad` / `install`:

| Variable | Description |
|---|---|
| `opensearch_username` | OpenSearch admin username |
| `opensearch_client_password` | OpenSearch client password |
| `opensearch_wrapper_username` | OpenSearch wrapper service username |
| `opensearch_wrapper_password` | OpenSearch wrapper service password |

**AIOps integration credentials** — required for `aiops` / `install`:

| Variable | Description |
|---|---|
| `smu_hostname` | SMU (System Management Unit) hostname |
| `smu_username` | SMU username |
| `smu_password` | SMU password |
| `smu_admin_username` | SMU admin username |
| `smu_admin_password` | SMU admin password |
| `zws_hostname` | z/OS Workload Scheduler (ZWS) hostname |
| `zws_username` | ZWS username |
| `zws_password` | ZWS password |
| `aiops_username` | AIOps login username |
| `aiops_password` | AIOps login password |

#### Relevant Vars: Already Configured

| Variable | Default | Description |
|---|---|---|
| `smu_port` | `16311` | SMU port |
| `zws_port` | `22443` | ZWS port |
| `zowe_enabled` | `false` | Enable Zowe integration |
| `watsonx_project_id` | `""` | WatsonX project ID (optional) |
| `wxa4z_authorization_ca_cert` | `""` | Base64-encoded P12 CA cert — leave empty unless you have a custom certificate |
| `zosmf_username` / `zosmf_password` | `""` | z/OSMF credentials (only required for z/OS topology integration) |
| `omegamon_token` | `""` | Omegamon token (only required for z/OS topology integration) |
| `redis_password` | `""` | Redis password (only required for z/OS topology integration) |

> **NATS credentials** are auto-generated by the role via `nsc` — do not set them manually.

#### To run the role

**Full install (all components):**
1. Configure all necessary variables in `vars/global.yaml` (see tables above).
2. Comment out any roles that are not `wxa4z-v3.3` in `install-wxa4z.yml`.
3. Uncomment the `wxa4z-v3.3` role.
4. Run: `ansible-playbook install-wxa4z.yml --tags install`

**Individual components:**
```bash
# Operator only
ansible-playbook install-wxa4z.yml --tags operator

# ZAssistantDeploy CR + secrets only
ansible-playbook install-wxa4z.yml --tags zad

# AIOps integration only
ansible-playbook install-wxa4z.yml --tags aiops
```

**Uninstall:**
```bash
ansible-playbook install-wxa4z.yml --tags uninstall
```

> Ensure the `wxa4z-v3.3` role is uncommented in `install-wxa4z.yml` before running any of the above commands.

#### Verification

Verify each of the three sub-components in order.

**1. Operator**

```bash
oc get deployment ibm-wxa4z-operator-controller-manager -n wxa4z-operator \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'
```

**Expected:** `True`

**2. ZAssistantDeploy (ZAD)**

```bash
oc get zassistantdeploy zassistantdeploy -n wxa4z-zad \
  -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}'

oc get pods -n wxa4z-zad
```

**Expected:** `True` for the condition; all pods in `Running` or `Completed` state.

**UI access — wxa4z chat:** Once ZAD is `Deployed`, navigate to **Chat** in watsonx Orchestrate and select an agent — the full wxa4z chat interface is now available.

**3. AIOpsIntegration**

```bash
oc get aiopsintegration wxa4z-aiops -n wxa4z-aiops \
  -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}'

oc get pods -n wxa4z-aiops
```

**Expected:** `True` for the condition; `zchatops-deployment` and `zchatops-mcp-server` pods in `Running` state.

**4. OpenShift UI check**

In the OpenShift UI, go to **Workloads → Pods** using the left navigation bar. Confirm the `wxa4z-operator`, `wxa4z-zad`, and `wxa4z-aiops` namespaces all show `Running` or `Completed` pods. Also ensure that for every tenant created, there exists a respective tenant namespace in the form of `wxa4z-<tenant_id>`.

