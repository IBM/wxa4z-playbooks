### Role Description
Installs the WatsonX Orchestrate (WxO) component on Software Hub using `cpd-cli`. Generates `install-options.yml` from a template, launches `cpd-cli manage install-components` asynchronously, applies hotfix-5314 mid-flight once the WO CR appears, then rejoins and waits for install to complete. Finishes by patching the `WatsonxOrchestrate` CR with resource size overrides.

### Var Configuration

#### Must Configure
| Variable | Description |
|---|---|
| `cpd_version` | Must be `5.3.1` |
| `path_cpd_cli_workspace` | Absolute path to your local `cpd-cli` workspace |
| `wxo_inferencing_stack` | `aio` (s390x/AI Optimizer), `ifm` (x86_64/WatsonX AI), or `rhaiis` |
| `wxo_size` | Deployment size: `small`, `medium`, or `large` |
| `wxo_install_mode` | `agentic` or `conversational` |
| `wxo_internal_ifm` | `true` = same-cluster IFM, `false` = external endpoint (only used when `wxo_inferencing_stack == 'ifm'`) |

#### Optional
| Variable | Default | Description |
|---|---|---|
| `cpd_operators_ns` | `cpd-operators` | Operators namespace |
| `cpd_instance_ns` | `cpd-instance-1` | Instance namespace |
| `software_hub_block_storage_class` | `ocs-storagecluster-ceph-rbd` | Block StorageClass |
| `software_hub_file_storage_class` | `ocs-storagecluster-cephfs` | File StorageClass |
| `software_hub_image_pull_prefix` | `icr.io` | Registry prefix |
| `software_hub_image_pull_secret` | `image-pull-secret` | Pull secret name |

### Tags

| Tag | Effect |
|---|---|
| `install` | Validate vars → apply cluster resources → generate install-options → async install + hotfix → patch CR |

### How-to-run

Uncomment `- install-wxo` in [`install-wxa4z.yml`](../../install-wxa4z.yml), then:

```bash
ansible-playbook install-wxa4z.yml --tags install
```
