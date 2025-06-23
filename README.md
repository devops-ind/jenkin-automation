# Unified Jenkins Infrastructure with Ansible

A complete, production-ready Jenkins infrastructure deployment system using Ansible and Docker. Supports both local development in dev containers and remote VM deployments with the same codebase.

## 🏗️ Architecture Overview

- **Ansible-driven**: Infrastructure as Code with version-controlled configurations
- **Docker-based**: Consistent environments using containerization
- **Dual deployment**: Same codebase works for local development and remote production
- **JCasC configuration**: Jenkins configured entirely through code
- **Mixed agent strategy**: Static DIND agent + dynamic Python/Maven agents

### Components

- **Jenkins Master**: Web UI and job orchestration
- **Static DIND Agent**: Always-available Docker-in-Docker agent for privileged operations
- **Dynamic Agents**: On-demand Maven and Python build agents
- **Ansible Roles**: Automated deployment and configuration management

## 🚀 Quick Start

### Prerequisites

- **Docker and Docker Compose v2**: Required for container management
- **VS Code with Dev Containers extension**: For local development
- **SSH access to target VM**: For remote deployment (with sudo privileges)
- **Python 3.8+**: For Ansible execution

### 1. Dev Container Setup (Automatic)

When you open this project in VS Code with Dev Containers:

```bash
# Automatically runs when dev container starts:
# 1. Sets up Ansible environment with required collections
# 2. Installs Docker collections (community.docker v3.4+)
# 3. Deploys Jenkins infrastructure locally
# 4. Jenkins available at http://localhost:8080 (admin/admin123)
```

### 2. Manual Deployment

```bash
# Local deployment (in dev container)
make local

# Remote deployment (requires DOCKER_HOST_IP)
DOCKER_HOST_IP=192.168.1.100 make remote

# Using the deployment script directly
scripts/deploy.sh --mode local deploy
DOCKER_HOST_IP=192.168.1.100 scripts/deploy.sh --mode remote deploy
```

## 🎯 Usage Examples

### Local Development Workflow

```bash
# Quick setup (automatic in dev container)
make init                    # Setup + deploy locally

# Development cycle
make rebuild                 # Rebuild with changes
make logs                    # View Jenkins logs
make status                  # Check service status

# Manual deployment if needed
cd ansible
ansible-playbook site.yml -e deployment_mode=local

# Access Jenkins
# URL: http://localhost:8080
# Username: admin
# Password: admin123
```

### Remote Production Deployment

```bash
# Set target VM
export DOCKER_HOST_IP=192.168.1.100
export ANSIBLE_USER=ubuntu
export SSH_KEY_PATH=~/.ssh/id_rsa

# Deploy
make remote

# Manage
make logs-remote             # View remote logs
make restart-remote          # Restart services
make shell-remote           # SSH to remote host
```

### Pipeline Development

Create pipelines using available agent labels:

```groovy
pipeline {
    agent none
    stages {
        stage('Build') {
            parallel {
                stage('Java Build') {
                    agent { label 'maven java dynamic' }
                    steps {
                        sh 'mvn clean package'
                    }
                }
                stage('Python Build') {
                    agent { label 'python py dynamic' }
                    steps {
                        sh 'pip install -r requirements.txt && pytest'
                    }
                }
            }
        }
        stage('Docker Operations') {
            agent { label 'dind docker-manager static' }
            steps {
                sh 'docker build -t myapp .'
            }
        }
    }
}
```

## 🔧 Available Agent Types

### Static DIND Agent
- **Labels**: `dind docker-manager static privileged`
- **Purpose**: Docker operations, image building, privileged tasks
- **Always available**: Yes
- **Capabilities**: Full Docker access, container management

### Dynamic Maven Agent
- **Labels**: `maven java dynamic`
- **Purpose**: Java/Maven builds, JUnit tests
- **Auto-provisioned**: Created on-demand, destroyed when idle
- **Capabilities**: Multiple JDK versions, Maven, Gradle

### Dynamic Python Agent
- **Labels**: `python py dynamic`
- **Purpose**: Python builds, pytest, pip packages
- **Auto-provisioned**: Created on-demand, destroyed when idle
- **Capabilities**: Python 3.x, pip, pytest, common libraries

## 📁 Project Structure

jenkins-automation/
├── .devcontainer/              # VS Code dev container configuration
│   ├── devcontainer.json       # UPDATED: UID 1001, Docker socket fixes
│   ├── Dockerfile              # UPDATED: Your optimized Ubuntu 24.04 + additions
│   └── post-create.sh          # UPDATED: Platform-specific Docker permissions
├── ansible/                    # Ansible infrastructure automation
│   ├── site.yml                # COMPLETELY REWRITTEN: HAProxy integration
│   ├── ansible.cfg             # UPDATED: Deprecation warnings disabled
│   ├── requirements.yml        # NEW: Docker Compose v2 collections
│   ├── inventory/              # Environment definitions
│   │   └── hosts.yml           # UPDATED: Domain and SSL variables
│   └── roles/                  # Ansible roles
│       ├── docker/             # NEW: Docker installation role
│       │   ├── tasks/main.yml  # NEW: RHEL-compatible Docker installation
│       │   ├── defaults/main.yml # NEW: Docker configuration defaults
│       │   └── vars/
│       │       └── debian.yml  # NEW: Debian/Ubuntu variables
│       └── jenkins/            # MAJOR UPDATE: Complete infrastructure role
│           ├── tasks/main.yml  # MAJOR UPDATE: HAProxy + SSL management
│           ├── defaults/main.yml # MAJOR UPDATE: Domain/SSL/HAProxy config
│           └── templates/      # Configuration templates
│               ├── docker-compose.jenkins.yml.j2 # UPDATED: HAProxy service
│               ├── jenkins.yml.j2 # Jenkins Configuration as Code
│               ├── haproxy.cfg.j2 # NEW: HAProxy with SSL termination
│               ├── Dockerfile.master.j2 # Jenkins master container
│               ├── Dockerfile.dind.j2 # DIND agent container
│               ├── Dockerfile.haproxy.j2 # NEW: HAProxy container
│               ├── plugins.txt.j2 # Jenkins plugins list
│               └── jenkins.env.j2 # Environment variables
├── environments/               # NEW: Platform-specific configurations
│   ├── dev-local.env          # NEW: Windows WSL/macOS/Linux development
│   └── prod-rhel.env          # NEW: RHEL production server
├── scripts/                   # Deployment and management
│   └── deploy.sh              # MAJOR UPDATE: Cross-platform + SSL support
├── examples/                  # Sample configurations
│   └── sample-pipeline.groovy # Pipeline examples for all agent types
├── Makefile                   # UPDATED: SSL setup, platform detection
├── README.md                  # COMPLETELY REWRITTEN: Enterprise documentation
└── IMPLEMENTATION_GUIDE.md    # NEW: This complete implementation guide


## ⚙️ Configuration

### Environment Variables

```bash
# Deployment mode
DEPLOYMENT_MODE=local          # or 'remote'

# Remote deployment (required for remote mode)
DOCKER_HOST_IP=192.168.1.100  # Target VM IP address
ANSIBLE_USER=ubuntu            # SSH user (must have sudo access)
SSH_KEY_PATH=~/.ssh/id_rsa     # SSH private key

# Jenkins configuration
JENKINS_ADMIN_USER=admin       # Jenkins admin username
JENKINS_ADMIN_PASSWORD=admin123 # Jenkins admin password (change in production!)
```

### Required Ansible Collections

The project automatically installs these collections via `ansible/requirements.yml`:

```yaml
collections:
  - community.docker: ">=3.4.0,<4.0.0"  # Docker Compose v2 support
  - community.general: ">=7.0.0"         # General utilities
  - ansible.posix: ">=1.5.0"             # POSIX utilities
```

**Note**: We use Docker Compose v2 (`docker_compose_v2` module). Docker Compose v1 is deprecated as of July 2022.

### Customizing Jenkins

#### Adding New Dynamic Agents

1. **Edit role defaults** (`ansible/roles/jenkins/defaults/main.yml`):
```yaml
jenkins_dynamic_agents:
  nodejs:
    image: "jenkins/inbound-agent:latest-node"
    labels: "nodejs javascript dynamic"
    instance_cap: 3
    idle_minutes: 10
    environment:
      NODE_VERSION: "18.17.1"
    mounts:
      - "type=volume,source=npm-cache,destination=/home/jenkins/.npm"
```

2. **Redeploy**:
```bash
make rebuild
```

#### Modifying Memory Settings

Edit the role defaults for different deployment modes:
```yaml
jenkins_master_memory: "{{ deployment_mode == 'local' and '2g' or '4g' }}"
```

#### Adding Custom Plugins

Add to the plugins list in role defaults:
```yaml
jenkins_plugins:
  - "your-custom-plugin:latest"
```

## 🔍 Monitoring and Troubleshooting

### Health Checks

```bash
# Check overall status
make status

# View logs
make logs                      # Local logs
make logs-remote              # Remote logs

# Container status
docker ps                     # Local containers
ssh user@remote "docker ps"   # Remote containers
```

### Common Issues

#### Jenkins Won't Start
```bash
# Check logs
make logs

# Common causes:
# 1. Port 8080 already in use
# 2. Insufficient memory  
# 3. Docker socket permissions
# 4. Docker Compose v2 not available
```

#### Docker Compose Version Issues
```bash
# Ensure Docker Compose v2 is installed
docker compose version

# Should show v2.x.x, not v1.x.x
# If you see v1, update Docker Desktop or install Compose v2
```

#### Ansible Collection Issues
```bash
# Reinstall collections if needed
ansible-galaxy collection install community.docker --force
ansible-galaxy collection install community.general --force

# Check installed collections
ansible-galaxy collection list
```

#### Dynamic Agents Not Starting
```bash
# Check Docker cloud configuration in Jenkins UI:
# Manage Jenkins > Clouds > docker-cloud-local

# Verify agent templates and Docker connectivity
docker network ls | grep jenkins
```

#### Remote Deployment Fails
```bash
# Test SSH connectivity
ssh -o ConnectTimeout=5 user@remote-ip "echo 'Connection test'"

# Verify Docker installation on remote
ssh user@remote-ip "docker --version && docker compose version"

# Check sudo access
ssh user@remote-ip "sudo docker ps"

# Check Ansible inventory
ansible-inventory --list
```

### Log Locations

```bash
# Ansible logs
tail -f ansible/logs/ansible.log

# Jenkins master logs
docker logs -f jenkins-master

# DIND agent logs
docker logs -f jenkins-agent-dind

# Deployment logs
tail -f /workspace/jenkins-deploy/deployment-info.txt  # Local
tail -f /opt/jenkins/deployment-info.txt              # Remote
```

## 🔒 Security Considerations

### Production Checklist

- [ ] Change default Jenkins admin password
- [ ] Configure proper authentication (LDAP, OAuth, etc.)
- [ ] Enable HTTPS with valid SSL certificates
- [ ] Restrict Docker socket access
- [ ] Configure firewall rules
- [ ] Set up regular backups
- [ ] Review agent permissions

### SSL Configuration

Enable SSL by setting variables:
```yaml
jenkins_ssl_enabled: true
jenkins_ssl_cert_path: "/path/to/certificates"
```

## 💾 Backup and Recovery

### Creating Backups

```bash
# Automated backup
make backup

# Manual backup
timestamp=$(date +%Y%m%d_%H%M%S)
docker exec jenkins-master tar czf /tmp/jenkins_backup_$timestamp.tar.gz -C /var/jenkins_home .
docker cp jenkins-master:/tmp/jenkins_backup_$timestamp.tar.gz ./backups/
```

### Restoring from Backup

```bash
# Stop Jenkins
make destroy

# Restore data
docker run --rm -v jenkins_home:/data -v $(pwd)/backups:/backup alpine \
  tar xzf /backup/jenkins-backup-YYYYMMDD.tar.gz -C /data

# Restart Jenkins
make local  # or make remote
```

## 🚀 Advanced Usage

### Custom Ansible Playbooks

Create additional playbooks for specific tasks:

```yaml
# deploy-monitoring.yml
- name: Deploy monitoring stack
  hosts: "{{ deployment_mode == 'local' and 'localhost' or 'docker_hosts' }}"
  roles:
    - prometheus
    - grafana
```

### Pipeline Libraries

Set up shared pipeline libraries in JCasC:
```yaml
unclassified:
  globalLibraries:
    libraries:
      - name: "shared-pipeline-library"
        defaultVersion: "main"
        retriever:
          modernSCM:
            scm:
              git:
                remote: "https://github.com/your-org/jenkins-shared-library.git"
```

### Multi-Environment Deployments

```bash
# Development environment
DEPLOYMENT_MODE=local make deploy

# Staging environment  
DOCKER_HOST_IP=staging.company.com DEPLOYMENT_MODE=remote make deploy

# Production environment
DOCKER_HOST_IP=prod.company.com DEPLOYMENT_MODE=remote make deploy
```

## 🤝 Contributing

1. **Development Setup**:
   ```bash
   git clone <repository>
   code .  # Opens in dev container
   # Jenkins automatically deploys locally
   # Wait for post-create script to complete
   ```

2. **Making Changes**:
   ```bash
   # Edit Ansible roles or templates
   make rebuild          # Test changes locally
   make validate         # Validate Ansible syntax
   ```

3. **Testing**:
   ```bash
   make test-local       # Dry-run local deployment
   make test-remote      # Dry-run remote deployment (requires DOCKER_HOST_IP)
   ```

4. **Collection Updates**:
   ```bash
   # Update Ansible collections
   ansible-galaxy collection install -r ansible/requirements.yml --force
   ```

## 🔧 Technical Notes

### Docker Compose v2 Migration
This project uses Docker Compose v2 (`community.docker.docker_compose_v2` module) instead of the deprecated v1. Key differences:

- **Module**: `community.docker.docker_compose_v2` (not `docker_compose`)
- **Build parameter**: `build: always` (not `build: yes`)
- **Wait functionality**: Built-in `wait: true` and `wait_timeout: 300`
- **Namespace**: All Docker modules use `community.docker.*` prefix

### Ansible Collections
- **community.docker**: v3.4.0+ required for Docker Compose v2 support
- **Automatic installation**: Collections installed via `requirements.yml`
- **Version pinning**: `>=3.4.0,<4.0.0` avoids breaking changes in v4.0.0

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Jenkins team for the excellent containerized images
- Ansible community for infrastructure automation tools
- Docker team for containerization platform
- VS Code team for dev container support

---

**Quick Commands Reference:**

```bash
make init           # Initialize everything (dev container auto-runs this)
make local          # Deploy locally  
make remote         # Deploy remotely (requires DOCKER_HOST_IP)
make status         # Check status
make logs           # View logs
make rebuild        # Force rebuild
make destroy        # Clean up
make validate       # Check Ansible syntax
make help           # Show all commands

# Manual Ansible commands
cd ansible
ansible-playbook site.yml -e deployment_mode=local    # Local deployment
ansible-playbook site.yml -e deployment_mode=remote   # Remote deployment
ansible-galaxy collection install -r requirements.yml # Install collections
```

## 🏷️ Version Information

- **Ansible**: 5.0+ (uses community.docker 3.4+)
- **Docker**: 20.10+ with Compose v2
- **Jenkins**: 2.401.3-LTS
- **Python**: 3.8+ (for Ansible execution)
- **Ubuntu**: 22.04 (dev container base)