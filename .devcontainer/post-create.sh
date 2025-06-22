#!/bin/bash

# This script runs after your dev container is created
# It sets up your development environment and deploys Jenkins automatically

set -e  # Exit on any error

echo "🚀 Setting up your Ansible + Jenkins development environment..."

# Navigate to the workspace
cd /workspace

# Install Ansible Galaxy requirements if they exist
if [ -f "ansible/requirements.yml" ]; then
    echo "📦 Installing Ansible Galaxy requirements..."
    ansible-galaxy install -r ansible/requirements.yml --force
    ansible-galaxy collection install -r ansible/requirements.yml --force
    echo "✅ Ansible Galaxy requirements installed"
else
    echo "📦 Installing essential Ansible collections..."
    ansible-galaxy collection install community.docker community.general ansible.posix --force
    echo "✅ Essential collections installed"
fi

# Set up proper ownership of workspace files (excluding .git to avoid permission issues)
echo "🔧 Setting up file permissions..."
# Create a list of directories to fix permissions for, excluding .git
sudo find /workspace -maxdepth 1 -type d -not -name ".git" -exec chown -R ansible:ansible {} \; 2>/dev/null || true
# Fix individual files in the root workspace directory
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
stdout_callback = yaml
callbacks_enabled = profile_tasks, timer
log_path = /workspace/ansible/logs/ansible.log
remote_tmp = /home/ansible/.ansible/tmp
local_tmp = /home/ansible/.ansible/tmp

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
    
    # Test again after permission fix
    if ! docker info >/dev/null 2>&1; then
        echo "⚠️  Docker daemon not accessible, attempting to start..."
        sudo service docker start 2>/dev/null || true
        sleep 5
    fi
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

# Auto-deploy Jenkins in local mode with better error handling
echo ""
echo "🚀 Auto-deploying Jenkins infrastructure in local mode..."
echo ""

# Set environment for local deployment
export DEPLOYMENT_MODE=local
export JENKINS_ADMIN_USER=admin
export JENKINS_ADMIN_PASSWORD=admin123

# Run Ansible playbook to deploy Jenkins with timeout
cd /workspace/ansible
timeout 600 ansible-playbook site.yml -e deployment_mode=local 2>&1 | tee /tmp/ansible-deploy.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "🎉 Jenkins deployment completed successfully!"
    echo ""
    echo "🌐 Jenkins is available at: http://localhost:8080"
    echo "👤 Username: admin"
    echo "🔐 Password: admin123"
    echo ""
elif [ ${PIPESTATUS[0]} -eq 124 ]; then
    echo ""
    echo "⏰ Jenkins deployment timed out (10 minutes)"
    echo "   This might be due to slow Docker image pulls or resource constraints"
    echo "   You can manually retry with: ansible-playbook site.yml -e deployment_mode=local"
    echo ""
else
    echo ""
    echo "⚠️  Jenkins deployment encountered an issue, but dev environment is ready"
    echo "   Check logs: cat /tmp/ansible-deploy.log"
    echo "   You can manually deploy Jenkins with: ansible-playbook site.yml -e deployment_mode=local"
    echo ""
fi

echo ""
echo "🎉 Development environment setup complete!"
echo ""
echo "💡 Quick start commands:"
echo "   • Deploy Jenkins locally:     ansible-playbook site.yml -e deployment_mode=local"
echo "   • Deploy to remote VM:        DEPLOYMENT_MODE=remote ansible-playbook site.yml"
echo "   • Check Jenkins status:       docker ps"
echo "   • View Jenkins logs:          docker logs jenkins-master"
echo "   • Access Jenkins:             http://localhost:8080"
echo ""
echo "📚 Your unified Ansible + Jenkins environment is ready!"

# Make the script file executable
chmod +x /workspace/.devcontainer/post-create.sh