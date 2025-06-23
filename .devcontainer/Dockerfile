FROM ubuntu:24.04

ARG USER_UID=1001
ARG USER_GID=$USER_UID

ENV DEBIAN_FRONTEND=noninteractive

# Your optimized package installation
RUN set -eux; \
    apt-get update && apt-get install -y \
    python3 python3-pip python3-yaml python3-jinja2 python3-requests \
    python3-urllib3 python3-cryptography python3-venv python3-packaging \
    ansible openssh-client sshpass git curl wget vim nano jq tree htop \
    net-tools iputils-ping telnet unzip ca-certificates gnupg lsb-release \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Python packages in venv with Docker additions
RUN python3 -m venv /opt/venv --system-site-packages \
    && /opt/venv/bin/pip install --no-deps --no-cache-dir \
    jmespath netaddr hvac boto3 docker docker-compose \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:$PATH"

# Create user and docker group
RUN if ! getent group $USER_GID; then groupadd --gid $USER_GID ansible; fi \
    && useradd --uid $USER_UID --gid $USER_GID -m ansible \
    && echo 'ansible ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Docker group with proper GID and user addition
RUN groupadd -g 999 docker 2>/dev/null || groupmod -g 999 docker 2>/dev/null || true \
    && usermod -aG docker ansible

# SSH directory setup
RUN mkdir -p /home/ansible/.ssh \
    && chown -R ansible:ansible /home/ansible/.ssh \
    && chmod 700 /home/ansible/.ssh

RUN update-ca-certificates

WORKDIR /workspace
USER ansible

# Shell aliases
RUN echo 'alias ll="ls -la"' >> ~/.bashrc \
    && echo 'alias d="docker"' >> ~/.bashrc \
    && echo 'alias dc="docker compose"' >> ~/.bashrc \
    && echo 'alias ap="ansible-playbook"' >> ~/.bashrc

SHELL ["/bin/bash", "-c"]