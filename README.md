# Quick Start Guide

## Prerequisites

- **OpenShift Cluster** (4.20+) with 3+ worker nodes
- **IBM Entitlement Key** from [IBM Container Library](https://myibm.ibm.com/products-services/containerlibrary)
- **OpenShift Admin Access**
- **Container Runtime**: Podman, Docker Desktop, Colima, or Rancher Desktop (required for `cpd-cli`)

**Required Software:**
- Ansible 2.20.2+
- Python 3.12+
- `oc` CLI

## Installation Path

Choose your installation approach:

- **[Standard Installation](#standard-installation-local-machine)** - Run Ansible from your local machine (recommended for dev environments)
- **[Running on Z Installation](#running-on-z-installation)** - Run Ansible on a RHEL Z bastion/jump host (for production and network-isolated environments)

## Standard Installation (Local Machine)

### 1. Verify Prerequisites

```bash
# Check versions
ansible --version  # Should be 2.20.2+
python3 --version  # Should be 3.12+
oc version

# Install if missing
pip3 install ansible
pip3 install kubernetes
ansible-galaxy collection install kubernetes.core
```

**Optional Configuration**: Change system default Python to 3.12
   ```bash
   alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
   alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 2
   alternatives --set python3 /usr/bin/python3.12
   ```

> **oc CLI Installation:** See [Getting Started with the OpenShift CLI](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)

### 2. Clone Repository

```bash
git clone git@github.com:IBM/wxa4z-playbooks.git
cd wxa4z-playbooks
```

### 3. Install cpd-cli

```bash
ansible-playbook install-cpd-cli.yml
```

Validate installation:
```bash
which cpd-cli
cpd-cli version

# If cpd-cli version does not yield output, refresh your shell:
# Bash: source ~/.bashrc
# Zsh: source ~/.zshrc
```

### 4. Install orchestrate-adk

```bash
ansible-playbook install-orchestrate-adk.yml
```

Validate installation:
```bash
orchestrate --version
```

### 5. Configure and Deploy

Edit `vars/global.yaml` with your cluster details, then proceed to [Deployment Guides](#deployment-guides).


## Running on Z Installation

> **When to use:** Only when running Ansible **ON** a RHEL Z system. Most users should use the [Standard Installation](#standard-installation-local-machine).

### 1. Clone Repository on Z System

**Option A: Using Git (requires GitHub access token)**

Generate token: https://github.com/settings/tokens

```bash
# Install git if not already present
sudo dnf install -y git

git clone https://<username>:<github-access-token>@github.com/IBM/wxa4z-playbooks.git
cd wxa4z-playbooks
```

**Option B: Using tar file**

```bash
# On your local machine
scp wxa4z-playbooks.tar.gz <user>@<lpar-host>:~

# SSH into LPAR
ssh <user>@<lpar-host>

# Extract
tar -xzvf wxa4z-playbooks.tar.gz
cd wxa4z-playbooks
```

### 2. Install oc CLI

**Linux (s390x):**
```bash
# Install wget if not already present
sudo dnf install -y wget

wget https://mirror.openshift.com/pub/openshift-v4/s390x/clients/ocp/stable/openshift-client-linux.tar.gz
tar -xf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin/
oc version
```

### 3. Upgrade Python and Ansible

> **Important:** These instructions keep your system Python 3.9 as default while enabling Ansible to use Python 3.12. This is the recommended approach for RHEL systems.

**Installation:**
```bash
# 1. Install Python 3.12 and required packages
sudo dnf install -y python3.12 python3.12-pip python3.12-pyyaml python3.12-cryptography

# 2. Upgrade pip and install ansible-core for Python 3.12
sudo /usr/bin/python3.12 -m pip install --upgrade pip
sudo /usr/bin/python3.12 -m pip install ansible-core==2.20.2
sudo /usr/bin/python3.12 -m pip install kubernetes

# 3. Install Ansible collections
ansible-galaxy collection install kubernetes.core

# 4. Install container runtime
sudo dnf install -y podman
```

**Verification:**
```bash
# System Python remains unchanged (3.9)
python --version
# Output: Python 3.9.x

# Ansible uses Python 3.12
ansible --version
# Output should show: ansible [core 2.20.2]
#                     python version = 3.12.x

# Test Ansible with Kubernetes module
oc login <api-server> -u <username> -p <password>
ansible localhost -m k8s_info -a "kind=Namespace name=default" -e "ansible_connection=local"
# Should return namespace details (SUCCESS)
```

### 4. Install cpd-cli

```bash
ansible-playbook install-cpd-cli.yml
```

Validate installation:
```bash
which cpd-cli
cpd-cli version

# If cpd-cli version does not yield output, refresh your shell:
# Bash: source ~/.bashrc
# Zsh: source ~/.zshrc
```

### 5. Install orchestrate-adk

```bash
# Must use Python 3.12 explicitly (system default is 3.9)
ansible-playbook install-orchestrate-adk.yml -e "ansible_python_interpreter=/usr/bin/python3.12"
```

Validate installation:
```bash
orchestrate --version
```

### 6. Configure and Deploy

Edit `vars/global.yaml` with your cluster details, then proceed to [Deployment Guides](#deployment-guides).

## Deployment Guides

For full step-by-step installation instructions, refer to the sample deployment walkthrough for your architecture:

| Architecture | Guide |
|---|---|
| x86_64 | [Sample-Deployments/x86-sample-deployment.MD](Sample-Deployments/x86-sample-deployment.MD) |
| s390x | [Sample-Deployments/s390x-sample-deployment.md](Sample-Deployments/s390x-sample-deployment.md) |

Each guide covers the deployment order, role-by-role variable configuration, and run instructions for that architecture.

## Contributing

For codebase structure, role conventions, and guidance on adding new logic to these playbooks, see [CONTRIBUTING.md](CONTRIBUTING.md).

## FAQ

**Q: I have an existing `cpd-cli` installation and commands that rely on it are failing. Do I need to uninstall my setup and run the `install-cpd-cli` playbook?**

You have two options:

1. **Retain your existing installation** — Identify and configure the correct PATH and environment settings so that your current `cpd-cli` installation is properly resolved by the playbooks.
2. **Reinstall using the provided playbook** — Uninstall your existing `cpd-cli` setup and run `ansible-playbook install-cpd-cli.yml` to provision a clean, pre-configured installation that the playbooks are designed to work with.

**Q: How do I properly install ansible while keeping the existing Python version required on RHEL systems?**

The playbooks require Python 3.12+ and ansible-core 2.20.2+. On RHEL Z systems, you can install Python 3.12 alongside Python 3.9 and set ansible to use the correct version without changing the system default. See [RHEL Z System Installation](#running-on-z-installation) for details.