### Role Description
Patches the OpenShift global pull secret (`openshift-config/pull-secret`) to add credentials for `cp.icr.io` using the IBM Entitlement Key.

### Var Configuration

#### Must Configure
| Variable | Description |
|---|---|
| `entitlement_key` | IBM Entitlement Key — used as the password for `cp.icr.io` |

#### Optional
_None — the target secret (`openshift-config/pull-secret`) is always the OpenShift global pull secret._

### Tags

| Tag | Effect |
|---|---|
| `install` | Fetch, merge, and push the updated global pull secret |

### How-to-run

Uncomment `- pull-secret` in [`install-wxa4z.yml`](../../install-wxa4z.yml), then:

```bash
ansible-playbook install-wxa4z.yml --tags install
```
