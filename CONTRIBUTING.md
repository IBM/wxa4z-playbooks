# Contributing

## Codebase Structure

The playbooks are organised around Ansible roles. Each role owns one product component and lives under `roles/<role-name>/`. Within a role, work is broken into focused task files rather than a single monolithic `main.yaml`.

```
roles/
└── <role-name>/
    ├── tasks/
    │   ├── main.yaml          # Entry point — imports or tags task files
    │   ├── <sub-task-a>.yaml  # One logical unit of work per file
    │   └── <sub-task-b>.yaml
    ├── templates/             # Jinja2 manifests (.yaml.j2) — rendered at runtime with vars
    ├── files/                 # Static manifests applied as-is (no templating needed)
    └── README.md              # Role-level variable reference
```

## Conventions

### New component = new role

Don't extend an existing role to install something unrelated. Create `roles/<new-role-name>/` with the same layout above.

### Split task files by concern

A role that has install/uninstall paths, or multiple sub-components, uses separate task files and imports them from `main.yaml` using tags so each can be run independently.

```yaml
# tasks/main.yaml
- import_tasks: operator.yaml
  tags: [operator, install, uninstall]

- import_tasks: zassistant-deploy.yaml
  tags: [zad, install]

- import_tasks: uninstall.yaml
  tags: [uninstall]
```

### Templates for anything that takes a variable, files for everything static

- If a manifest needs a value from `vars/global.yaml` at runtime → `templates/` as a `.yaml.j2`
- If it never changes → `files/`

### Tags control execution scope

Each task file should be tagged so callers can target just that slice (e.g. `--tags operator`, `--tags zad`, `--tags uninstall`). `main.yaml` is the tag router — it should contain `import_tasks` / `include_tasks` calls, not raw task logic.

### All user-facing variables go in `vars/global.yaml`

Role defaults (sane fallbacks that rarely change) go in `roles/<role-name>/defaults/main.yml`. Never hard-code environment-specific values inside task files.

## Examples in This Repo

| Role | What to look at |
|---|---|
| `wxa4z-v3.3` | `tasks/main.yaml` routes to `operator.yaml`, `zassistant-deploy.yaml`, `aiops.yaml`, and `uninstall.yaml` via tags; `templates/` holds all secret and CR manifests |
| `configure-model-gateway` | `tasks/main.yaml` branches by inferencing stack (`aio.yaml`, `ifm.yaml`, `rhaiis.yaml`) — adding a new stack means adding one task file and a branch in `main.yaml` |
| `software-hub` | Granular task files per operation (`case-download.yaml`, `create-projects.yaml`, `create-pull-secrets.yaml`, etc.) wired together in `main.yaml` |
