# get-cpd-credentials

### Role Description
Fetches CPD admin credentials and the CPD API key from cluster secrets and prints them to the console. Useful for retrieving credentials after initial installation without logging into the CPD UI.

### Secrets read

| Secret | Namespace | Fields extracted |
|---|---|---|
| `ibm-iam-bindinfo-platform-auth-idp-credentials` | `cpd_instance_ns` | `admin_username` → `cpd_username`, `admin_password` → `cpd_password` |
| `cpd-api-key` | `cpd_instance_ns` | `cpd-api-key` → `cpd_api_key` |

> **Prerequisites:** Logged into the OpenShift cluster (`oc login`). The `cpd-api-key` secret is created by the `create-wxo-instance` role — run that first if it doesn't exist yet.

### How-to-run
```bash
ansible-playbook install-wxa4z.yml --tags get-cpd-credentials
```
Ensure the `get-cpd-credentials` role is uncommented in the playbook's role list before running.
