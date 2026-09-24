## s390x Sample Deployment -- Dev Cluster 

#### Disclaimer
This is a sample deployment walkthrough for an s390x cluster. You can reference the steps below as a guide.

#### Prerequisites
1. OCP Cluster with "vanilla" openshift installed, a node configuration that falls under our Infrastructure Requirements (see wxa4z documentation), and 300GB disks attached to at least 3 worker nodes -- a requirement for the Fusion Data Foundation (FDF) Storage solution.
2. Satisfied prerequisites from the README.md file in this repo (prepare your installation workspace).
3. Ensure you have both `cpd-cli` and `orchestrate` installed on your machine before proceeding with the deployment steps below. If not, refer back to the README.md steps in this repo.

#### s390x Deployment Order
| Order | s390x | Time Estimate |
|-------|-------|-------|
| 1 | Configure inferencing: AIO LPAR | --- |
| 2 | `pull-secret` | ~3m |
| 3 | `ibm-operator-catalog` | ~3m |
| 4 | `fusion-data-foundation` | ~15-30m |
| 5 | `cert-manager-operator` | ~3-5m |
| 6 | `software-hub` | ~40m - 1hr |
| 7 | `install-wxo` | ~30m-1hr |
| 8 | `create-wxo-instance` | ~1m |
| 9 | `configure-model-gateway` | ~1m |
| 10 | `wxa4z-v3.3` | ~5-10m |

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

#### Verification

Confirm that `cp.icr.io` appears in the cluster's global pull secret:

```bash
oc get secret pull-secret -n openshift-config \
  -o jsonpath='{.data.\.dockerconfigjson}' \
  | base64 --decode \
  | python3 -m json.tool \
  | grep -o '"cp\.icr\.io"'
```

**Expected output:** `"cp.icr.io"`

If the output is empty, the entitlement key was not applied. Re-run the role with the correct `entitlement_key` set in `vars/global.yaml`.

---

### Role: `ibm-operator-catalog`

#### Vars
No variable configuration is required.

Run the `ibm-operator-catalog` role:
- Uncomment the `ibm-operator-catalog` role in `install-wxa4z.yml`
- Ensure that `perform_ocp_login: true` is set, along with the relevant OCP credentials
- Run the following in your terminal: `ansible-playbook install-wxa4z.yml --tags install`

#### Verification

Confirm the IBM Operator Catalog reached `READY` state:

```bash
oc get catalogsource ibm-operator-catalog -n openshift-marketplace \
  -o jsonpath='{.status.connectionState.lastObservedState}{"\n"}'
```

**Expected output:** `READY`

If the output shows `TRANSIENT_FAILURE` or is empty, check the catalog pod status:

```bash
oc get pods -n openshift-marketplace | grep ibm-operator-catalog
```

---

### Role: `fusion-data-foundation`

##### **FDF Uninstall Warning**: Do not attempt to use the `--tags uninstall` flag with the `fusion-data-foundation` role. An uninstall path for this role is not supported at this stage, and attempting to uninstall may leave the namespace in a 'Terminating' state with orphaned resources.

Prerequisites: First, ensure that you have attached an extra 300 GB disk to each worker node (for FDF)

#### Set Global Vars
 - Navigate to the OCP UI, in the top right click the user, then "Copy login command", "Display token", and then copy the `--server` value and set the ocp_server variable in the global vars file `vars/global.yaml`
 - Set the ocp_username and ocp_password values and set perform_ocp_login: true -- this will enable the playbooks to perform ocp login at runtime, which is required.

#### Get Disk Paths

(1) Get node names: `oc get nodes`. Sample output:
```txt
NAME             STATUS   ROLES                  AGE   VERSION
wxa4z8-comfa-0   Ready    worker                 19h   v1.33.12
wxa4z8-comji-2   Ready    worker                 19h   v1.33.12
wxa4z8-comtr-1   Ready    worker                 19h   v1.33.12
wxa4z8-conbs-0   Ready    control-plane,master   20h   v1.33.12
wxa4z8-conol-1   Ready    control-plane,master   20h   v1.33.12
wxa4z8-conqb-2   Ready    control-plane,master   20h   v1.33.12
```

(2) For all worker nodes with a 300GB "FDF Disk" attached, we have to find the path to the disk. To determine which nodes have these disks attached, we have to follow the steps outlined in this subsection. That being said, if your node configuration does not deviate from our documentation, you will likely have 3 worker nodes, all of which have an additional 300GB disk attached (as we designate 3 worker nodes to have an attached 300GB disk). For each node, do the following:
- Log in to your ocp cluster via CLI with: `oc login --server=https://api.your-cluster.com:6443 -u <username> -p <password> --insecure-skip-tls-verify=true`
- `oc debug node/<node-name>`
- `chroot /host` to use host binaries
- `lsblk` -- lsblk stands for list block devices. It displays the storage devices attached to a Linux system, including disks, partitions, and mount points. The purpose of lsblk is to identify which device name corresponds to the attached 300 GB FDF disk. 

Example:
```text
(1) oc debug node/wxa4z8-comfa-0
(2) chroot /host
(3) lsblk
```
Output for `lsblk` may look like:
```txt
NAME MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0
       7:0    0   5.3M  1 loop 
vda  252:0    0   200G  0 disk 
|-vda3
|    252:3    0   384M  0 part /boot
`-vda4
     252:4    0 199.6G  0 part /var/lib/kubelet/pods/a24c1f2a-0f5a-4dc9-9da9-af1594a52fbb/volume-subpaths/nginx-conf/networking-console-plugin/1
                               /var/lib/kubelet/pods/0af0e9b8-f24c-463e-9ed7-770b4ea9abde/volume-subpaths/nginx-conf/networking-console-plugin/1
                               /var
                               /sysroot/ostree/deploy/rhcos/var
                               /sysroot
                               /etc
vdb  252:16   0   300G  0 disk 
```
From there, you can look for the 300GB disk, which is the following line, at `vdb`:
```text
vdb  252:16   0   300G  0 disk 
```
Then, list CCW device paths: `ls -lr /dev/disk/by-path/ | grep ccw`. 
Sample output:
```text
lrwxrwxrwx. 1 root root  9 Jul  1 04:56 ccw-0.0.0004 -> ../../vdb
lrwxrwxrwx. 1 root root 10 Jul  1 04:56 ccw-0.0.0000-part4 -> ../../vda4
lrwxrwxrwx. 1 root root 10 Jul  1 04:56 ccw-0.0.0000-part3 -> ../../vda3
lrwxrwxrwx. 1 root root  9 Jul  1 04:56 ccw-0.0.0000 -> ../../vda
```
We care about `vdb` since this is where the 300GB disk is for this node:
```text
sh-5.1# ls -lr /dev/disk/by-path/ | grep ccw | grep vdb
lrwxrwxrwx. 1 root root  9 Jul  1 04:56 ccw-0.0.0004 -> ../../vdb
```
The relevant data we can extract for this worker node is that the relevant path to the 300GB disk is: `ccw-0.0.0004`. 

**Repeat this process for all 3 worker nodes that have 300GB disks attached for FDF.**

Then, update `vars/global.yaml` with the storage node information. Consider the example for this internal deployment:
  ```yaml
  ocp_storage_nodes:
    - name: worker0-name                    # Full node name from 'oc get nodes'
      path: /dev/disk/by-path/ccw-0.0.XXXX  # Path from step above (s390x)
    - name: worker1-name
      path: /dev/disk/by-path/ccw-0.0.YYYY
    - name: worker2-name
      path: /dev/disk/by-path/ccw-0.0.ZZZZ
  ```

The final version looks like:
  ```yaml
  ocp_storage_nodes:
  - name: wxa4z8-comfa-0
    path: /dev/disk/by-path/ccw-0.0.0004
  - name: wxa4z8-comtr-1
    path: /dev/disk/by-path/ccw-0.0.0004
  - name: wxa4z8-comji-2
    path: /dev/disk/by-path/ccw-0.0.0000
  ```

Before running the role:
- As noted above, ensure a container runtime (Docker Desktop, Colima, Podman, or Rancher Desktop) is running before executing the playbook, as cpd-cli requires it. **Podman is recommended**.
- The cpd-cli login step will fail without this condition being satisfied.

Run the fusion-data-foundation role: 
- Uncomment the `fusion-data-foundation` role in `install-wxa4z.yml`
- Ensure that `perform_ocp_login: true` is set, along with the relevant OCP credentials
- Run the following in your terminal: `ansible-playbook install-wxa4z.yml --tags install`

**NOTE:** An uninstall path for the fusion-data-foundation role is not supported at this stage.
>**Note**: This role may error due to race conditions. As Ansible is idempotent, a rerun of the playbook with no changes may be required.

#### Verification

Run all three checks before proceeding to `cert-manager-operator`:

```bash
# 1. StorageCluster phase — expected: Ready
oc get storagecluster ocs-storagecluster -n openshift-storage \
  -o jsonpath='{.status.phase}{"\n"}'

# 2. FusionServiceInstance installStatus — expected: Completed
oc get fusionserviceinstance -n ibm-spectrum-fusion-ns \
  -o jsonpath='{.items[0].status.installStatus.status}{"\n"}'

# 3. OCS storage classes — both must exist for Software Hub
oc get storageclass | grep ocs-storagecluster
```

**Expected outputs:**

| Check | Expected |
|---|---|
| StorageCluster phase | `Ready` |
| FusionServiceInstance status | `Completed` |
| Storage classes | `ocs-storagecluster-ceph-rbd` and `ocs-storagecluster-cephfs` listed |

If the `StorageCluster` is not `Ready`, check pod statuses in `openshift-storage`. A re-run may be needed due to race conditions (noted above).

---

### Role: `cert-manager-operator`

#### Vars
No variable configuration is required.

#### To run the role:
- Uncomment the `cert-manager-operator` role in `install-wxa4z.yml`
- Ensure that `perform_ocp_login: true` is set, along with the relevant OCP credentials
- Run the role: `ansible-playbook install-wxa4z.yml --tags install`

#### Verification

Confirm the cert-manager CSV reached `Succeeded` state:

```bash
oc get csv -n cert-manager-operator \
  -o jsonpath='{.items[0].status.phase}{"\n"}'
```

**Expected output:** `Succeeded`

If it shows `Installing`, wait and retry. If `Failed`, check: `oc get subscription -n cert-manager-operator`

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
| `cpd_scheduler_ns` | `ibm-cpd-scheduler` | Scheduler namespace (x86_64 only, not applicable on s390x) |
| `software_hub_components` | `cpd_platform` | Components to install |
| `software_hub_case_components` | `cpd_platform,cpfs,zen,watsonx_orchestrate` | CASE packages to download |
| `software_hub_license_types` | `EE` | License type |
| `software_hub_image_pull_prefix` | `icr.io` | Registry prefix |

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
| `wxo_inferencing_stack` | `aio` | The inferencing backend to use. On s390x, use `aio` for AI Optimizer |

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

>**Note**: This role may error due to race conditions. As Ansible is idempotent, a rerun of the playbook with no changes may be required.

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

>**Note**: This role requires orchestrate to be installed. Ensure you have orchestrate installed: `orchestrate --version`. If not, refer back to the README.md in this repo.`

#### Vars: Must Configure
| Variable | Allowed Values | Description |
|---|---|---|
| `aio_cluster_ip` | IP address string | IP address of the AI Optimizer (AIO) LPAR that serves inferencing requests |
| `aio_api_key` | API key string | API key obtained from the AIO LPAR, used to authenticate inferencing calls. See [AIO docs](https://www.ibm.com/docs/en/ai-optimizer-for-z/3.1.1?topic=routing-submitting-inference-requests) |

#### Relevant Vars: Already Configured
| Variable | Allowed Values | Description |
|---|---|---|
| `wxo_tenant_id` | `""` (auto-fetch) or tenant ID string | Tenant ID for the WxO environment. Leave empty to auto-fetch from the `wxo-tenant-ids` ConfigMap on the cluster. NOTE: if you do so, model gateway (MGW) will be configured for the first tenant fetched. If you're working with multiple tenants, be explicit. |
| `wxo_inferencing_stack` | `aio` | Inferencing backend. Set to `aio` for s390x AI Optimizer deployments |

#### To run the role:
1. Configure the necessary variables in `vars/global.yaml`.
2. Comment out any roles that are not `configure-model-gateway`.
3. Uncomment the `configure-model-gateway` role in `install-wxa4z.yml`.
4. Run the playbook with the `aio` tag: `ansible-playbook install-wxa4z.yml --tags aio`

>**Note**: This role may error due to race conditions. As Ansible is idempotent, a rerun of the playbook with no changes may be required.

#### Verification

Use the `orchestrate` CLI to confirm the environment, connection, and model are registered:

```bash
orchestrate env list          # Confirm the target WxO environment exists and is active
orchestrate connections list  # Confirm the expected -mgw-credentials connection shows ✅ in Draft and Live; other ❌ rows are normal
orchestrate models list       # Confirm configured model is registered
```

The AIO model configured in vars/global.yaml should appear in `models list`. The playbook debug output will also show "Model imported successfully" or "Model already exists and was updated" on a successful run.

**UI access — Agent Builder:** Log in to the watsonx Orchestrate UI and navigate to **Build → Agent Builder**. You can now create agents and test them against the registered model.

> **Note:** The full wxa4z chat capability requires `wxa4z-v3.3` (ZAssistantDeploy) to be deployed first. At this point you can create and test agents in Agent Builder, but the zRAG/AIOps backend services are not yet running.

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

**For AIO deployments** (`model_runtime: openai_protocol`):
| Variable | Description |
|---|---|
| `aio_cluster_ip` | IP or hostname of AIO LPAR (no ports/paths). Example: 192.168.1.100 |
| `aio_api_key` | API key from AIO LPAR |

**For WatsonX deployments** (`model_runtime: on-prem` or `cloud`):
| Variable | Description |
|---|---|
| `watsonx_url` | Software Hub (on-prem) or SaaS wxai (cloud) URL |
| `watsonx_api_key` | Software Hub (on-prem) or IAM (cloud) API key |
| `watsonx_model_id` | Model to use (e.g., `ibm/granite-4.1-8b`, `meta-llama/llama-3-3-70b-instruct`) |
| `watsonx_space_id` | Deployment space ID |
| `watsonx_project_id` | Project ID (optional) |

> **Note:** When using AIO (`model_runtime: openai_protocol`), the wxa4z-v3.3 role automatically constructs the LLM endpoint URL from your `aio_cluster_ip` setting. You don't need to manually set `llm_base_url` or `llm_api_key` — the role handles this for you.

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
  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}{"\n"}'
```

**Expected:** `True`

**2. ZAssistantDeploy (ZAD)**

```bash
oc get zassistantdeploy zassistantdeploy -n wxa4z-zad \
  -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}{"\n"}'

oc get pods -n wxa4z-zad
```

**Expected:** `True` for the condition; all pods in `Running` or `Completed` state.

**UI access — wxa4z chat:** Once ZAD is `Deployed`, navigate to **Chat** in watsonx Orchestrate and select an agent — the full wxa4z chat interface is now available.

**3. AIOpsIntegration**

```bash
oc get aiopsintegration wxa4z-aiops -n wxa4z-aiops \
  -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}{"\n"}'

oc get pods -n wxa4z-aiops
```

**Expected:** `True` for the condition; `zchatops-deployment` and `zchatops-mcp-server` pods in `Running` state.

**4. OpenShift UI check**

In the OpenShift UI, go to **Workloads → Pods** using the left navigation bar. Confirm the `wxa4z-operator`, `wxa4z-zad`, and `wxa4z-aiops` namespaces all show `Running` or `Completed` pods. Also ensure that for every tenant created, there exists a respective tenant namespace in the form of `wxa4z-<tenant_id>`.
