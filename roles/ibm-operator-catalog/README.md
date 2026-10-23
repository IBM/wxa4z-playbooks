### Role Description
Creates (or deletes) the `ibm-operator-catalog` CatalogSource in `openshift-marketplace`, making all IBM operators available for installation via OLM. Polls `icr.io/cpopen/ibm-operator-catalog:latest` every 45 minutes.

### Var Configuration

#### Must Configure
_None — the CatalogSource manifest is static._

#### Optional
_None — edit [`files/catalog-source.yaml`](files/catalog-source.yaml) directly to change the image tag or poll interval._

### Tags

| Tag | Effect |
|---|---|
| `install` | Create the CatalogSource and wait for it to reach `READY` |
| `uninstall` | Delete the CatalogSource |

### How-to-run

Uncomment `- ibm-operator-catalog` in [`install-wxa4z.yml`](../../install-wxa4z.yml), then:

```bash
# Install
ansible-playbook install-wxa4z.yml --tags install

# Uninstall
ansible-playbook install-wxa4z.yml --tags uninstall
```
