# RHOAI Operator Role

Ansible role for installing Red Hat OpenShift AI (RHOAI) Operator with architecture-specific support.

## Overview

This role automates the installation of the RHOAI Operator on OpenShift clusters with support for multiple architectures:
- **s390x**: IBM Z architecture (fully implemented)
- **x86_64**: Intel/AMD 64-bit architecture (placeholder for future implementation)

The role automatically detects the system architecture and executes the appropriate installation tasks.

## Requirements

- OpenShift cluster (4.12+)
- Cluster admin privileges
- Ansible collections:
  - `kubernetes.core`
  - `community.kubernetes`

## Architecture Support

- ✅ **s390x**: Fully supported (IBM Z)
  - Installs RHOAI operator
  - Creates DSCInitialization (default-dsci)
  - Creates DataScienceCluster (default-dsc)
  - Validates all components are ready
  
- 🔄 **x86_64**: Placeholder (to be implemented)
  - Task file exists at `tasks/x86_64.yaml`
  - Directory exists at `files/x86_64/` for configuration files
  - Currently displays "not implemented" message
  
- ❌ **Other architectures**: Skipped with informational message

## Role Structure

```
roles/rhoai-operator/
├── README.md
├── files/
│   ├── s390x/                    # s390x-specific files
│   │   ├── namespace.yaml
│   │   ├── operator-group.yaml
│   │   ├── subscription.yaml
│   │   ├── default-dsci.yaml
│   │   └── default-dsc.yaml
│   └── x86_64/                   # x86_64-specific files (empty, for future)
└── tasks/
    ├── main.yaml                 # Architecture router
    ├── s390x.yaml                # s390x-specific tasks
    └── x86_64.yaml               # x86_64-specific tasks (placeholder)
```

## How It Works

The `main.yaml` file acts as a router that:
1. Detects the system architecture using `ansible_architecture`
2. Imports the appropriate architecture-specific task file
3. Displays a skip message for unsupported architectures

Architecture-specific files are organized in separate directories under `files/`:
- `files/s390x/` - Contains all YAML manifests for s390x deployments
- `files/x86_64/` - Reserved for x86_64-specific manifests (to be added)

## Example Playbook

### Installation

```yaml
---
- name: Install RHOAI Operator
  hosts: localhost
  connection: local
  roles:
    - role: rhoai-operator
      tags: install
```

### Uninstallation

```yaml
---
- name: Uninstall RHOAI Operator
  hosts: localhost
  connection: local
  roles:
    - role: rhoai-operator
      tags: uninstall
```

### Command Line Usage

Install:
```bash
ansible-playbook install-rhoai.yml --tags install
```

Uninstall:
```bash
ansible-playbook install-rhoai.yml --tags uninstall
```

## s390x Installation Process

The s390x installation performs the following steps:

1. **Create Namespace**: Creates `redhat-ods-operator` namespace
2. **Create Operator Group**: Sets up operator group
3. **Create Subscription**: Subscribes to RHOAI operator
4. **Wait for Operator**: Waits for operator pod to be Running
5. **Apply DSCInitialization**: Creates default-dsci configuration
6. **Wait for DSCI Ready**: Waits for DSCInitialization to be Ready
7. **Apply DataScienceCluster**: Creates default-dsc configuration
8. **Wait for DSC Ready**: Waits for DataScienceCluster to be Ready
9. **Verify Pods**: Ensures key RHOAI/KServe pods are Running
10. **Final Check**: Validates pods exist in redhat-ods-applications namespace

All configuration files are loaded from `files/s390x/` directory.

## s390x Uninstallation Process

The s390x uninstallation performs the following steps:

1. Delete DataScienceCluster (default-dsc)
2. Delete DSCInitialization (default-dsci)
3. Delete Subscription
4. Delete Operator Group
5. Delete Namespace
6. Wait for all operator pods to be deleted
7. Wait for all application pods to be deleted

## Adding x86_64 Support

To add x86_64-specific installation tasks:

1. **Create x86_64-specific YAML files** in `roles/rhoai-operator/files/x86_64/`
   - namespace.yaml
   - operator-group.yaml
   - subscription.yaml
   - default-dsci.yaml
   - default-dsc.yaml

2. **Edit** `roles/rhoai-operator/tasks/x86_64.yaml`

3. **Replace the placeholder tasks** with actual installation steps

4. **Follow the same pattern** as `s390x.yaml` but reference `files/x86_64/` paths

5. **Test thoroughly** on x86_64 systems

Example structure for x86_64.yaml:
```yaml
---
- name: Install RHOAI operator on x86_64
  tags: install
  block:
    - name: Create rhoai-operator namespace
      kubernetes.core.k8s:
        state: present
        src: "files/x86_64/namespace.yaml"
    
    - name: Create operator group
      kubernetes.core.k8s:
        state: present
        src: "files/x86_64/operator-group.yaml"
    
    # Add more x86_64-specific installation tasks here
    
- name: Uninstall RHOAI operator on x86_64
  tags: uninstall
  block:
    - name: Delete default DataScienceCluster
      kubernetes.core.k8s:
        state: absent
        src: "files/x86_64/default-dsc.yaml"
    
    # Add more x86_64-specific uninstallation tasks here
```

## Verification

After installation on s390x, verify the deployment:

```bash
# Check operator pods
oc get pods -n redhat-ods-operator

# Check DSCInitialization status
oc get dscinitialization default-dsci -n redhat-ods-applications -o yaml

# Check DataScienceCluster status
oc get datasciencecluster default-dsc -n redhat-ods-applications -o yaml

# Check application pods
oc get pods -n redhat-ods-applications
```

## Tags

- `install`: Run installation tasks
- `uninstall`: Run uninstallation tasks

## Notes

- The role automatically detects architecture and runs appropriate tasks
- Configuration files are organized by architecture in separate directories
- s390x implementation is complete and tested
- x86_64 implementation is a placeholder for future development
- Uninstallation for s390x is marked as "not tested" in the code
- Wait times and retries are configured for production use

## Troubleshooting

### Operator Pod Not Starting
Check the subscription and operator logs:
```bash
oc get subscription -n redhat-ods-operator
oc logs -n redhat-ods-operator -l name=rhods-operator
```

### DSCInitialization Not Ready
Check the DSCI status and events:
```bash
oc describe dscinitialization default-dsci -n redhat-ods-applications
```

### DataScienceCluster Not Ready
Check the DSC status and events:
```bash
oc describe datasciencecluster default-dsc -n redhat-ods-applications
```

## License

Apache-2.0

## Author Information

Red Hat OpenShift AI Team