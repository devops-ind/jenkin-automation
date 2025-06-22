# Use Ubuntu as the base - provides stability and compatibility
FROM ubuntu:24.04

# Arguments passed from devcontainer.json
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
# We need Python, pip, and various tools for Ansible and development
RUN set -eux; \
    apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-yaml \
    python3-jinja2 \
    python3-requests \
    python3-urllib3 \
    python3-cryptography \
    python3-venv \
    python3-packaging \
    ansible \
    openssh-client \
    sshpass \
    git \
    curl \
    wget \
    vim \
    nano \
    jq \
    tree \
    htop \
    net-tools \
    iputils-ping \
    telnet \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (needed for Docker-in-Docker communication)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install additional Python packages for enhanced Ansible functionality
# These provide extra modules and better output formatting
RUN python3 -m venv /opt/venv --system-site-packages \
    && /opt/venv/bin/pip install --no-deps --no-cache-dir \
    jmespath \
    netaddr \
    hvac \
    boto3 \
    docker \
    docker-compose \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:$PATH"

# Create a non-root user for better security practices
# This mirrors your local user to avoid permission issues
RUN if ! getent group $USER_GID; then groupadd --gid $USER_GID ansible; fi \
    && useradd --uid $USER_UID --gid $USER_GID -m ansible \
    && echo 'ansible ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Create docker group with specific GID that matches the host (999 is common)
# and add ansible user to it for Docker socket access
RUN groupadd -g 999 docker 2>/dev/null || groupmod -g 999 docker 2>/dev/null || true \
    && usermod -aG docker ansible

# Set up SSH directory for the ansible user
# This is important for connecting to remote systems
RUN mkdir -p /home/ansible/.ssh \
    && chown -R ansible:ansible /home/ansible/.ssh \
    && chmod 700 /home/ansible/.ssh

# Copy your certificates into the container (optional - commented out for flexibility)
# This handles corporate SSL interception (Zscaler, DPI)
# COPY docker/zscaler.crt /usr/local/share/ca-certificates/zscaler.crt 2>/dev/null || true
# COPY docker/dpi.crt /usr/local/share/ca-certificates/dpi.crt 2>/dev/null || true

# Update the certificate store to include your corporate certificates
RUN update-ca-certificates

# Set the working directory to your project root
WORKDIR /workspace

# Switch to the non-root user
USER ansible

# Set up a basic shell environment
RUN echo 'alias ll="ls -la"' >> ~/.bashrc \
    && echo 'alias d="docker"' >> ~/.bashrc \
    && echo 'alias dc="docker compose"' >> ~/.bashrc \
    && echo 'alias ap="ansible-playbook"' >> ~/.bashrc \
    && echo 'alias k="kubectl"' >> ~/.bashrc

# Set default shell to bash
SHELL ["/bin/bash", "-c"]