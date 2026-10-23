### Role Description
Installs IBM Spectrum Fusion Data Foundation (FDF) on OpenShift. Labels storage worker nodes, deploys the FDF operator, creates the `SpectrumFusion` and `FusionServiceInstance` CRs, provisions a `LocalVolumeSet`, and brings up an OCS `StorageCluster`.

### Var Configuration

#### Must Configure
| Variable | Description |
|---|---|
| `ocp_storage_nodes` | List of worker nodes (name + disk path) to label and use for local storage |

```yaml
ocp_storage_nodes:
  - name: worker-0
    path: /dev/disk/by-path/ccw-0.0.0004
  - name: worker-1
    path: /dev/disk/by-path/ccw-0.0.0004
```

#### Optional
All defaults are in [`defaults/main.yml`](defaults/main.yml). Common overrides:

| Variable | Default | Description |
|---|---|---|
| `fdf_channel` | `v2.0` | OLM subscription channel |
| `fdf_namespace` | `ibm-spectrum-fusion-ns` | Operator namespace |
| `fdf_storage_class` | `fdf-localvolume` | LocalVolumeSet / StorageClass name |
| `fdf_min_disk_size` | `10Gi` | Minimum disk size for local volume discovery |
| `fdf_storage_cluster_name` | `ocs-storagecluster` | OCS StorageCluster CR name |

### Tags

| Tag | Effect |
|---|---|
| `install` | Full FDF install (operator → CRs → storage cluster) |
| `uninstall` | Tear down FDF operator, CRs, and namespace |

### How-to-run

Uncomment `- fusion-data-foundation` in [`install-wxa4z.yml`](../../install-wxa4z.yml), then:

```bash
# Install
ansible-playbook install-wxa4z.yml --tags install

# Uninstall
ansible-playbook install-wxa4z.yml --tags uninstall
```
