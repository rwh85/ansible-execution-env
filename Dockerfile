# Ansible Execution Environment
# Base: UBI9 (RHEL 9) — full parity with target hardened systems

FROM registry.access.redhat.com/ubi9/ubi:9.5

LABEL maintainer="Russ Harvey <russell.w.harvey2@boeing.com>"
LABEL description="Ansible Execution Environment for rhel9-desktop-stig"

# Install Python 3.12, pip, and system dependencies
RUN dnf install -y \
        python3.12 \
        python3.12-pip \
        sshpass \
        openssh-clients \
        git-core \
        shadow-utils \
    && dnf clean all \
    && ln -sf /usr/bin/python3.12 /usr/bin/python3 \
    && ln -sf /usr/bin/pip3.12 /usr/bin/pip3

# Install Python packages and Ansible in a single layer
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel \
    && python3 -m pip install --no-cache-dir ansible-core -r /tmp/requirements.txt \
    && python3 -c "import paramiko, jmespath, yaml, cryptography; print('All Python packages verified')" \
    && ansible --version \
    && rm -f /tmp/requirements.txt

# Install Ansible Galaxy collections
COPY requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml -p /usr/share/ansible/collections \
    && rm -f /tmp/requirements.yml

# Create non-root user
RUN groupadd -g 1000 ansible \
    && useradd -u 1000 -g ansible -m -s /bin/bash ansible \
    && mkdir -p /playbooks \
    && chown ansible:ansible /playbooks

# Remove SUID/SGID bits — defense in depth
RUN find / -xdev -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true

# Ansible config
ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections
ENV ANSIBLE_HOST_KEY_CHECKING=False
ENV ANSIBLE_RETRY_FILES_ENABLED=False

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=2 \
    CMD python3 -c "import ansible; print('ok')" || exit 1

USER ansible
WORKDIR /playbooks

ENTRYPOINT ["entrypoint.sh"]
CMD ["ansible", "--version"]
