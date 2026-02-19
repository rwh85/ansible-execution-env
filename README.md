# Ansible Execution Environment

[![Build, Test, Scan & Publish](https://github.com/rwh85/ansible-execution-env/actions/workflows/build.yml/badge.svg)](https://github.com/rwh85/ansible-execution-env/actions/workflows/build.yml)

A portable Docker image containing everything needed to run the `rhel9-desktop-stig` Ansible playbooks. Built on UBI 9 (full) with Python 3.12 for native RHEL 9 parity. All Python packages, Ansible collections, and system tools are baked in — just mount your playbooks and go.

**Why?** Reproducible execution across machines, no local dependency management, and air-gap portable via `docker save`.

## Quick Start

```bash
# Build
make build

# Run a playbook
docker run --rm -it \
  -v /path/to/rhel9-desktop-stig:/playbooks \
  -v ~/.ssh:/home/ansible/.ssh:ro \
  ansible-execution-env \
  ansible-playbook /playbooks/playbooks/harden.yml -i /playbooks/inventory/hosts

# Interactive shell
make shell
```

## What's Included

| Component | Version |
|-----------|---------|
| Base Image | UBI9 9.5 (RHEL 9) |
| Python | 3.12 |
| Ansible Core | ≥2.16 (latest stable) |
| `ansible.posix` | ≥1.5.0 |
| `community.general` | ≥9.0.0 |
| paramiko, jmespath, pyyaml, cryptography | Latest |
| sshpass, openssh-clients, git-core | System packages |

### Base Image Choice

Uses `registry.access.redhat.com/ubi9/ubi:9.5` (full UBI9 with dnf) for full parity with target RHEL 9 systems. Python 3.12 is installed via dnf with a `python3` symlink for compatibility.

## Build

```bash
make build
# or
docker build -t ansible-execution-env:latest .
```

## Running Playbooks

Mount your playbook repo to `/playbooks`:

```bash
# With SSH keys
docker run --rm -it \
  -v ~/code/rhel9-desktop-stig:/playbooks \
  -v ~/.ssh:/home/ansible/.ssh:ro \
  ansible-execution-env \
  ansible-playbook /playbooks/playbooks/harden.yml -i /playbooks/inventory/hosts

# With password auth
docker run --rm -it \
  -v ~/code/rhel9-desktop-stig:/playbooks \
  ansible-execution-env \
  ansible-playbook /playbooks/playbooks/harden.yml -i /playbooks/inventory/hosts -k

# Using docker-compose (includes all hardening flags)
PLAYBOOK_DIR=~/code/rhel9-desktop-stig docker compose up
```

## SSH Keys & Passwords

- **Keys**: Mount `~/.ssh` read-only. The entrypoint auto-fixes permissions and starts `ssh-agent`.
- **Passwords**: Use `-k` (ask at runtime) or `ANSIBLE_SSH_PASS` env var (not recommended).
- **Become password**: Use `-K` flag or `ANSIBLE_BECOME_PASS` env var.

## Adding Custom Collections or Python Packages

Edit `requirements.yml` / `requirements.txt` and rebuild:

```bash
# Add a collection
echo "  - name: community.crypto" >> requirements.yml

# Add a Python package
echo "boto3" >> requirements.txt

# Rebuild
make build
```

Or install at runtime (ephemeral — requires writable filesystem):

```bash
make shell
pip install --user boto3
ansible-galaxy collection install community.crypto
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ANSIBLE_HOST_KEY_CHECKING` | `False` | Skip SSH host key verification |
| `ANSIBLE_RETRY_FILES_ENABLED` | `False` | Don't create .retry files |
| `ANSIBLE_COLLECTIONS_PATH` | `/usr/share/ansible/collections` | Collection search path |
| `ANSIBLE_SSH_ARGS` | (unset) | Extra SSH arguments |
| `ANSIBLE_VAULT_PASSWORD_FILE` | (unset) | Path to vault password file |

## Security

This image follows container security best practices:

### Image Hardening

- **Non-root user**: Runs as `ansible` (UID 1000) — never root
- **UBI9 full base**: Python 3.12 installed via dnf with explicit `python3` symlink, avoiding PATH/alternatives issues on minimal variants
- **No SUID/SGID binaries**: All set-user-id bits are stripped at build time
- **No secrets in layers**: `.dockerignore` excludes `.env`, private keys, and PEM files from the build context
- **Minimal packages**: Only what's needed for Ansible execution
- **Clean layers**: Package caches and temp files removed in every `RUN` instruction
- **HEALTHCHECK**: Built-in health probe verifies the Python/Ansible stack

### Runtime Hardening (docker-compose.yml)

- **Read-only filesystem**: `read_only: true` — container cannot modify its own image layers
- **tmpfs mounts**: `/tmp` (64MB) and `/home/ansible` (32MB) for ephemeral writes
- **No new privileges**: `security_opt: [no-new-privileges:true]` — prevents privilege escalation
- **All capabilities dropped**: `cap_drop: [ALL]` — minimal Linux capabilities
- **Resource limits**: Commented defaults for `mem_limit` (512m) and `cpus` (2.0)

When running with `docker run` directly, apply the same flags:

```bash
docker run --rm -it \
  --read-only \
  --tmpfs /tmp:size=64m \
  --tmpfs /home/ansible:size=32m \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  -v ~/code/rhel9-desktop-stig:/playbooks \
  -v ~/.ssh:/home/ansible/.ssh:ro \
  ansible-execution-env \
  ansible-playbook /playbooks/playbooks/harden.yml -i /playbooks/inventory/hosts
```

### Scanning & Linting

```bash
# Lint the Dockerfile (requires hadolint)
make lint

# Scan image for CVEs (requires trivy)
make scan

# Run all tests including security checks
make test
```

**Installing tools:**

- **Hadolint**: [github.com/hadolint/hadolint/releases](https://github.com/hadolint/hadolint/releases) — download binary or `brew install hadolint`
- **Trivy**: [aquasecurity.github.io/trivy](https://aquasecurity.github.io/trivy/latest/getting-started/installation/) — `curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh`

## Air-Gapped Environments

```bash
# Export image
make export
# Creates ansible-execution-env-0.1.0.tar.gz

# On target machine
docker load < ansible-execution-env-0.1.0.tar.gz
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `build` | Build the Docker image |
| `run` | Run default playbook with mounted directory |
| `shell` | Interactive bash shell in container |
| `test` | Verify tools, collections, non-root, and no SUID binaries |
| `lint` | Run hadolint on Dockerfile |
| `scan` | Run trivy image scan (HIGH/CRITICAL) |
| `export` | `docker save` + gzip for air-gap transfer |
| `clean` | Remove Docker image |

## Image Size

- Single-stage build for simplicity and reliability
- Package caches cleaned in same layer as install
- `.dockerignore` excludes repo metadata from build context

## Design Decisions

- **UBI9 full**: Matches RHEL 9 target OS for full parity — dnf available for reliable package management
- **Non-root**: Runs as `ansible` user (UID 1000) for security
- **No playbooks baked in**: Everything mounted at runtime for flexibility
- **Entrypoint**: Handles SSH key permissions even when mounted read-only
- **Tagged base image**: Base image pinned by version tag for reproducible builds

## CI/CD

A GitHub Actions pipeline (`.github/workflows/build.yml`) runs on every push to `main`, pull request, and manual dispatch:

| Job | What it does |
|-----|-------------|
| **lint** | Runs [Hadolint](https://github.com/hadolint/hadolint) on the Dockerfile |
| **build-and-test** | Builds the image, runs `make test` (Ansible, collections, non-root, no SUID) |
| **scan** | [Trivy](https://github.com/aquasecurity/trivy) vulnerability scan — fails on HIGH/CRITICAL |
| **push** | Tags and pushes to `ghcr.io/rwh85/ansible-execution-env` (main branch only) |

Images are tagged with both `latest` and the short commit SHA. Docker layer caching via GitHub Actions cache keeps builds fast.

To pull the published image:

```bash
docker pull ghcr.io/rwh85/ansible-execution-env:latest
```

## License

Proprietary. See [LICENSE](LICENSE).
