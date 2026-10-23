# list-wxo-tenants

### Role Description
Helper role that fetches all WxO tenant instances from the CPD deployment, activates each tenant's ADK environment to detect the currently configured default MGW model, and prints a summary table. Run this before `configure-model-gateway` to understand what's on the cluster and decide which tenants to target.

> **Prerequisites:** `orchestrate` CLI installed and in PATH; logged into the OpenShift cluster (`oc login`)

### Var Configuration
No variable configuration is required. CPD credentials and the cluster URL are fetched automatically from cluster secrets and routes.

### Tags
| Tag | Description |
|---|---|
| `list-wxo-tenants` | Runs the full tenant discovery and table display |

### How-to-run
```bash
ansible-playbook install-wxa4z.yml --tags list-wxo-tenants
```
Ensure the `list-wxo-tenants` role is uncommented in the playbook's role list before running.

### Output

```
============================================================
WxO Tenants — cpd-cpd-instance-1.apps.example.com
============================================================
TENANT NAME                   TENANT ID               DEFAULT MGW MODEL
----------------------------  ----------------------  ----------------------------------------
wo-prod                       1653802146084           virtual-model/openai/ibm/granite-4.1-8b-instruct
wo-dev                        1653802146085           (none)
============================================================
3 tenant(s) found.
```
