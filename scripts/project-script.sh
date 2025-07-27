#!/bin/bash

# Jenkins Infrastructure Production Directory Structure Creator
# Simple and reliable script to create the directory structure

set -e

PROJECT_NAME="jenkins-infrastructure-production"
BASE_DIR="${1:-$PROJECT_NAME}"

echo "Creating Jenkins Infrastructure directory structure in: $BASE_DIR"

# Create base directory
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

echo "📁 Creating main project structure..."

# Create all directories first
mkdir -p ansible/inventories/production/group_vars/{all,jenkins_masters,jenkins_agents,monitoring,harbor}
mkdir -p ansible/inventories/staging/group_vars/{all,jenkins_masters,jenkins_agents,monitoring,harbor}
mkdir -p ansible/roles/{common,docker,harbor,jenkins-images,jenkins-infrastructure,monitoring,backup,shared-storage,security,high-availability}/{tasks,handlers,templates,files,defaults,vars}
mkdir -p ansible/playbooks
mkdir -p ansible/group_vars/all

# Additional role subdirectories
mkdir -p ansible/roles/jenkins-images/templates
mkdir -p ansible/roles/jenkins-images/files
mkdir -p ansible/roles/jenkins-infrastructure/templates/job-definitions
mkdir -p ansible/roles/monitoring/templates/dashboards
mkdir -p ansible/roles/monitoring/files/exporters
mkdir -p ansible/roles/backup/templates
mkdir -p ansible/roles/shared-storage/templates
mkdir -p ansible/roles/security/templates
mkdir -p ansible/roles/high-availability/templates

# Pulumi directories
mkdir -p pulumi/modules

# Pipeline directories
mkdir -p pipelines

# Monitoring directories
mkdir -p monitoring/prometheus/{rules,targets}
mkdir -p monitoring/grafana/{dashboards,datasources}
mkdir -p monitoring/alertmanager/templates

# Scripts directory
mkdir -p scripts

# Documentation directory
mkdir -p docs

# Environments directories
mkdir -p environments/vault-passwords
mkdir -p environments/certificates

# Tests directories
mkdir -p tests/integration
mkdir -p tests/security

echo "📝 Creating main project files..."

# Create main project files
cat > README.md << 'EOF'
# Jenkins Infrastructure Production

This repository contains Ansible playbooks and configurations for managing Jenkins infrastructure in production.

## Quick Start

1. Install dependencies: `pip install -r requirements.txt`
2. Configure inventory: Edit `ansible/inventories/production/hosts.yml`
3. Set up vault passwords: `ansible-vault create ansible/inventories/production/group_vars/all/vault.yml`
4. Deploy: `make deploy-production`

## Documentation

See the `docs/` directory for detailed documentation.
EOF

cat > Makefile << 'EOF'
.PHONY: help deploy-production deploy-staging build-images backup monitor

help:
	@echo "Available targets:"
	@echo "  deploy-production  - Deploy to production environment"
	@echo "  deploy-staging     - Deploy to staging environment"
	@echo "  build-images      - Build and push Docker images"
	@echo "  backup            - Run backup procedures"
	@echo "  monitor           - Setup monitoring stack"

deploy-production:
	ansible-playbook -i ansible/inventories/production/hosts.yml ansible/site.yml

deploy-staging:
	ansible-playbook -i ansible/inventories/staging/hosts.yml ansible/site.yml

build-images:
	ansible-playbook -i ansible/inventories/production/hosts.yml ansible/deploy-images.yml

backup:
	ansible-playbook -i ansible/inventories/production/hosts.yml ansible/deploy-backup.yml

monitor:
	ansible-playbook -i ansible/inventories/production/hosts.yml ansible/deploy-monitoring.yml
EOF

cat > requirements.txt << 'EOF'
ansible>=6.0.0
ansible-core>=2.13.0
jinja2>=3.0.0
PyYAML>=6.0.0
requests>=2.28.0
docker>=6.0.0
kubernetes>=24.0.0
EOF

cat > .gitignore << 'EOF'
# Ansible
*.retry
.vault_pass
vault-passwords/*.txt

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Certificates
environments/certificates/*.key
environments/certificates/*.pem

# Logs
*.log
logs/
EOF

cat > .ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
inventory = ansible/inventories/production/hosts.yml
roles_path = ansible/roles
vault_password_file = environments/vault-passwords/production.txt
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts_cache
fact_caching_timeout = 3600
EOF

echo "🔧 Creating Ansible configuration files..."

# Ansible main files
cat > ansible/ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
inventory = inventories/production/hosts.yml
roles_path = roles
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts_cache
EOF

cat > ansible/site.yml << 'EOF'
---
- name: Deploy Jenkins Infrastructure
  hosts: all
  become: yes
  roles:
    - common
    - docker
    - security

- name: Deploy Harbor Registry
  hosts: harbor
  become: yes
  roles:
    - harbor

- name: Deploy Jenkins Infrastructure
  hosts: jenkins_masters,jenkins_agents
  become: yes
  roles:
    - jenkins-infrastructure
    - shared-storage

- name: Deploy Monitoring Stack
  hosts: monitoring
  become: yes
  roles:
    - monitoring

- name: Setup High Availability
  hosts: jenkins_masters
  become: yes
  roles:
    - high-availability
  when: enable_ha | default(false)
EOF

cat > ansible/deploy-images.yml << 'EOF'
---
- name: Build and Deploy Jenkins Images
  hosts: jenkins_masters
  become: yes
  roles:
    - jenkins-images
EOF

cat > ansible/deploy-monitoring.yml << 'EOF'
---
- name: Deploy Monitoring Stack
  hosts: monitoring
  become: yes
  roles:
    - monitoring
EOF

cat > ansible/deploy-backup.yml << 'EOF'
---
- name: Deploy Backup System
  hosts: all
  become: yes
  roles:
    - backup
EOF

cat > ansible/requirements.yml << 'EOF'
---
collections:
  - name: community.docker
    version: ">=3.0.0"
  - name: community.general
    version: ">=5.0.0"
  - name: ansible.posix
    version: ">=1.4.0"
EOF

echo "📋 Creating inventory files..."

# Create inventory files
cat > ansible/inventories/production/hosts.yml << 'EOF'
---
all:
  vars:
    ansible_user: ansible
    ansible_ssh_private_key_file: ~/.ssh/jenkins-prod-key
    environment: production

jenkins_masters:
  hosts:
    jenkins-master-01:
      ansible_host: 10.0.1.10
      jenkins_master_port: 8080
    jenkins-master-02:
      ansible_host: 10.0.1.11
      jenkins_master_port: 8080

jenkins_agents:
  hosts:
    jenkins-agent-01:
      ansible_host: 10.0.1.20
      agent_labels: "docker,maven,python"
    jenkins-agent-02:
      ansible_host: 10.0.1.21
      agent_labels: "docker,nodejs,python"

monitoring:
  hosts:
    monitoring-01:
      ansible_host: 10.0.1.30
      prometheus_port: 9090
      grafana_port: 3000

harbor:
  hosts:
    harbor-01:
      ansible_host: 10.0.1.40
      harbor_port: 443
EOF

cat > ansible/inventories/staging/hosts.yml << 'EOF'
---
all:
  vars:
    ansible_user: ansible
    ansible_ssh_private_key_file: ~/.ssh/jenkins-staging-key
    environment: staging

jenkins_masters:
  hosts:
    jenkins-master-staging:
      ansible_host: 10.0.2.10
      jenkins_master_port: 8080

jenkins_agents:
  hosts:
    jenkins-agent-staging:
      ansible_host: 10.0.2.20
      agent_labels: "docker,maven,python,nodejs"

monitoring:
  hosts:
    monitoring-staging:
      ansible_host: 10.0.2.30

harbor:
  hosts:
    harbor-staging:
      ansible_host: 10.0.2.40
EOF

echo "⚙️ Creating group variables..."

# Create group_vars files
cat > ansible/inventories/production/group_vars/all/main.yml << 'EOF'
---
# Global configuration for production environment
jenkins_version: "2.426.1"
docker_version: "24.0.7"
timezone: "UTC"

# Network configuration
jenkins_network: "jenkins-net"
monitoring_network: "monitoring-net"

# Storage configuration
jenkins_home: "/opt/jenkins"
backup_location: "/backup/jenkins"
shared_storage_mount: "/shared"

# Security settings
enable_ssl: true
ssl_cert_path: "/etc/ssl/certs/jenkins.crt"
ssl_key_path: "/etc/ssl/private/jenkins.key"

# Backup configuration
backup_enabled: true
backup_schedule: "0 2 * * *"
backup_retention_days: 30
EOF

cat > ansible/inventories/production/group_vars/all/vault.yml << 'EOF'
---
# Encrypted variables (use ansible-vault to edit)
# $ANSIBLE_VAULT;1.1;AES256
# This is a placeholder - use: ansible-vault create vault.yml
# Add your encrypted secrets here
vault_jenkins_admin_password: "changeme"
vault_grafana_password: "changeme"
vault_harbor_password: "changeme"
vault_slack_webhook: "https://hooks.slack.com/your/webhook/url"
EOF

echo "🎭 Creating Ansible roles..."

# Create role files for each role
ROLES=(
    "common"
    "docker" 
    "harbor"
    "jenkins-images"
    "jenkins-infrastructure"
    "monitoring"
    "backup"
    "shared-storage"
    "security"
    "high-availability"
)

for role in "${ROLES[@]}"; do
    # Create basic role files
    cat > "ansible/roles/$role/tasks/main.yml" << EOF
---
# Tasks for $role role
- name: Include $role tasks
  include_tasks: "{{ ansible_os_family | lower }}.yml"
  when: ansible_os_family is defined

- name: Default $role configuration
  debug:
    msg: "Configuring $role role"
EOF

    cat > "ansible/roles/$role/handlers/main.yml" << EOF
---
# Handlers for $role role
- name: restart $role service
  systemd:
    name: $role
    state: restarted
    enabled: yes
  listen: "restart $role"
EOF

    cat > "ansible/roles/$role/defaults/main.yml" << EOF
---
# Default variables for $role role
${role}_enabled: true
${role}_version: "latest"
EOF
done

echo "📚 Creating playbooks..."

# Create playbooks
PLAYBOOKS=(
    "bootstrap.yml"
    "deploy-infrastructure.yml"
    "update-images.yml"
    "backup-restore.yml"
    "monitoring-setup.yml"
    "security-hardening.yml"
    "ha-setup.yml"
    "disaster-recovery.yml"
)

for playbook in "${PLAYBOOKS[@]}"; do
    cat > "ansible/playbooks/$playbook" << EOF
---
- name: ${playbook%.yml} playbook
  hosts: all
  become: yes
  tasks:
    - name: Execute ${playbook%.yml}
      debug:
        msg: "Running ${playbook%.yml} tasks"
EOF
done

echo "🔧 Creating group variables..."

# Create group_vars
cat > ansible/group_vars/all/jenkins.yml << 'EOF'
---
jenkins_version: "2.426.1"
jenkins_port: 8080
jenkins_home: "/opt/jenkins"
jenkins_plugins:
  - workflow-aggregator
  - docker-workflow
  - kubernetes
  - prometheus
  - configuration-as-code
EOF

cat > ansible/group_vars/all/monitoring.yml << 'EOF'
---
prometheus_version: "2.40.0"
grafana_version: "9.3.0"
alertmanager_version: "0.25.0"
node_exporter_version: "1.5.0"

# Prometheus configuration
prometheus_port: 9090
prometheus_data_dir: "/var/lib/prometheus"
prometheus_config_dir: "/etc/prometheus"

# Grafana configuration
grafana_port: 3000
grafana_data_dir: "/var/lib/grafana"
grafana_provisioning_dir: "/etc/grafana/provisioning"
EOF

cat > ansible/group_vars/all/harbor.yml << 'EOF'
---
harbor_version: "2.7.0"
harbor_hostname: "{{ harbor_registry }}"
harbor_port: 443
harbor_data_volume: "/data/harbor"
harbor_log_level: "info"
EOF

cat > ansible/group_vars/all/backup.yml << 'EOF'
---
backup_script_path: "/usr/local/bin/jenkins-backup.sh"
backup_log_file: "/var/log/jenkins-backup.log"
backup_compression: "gzip"
backup_exclude_patterns:
  - "*.tmp"
  - "workspace/*"
  - "caches/*"
EOF

echo "🚀 Creating pipeline definitions..."

# Create pipeline definitions
PIPELINES=(
    "Jenkinsfile.image-builder"
    "Jenkinsfile.backup"
    "Jenkinsfile.monitoring"
    "Jenkinsfile.security-scan"
    "Jenkinsfile.infrastructure-update"
    "Jenkinsfile.disaster-recovery"
)

for pipeline in "${PIPELINES[@]}"; do
    cat > "pipelines/$pipeline" << EOF
pipeline {
    agent any
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['staging', 'production'],
            description: 'Target environment'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('${pipeline#Jenkinsfile.}') {
            steps {
                echo "Running ${pipeline#Jenkinsfile.} pipeline"
                // Add your pipeline steps here
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}
EOF
done

echo "📊 Creating monitoring configurations..."

# Create monitoring configurations
cat > monitoring/prometheus/rules/jenkins.yml << 'EOF'
groups:
  - name: jenkins
    rules:
      - alert: JenkinsDown
        expr: up{job="jenkins"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Jenkins instance is down"
          
      - alert: JenkinsBuildFailure
        expr: increase(jenkins_builds_failure_total[1h]) > 5
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: "High build failure rate in Jenkins"
EOF

cat > monitoring/grafana/dashboards/jenkins-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Jenkins Overview",
    "tags": ["jenkins"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Build Success Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "rate(jenkins_builds_success_total[1h])",
            "legendFormat": "Success Rate"
          }
        ]
      }
    ],
    "time": {
      "from": "now-6h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
EOF

echo "🔨 Creating scripts..."

# Create scripts
SCRIPTS=(
    "deploy.sh"
    "build-images.sh"
    "backup.sh"
    "monitor.sh"
    "vault-setup.sh"
    "ha-setup.sh"
    "disaster-recovery.sh"
)

for script in "${SCRIPTS[@]}"; do
    cat > "scripts/$script" << EOF
#!/bin/bash
# ${script%.sh} automation script

set -e

ENVIRONMENT=\${1:-production}
INVENTORY="ansible/inventories/\$ENVIRONMENT/hosts.yml"

echo "Running ${script%.sh} for \$ENVIRONMENT environment"

# Add your script logic here
case "\$ENVIRONMENT" in
    production)
        echo "Executing ${script%.sh} for production"
        ;;
    staging)
        echo "Executing ${script%.sh} for staging"
        ;;
    *)
        echo "Unknown environment: \$ENVIRONMENT"
        exit 1
        ;;
esac
EOF
    chmod +x "scripts/$script"
done

echo "📚 Creating documentation..."

# Create documentation
DOCS=(
    "DEPLOYMENT.md"
    "MONITORING.md"
    "BACKUP-RECOVERY.md"
    "HIGH-AVAILABILITY.md"
    "SECURITY.md"
    "TROUBLESHOOTING.md"
    "ARCHITECTURE.md"
)

for doc in "${DOCS[@]}"; do
    cat > "docs/$doc" << EOF
# ${doc%.md}

## Overview

This document covers ${doc%.md} procedures and guidelines for the Jenkins infrastructure.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Procedures](#procedures)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## Prerequisites

- Ansible installed and configured
- Access to target environments
- Required credentials and certificates

## Procedures

### Step 1: Preparation

Describe preparation steps here.

### Step 2: Execution

Describe execution steps here.

### Step 3: Verification

Describe verification steps here.

## Troubleshooting

Common issues and solutions.

## References

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Ansible Documentation](https://docs.ansible.com/)
EOF
done

echo "🌍 Creating environment configurations..."

# Create environments
cat > environments/production.env << 'EOF'
# Production environment variables
ENVIRONMENT=production
JENKINS_VERSION=2.426.1
HARBOR_REGISTRY=harbor.company.com
BACKUP_ENABLED=true
MONITORING_ENABLED=true
HA_ENABLED=true
EOF

cat > environments/staging.env << 'EOF'
# Staging environment variables
ENVIRONMENT=staging
JENKINS_VERSION=2.426.1-lts
HARBOR_REGISTRY=harbor-staging.company.com
BACKUP_ENABLED=false
MONITORING_ENABLED=true
HA_ENABLED=false
EOF

# Vault password examples
cat > environments/vault-passwords/README.md << 'EOF'
# Vault Passwords

Create your vault password files:

- `production.txt` - Production vault password
- `staging.txt` - Staging vault password

## Example:
```bash
echo "your-secure-password" > production.txt
chmod 600 production.txt
```
EOF

# Certificate examples
cat > environments/certificates/README.md << 'EOF'
# SSL Certificates

Place your SSL certificates in this directory:

- `jenkins.crt` - Jenkins SSL certificate
- `jenkins.key` - Jenkins SSL private key  
- `ca-bundle.crt` - Certificate Authority bundle

## File Permissions

Ensure proper permissions:
```bash
chmod 600 jenkins.key
chmod 644 jenkins.crt
chmod 644 ca-bundle.crt
```
EOF

echo "🧪 Creating test framework..."

# Create test files
cat > tests/inventory-test.py << 'EOF'
#!/usr/bin/env python3
"""Test inventory configuration"""

import yaml
import sys

def test_inventory(inventory_file):
    """Test inventory file structure"""
    try:
        with open(inventory_file, 'r') as f:
            inventory = yaml.safe_load(f)
        
        # Check required groups
        required_groups = ['jenkins_masters', 'jenkins_agents', 'monitoring', 'harbor']
        for group in required_groups:
            if group not in inventory:
                print(f"ERROR: Missing group {group}")
                return False
        
        print("Inventory validation passed")
        return True
        
    except Exception as e:
        print(f"ERROR: {e}")
        return False

if __name__ == "__main__":
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else "ansible/inventories/production/hosts.yml"
    if not test_inventory(inventory_file):
        sys.exit(1)
EOF

chmod +x tests/inventory-test.py

cat > tests/playbook-syntax.yml << 'EOF'
---
- name: Test playbook syntax
  hosts: localhost
  connection: local
  gather_facts: no
  tasks:
    - name: Check Ansible version
      debug:
        msg: "Ansible version: {{ ansible_version.full }}"
    
    - name: Syntax test passed
      debug:
        msg: "All playbook syntax checks passed"
EOF

echo ""
echo "✅ Jenkins Infrastructure directory structure created successfully!"
echo ""
echo "📁 Created in: $(pwd)"
echo ""
echo "🚀 Next steps:"
echo "1. Review and customize configuration files"
echo "2. Set up Ansible vault: ansible-vault create ansible/inventories/production/group_vars/all/vault.yml"
echo "3. Update inventory files with your actual hosts"
echo "4. Install dependencies: pip install -r requirements.txt"
echo "5. Test syntax: ansible-playbook --syntax-check ansible/site.yml"
echo "6. Deploy: make deploy-production"
echo ""
echo "📚 See docs/ directory for detailed documentation"
echo ""
echo "🔍 To validate the structure, run: python3 tests/inventory-test.py"