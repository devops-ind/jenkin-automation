#!/bin/bash

# Lightweight post-create script that doesn't deploy Jenkins automatically
# This prevents container crashes during startup

set -e

echo "🚀 Setting up your Ansible development environment (lightweight mode)..."

# Navigate to the workspace
cd /workspace

# Install Ansible Galaxy requirements if they exist
if [ -f "ansible/requirements.yml" ]; then
    echo "📦 Installing Ansible Galaxy requirements..."
    ansible-galaxy collection install -r ansible/requirements.yml --force
    echo "✅ Ansible Galaxy requirements installed"
else
    echo "📦 Installing essential Ansible collections..."
    ansible-galaxy collection install community.docker community.general ansible.posix --force
    echo "✅ Essential collections installed"
fi

# Set up proper ownership of workspace files (excluding .git to avoid permission issues)
echo "🔧 Setting up file permissions..."
sudo find /workspace -maxdepth 1 -type d -not -name ".git" -exec chown -R ansible:ansible {} \; 2>/dev/null || true
sudo find /workspace -maxdepth 1 -type f -exec chown ansible:ansible {} \; 2>/dev/null || true
echo "✅ File permissions configured"

# Create necessary directories if they don't exist
mkdir -p /workspace/ansible/logs
mkdir -p /workspace/jenkins-deploy
mkdir -p /home/ansible/.ansible/tmp

# Set up Ansible configuration
if [ ! -f "/home/ansible/.ansible.cfg" ]; then
    echo "⚙️  Creating Ansible user configuration..."
    cat > /home/ansible/.ansible.cfg << EOF
[defaults]
inventory = /workspace/ansible/inventory
roles_path = /workspace/ansible/roles
host_key_checking = False
stdout_callback = default
callbacks_enabled = profile_tasks, timer
log_path = /workspace/ansible/logs/ansible.log
remote_tmp = /home/ansible/.ansible/tmp
local_tmp = /home/ansible/.ansible/tmp
deprecation_warnings = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
pipelining = True
EOF
    echo "✅ Ansible configuration created"
fi

# Test Ansible installation
echo "🔍 Testing Ansible installation..."
ansible --version
ansible-galaxy --version

# Test Docker connectivity and fix permissions if needed
echo "🐳 Testing Docker connectivity..."
if ! docker --version; then
    echo "❌ Docker CLI not available"
    exit 1
fi

# Fix Docker socket permissions if needed (your Dockerfile should handle this, but just in case)
if ! docker info >/dev/null 2>&1; then
    echo "🔧 Fixing Docker socket permissions..."
    sudo chown ansible:docker /var/run/docker.sock 2>/dev/null || true
    sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

docker --version
docker compose version

# Create a simple inventory test
if [ -f "/workspace/ansible/inventory/hosts.yml" ]; then
    echo "📋 Testing inventory configuration..."
    ansible-inventory --list > /dev/null && echo "✅ Inventory configuration is valid"
fi

# Set up Git configuration if not already configured
if [ ! -f "/home/ansible/.gitconfig" ]; then
    echo "📝 Setting up basic Git configuration..."
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    echo "ℹ️  You may want to set your Git user name and email:"
    echo "   git config --global user.name 'Your Name'"
    echo "   git config --global user.email 'your.email@example.com'"
fi

echo ""
echo "🎉 Development environment setup complete!"
echo ""
echo "💡 To deploy Jenkins, run:"
echo "   make local"
echo "   # OR"
echo "   cd ansible && ansible-playbook site.yml -e deployment_mode=local"
echo ""
echo "📚 Your Ansible development environment is ready!"

# Make the script file executable
chmod +x /workspace/.devcontainer/post-create-lite.sh