IMAGE_NAME := ansible-execution-env
VERSION    := 0.1.0
TAG        := $(IMAGE_NAME):$(VERSION)
LATEST     := $(IMAGE_NAME):latest
PLAYBOOK_DIR ?= $(HOME)/code/rhel9-desktop-stig
SSH_DIR      ?= $(HOME)/.ssh

.PHONY: build run shell test lint scan export clean

build:
	docker build -t $(TAG) -t $(LATEST) .

run:
	docker run --rm -it \
		-v $(PLAYBOOK_DIR):/playbooks \
		-v $(SSH_DIR):/home/ansible/.ssh:ro \
		$(LATEST) \
		ansible-playbook /playbooks/playbooks/harden.yml -i /playbooks/inventory/hosts

shell:
	docker run --rm -it \
		-v $(PLAYBOOK_DIR):/playbooks \
		-v $(SSH_DIR):/home/ansible/.ssh:ro \
		$(LATEST) \
		/bin/bash

test:
	@echo "=== Verifying Ansible Execution Environment ==="
	docker run --rm --entrypoint "" $(LATEST) ansible --version
	docker run --rm --entrypoint "" $(LATEST) ansible-galaxy collection list
	docker run --rm --entrypoint "" $(LATEST) python3 -c "import paramiko, jmespath, yaml, cryptography; print('Python packages OK')"
	docker run --rm --entrypoint "" $(LATEST) sh -c "which sshpass && which ssh && which git && echo 'System tools OK'"
	@echo "--- Security checks ---"
	docker run --rm --entrypoint "" $(LATEST) sh -c '[ "$$(id -u)" -ne 0 ] && echo "Non-root OK (uid=$$(id -u))" || (echo "FAIL: running as root" && exit 1)'
	docker run --rm --entrypoint "" $(LATEST) sh -c 'count=$$(find / -xdev -perm /6000 -type f 2>/dev/null | wc -l); echo "SUID/SGID binaries: $$count"; [ "$$count" -eq 0 ] && echo "No SUID/SGID OK" || echo "WARN: $$count SUID/SGID binaries (review manually)"'
	@echo "=== All checks passed ==="

lint:
	@echo "=== Linting Dockerfile with Hadolint ==="
	@command -v hadolint >/dev/null 2>&1 || { echo "Install hadolint: https://github.com/hadolint/hadolint/releases"; exit 1; }
	hadolint Dockerfile

scan:
	@echo "=== Scanning image with Trivy ==="
	@command -v trivy >/dev/null 2>&1 || { echo "Install trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"; exit 1; }
	trivy image --severity HIGH,CRITICAL $(LATEST)

export:
	docker save $(LATEST) | gzip > $(IMAGE_NAME)-$(VERSION).tar.gz
	@echo "Exported to $(IMAGE_NAME)-$(VERSION).tar.gz"

clean:
	docker rmi $(TAG) $(LATEST) 2>/dev/null || true
