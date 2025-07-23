# Unified Jenkins Infrastructure with Ansible

A production-ready, enterprise-grade Jenkins infrastructure deployment system using Ansible and Docker. Supports both local development in dev containers and remote VM deployments with the same unified codebase.

## 🏗️ Architecture Overview

This project provides a complete CI/CD infrastructure solution featuring:

- **Ansible-driven IaC**: Infrastructure as Code with version-controlled configurations
- **Docker-based containers**: Consistent environments across all deployments
- **Unified deployment**: Same codebase works for local development and remote production
- **JCasC configuration**: Jenkins configured entirely through code
- **Mixed agent strategy**: Static DIND agent + dynamic Python/Maven agents
- **HAProxy load balancing**: SSL termination and high availability
- **Cross-platform support**: Windows WSL, macOS, Linux local + RHEL remote

### Components

- **Jenkins Master**: Web UI and job orchestration with JCasC
- **Static DIND Agent**: Always-available Docker-in-Docker agent for privileged operations
- **Dynamic Agents**: On-demand Maven and Python build agents with auto-scaling
- **HAProxy Load Balancer**: SSL termination, stats monitoring, health checks
- **Ansible Automation**: Complete infrastructure deployment and management

## 🚀 Quick Start

### Prerequisites

- **Docker**: Required for container management
- **VS Code with Dev Containers extension**: For local development
- **SSH access to target VM**: For remote deployment (with sudo privileges)
- **Python 3.8+**: For Ansible execution

### 1. Dev Container Setup (Recommended)

When you open this project in VS Code with Dev Containers, everything is automatically configured:

```bash
# Automatically runs when dev container starts:
# 1. Sets up Ansible environment with required collections
# 2. Installs Docker collections (community.docker v3.4+)
# 3. Configures development environment
# 4. Ready to deploy Jenkins locally
```

### 2. Quick Local Deployment

```bash
# Using Make (recommended)
make local                    # Deploy locally
make status                   # Check deployment status
make logs                     # View Jenkins logs

# Using deployment script directly
scripts/deploy.sh --mode local deploy

# Using Ansible directly
cd ansible
ansible-playbook site.yml -e deployment_mode=local
```

**Access your local Jenkins:**
- URL: http://localhost:8080
- Username: `admin`
- Password: `admin123`

### 3. Remote VM Deployment

```bash
# Set target VM configuration
export DOCKER_HOST_IP=192.168.1.100
export ANSIBLE_USER=ubuntu
export SSH_KEY_PATH=~/.ssh/id_rsa

# Deploy to remote VM
make remote

# Or using deployment script
DOCKER_HOST_IP=192.168.1.100 scripts/deploy.sh --mode remote deploy
```

## 🎯 Usage Examples

### Local Development Workflow

```bash
# Complete setup in dev container
make init                     # Initialize everything

# Development cycle
make rebuild                  # Rebuild with changes
make logs                     # View Jenkins logs
make status                   # Check service status
make backup                   # Create backup

# Manual Ansible commands
cd ansible
ansible-playbook site.yml -e deployment_mode=local
ansible-galaxy collection install -r requirements.yml
```

### Remote Production Deployment

```bash
# Production environment setup
source environments/prod-vm.env  # Load production config
make remote                      # Deploy to production

# Management commands
make logs-remote                 # View remote logs
make restart-remote             # Restart services
make shell-remote               # SSH to remote host
make backup                     # Create backups
```

### Pipeline Development

Create pipelines using the available agent labels:

```groovy
pipeline {
    agent none
    stages {
        stage('Build Matrix') {
            parallel {
                stage('Java Build') {
                    agent { label 'maven java dynamic' }
                    steps {
                        sh 'mvn clean package'
                        publishTestResults testResultsPattern: 'target/surefire-reports/*.xml'
                    }
                }
                stage('Python Build') {
                    agent { label 'python py dynamic' }
                    steps {
                        sh 'pip install -r requirements.txt && pytest'
                        publishTestResults testResultsPattern: 'test-results.xml'
                    }
                }
                stage('Docker Operations') {
                    agent { label 'dind docker-manager static privileged' }
                    steps {
                        sh 'docker build -t myapp:${BUILD_NUMBER} .'
                        sh 'docker push registry.company.com/myapp:${BUILD_NUMBER}'
                    }
                }
            }
        }
    }
}
```

## 🔧 Available Agent Types

### Static DIND Agent
- **Labels**: `dind docker-manager static privileged`
- **Purpose**: Docker operations, image building, privileged tasks
- **Always available**: Yes, persistent connection
- **Capabilities**: Full Docker access, container management, image building

### Dynamic Maven Agent
- **Labels**: `maven java dynamic`
- **Purpose**: Java/Maven builds, JUnit tests, Gradle builds
- **Auto-provisioned**: Created on-demand, destroyed when idle (10 min timeout)
- **Capabilities**: Multiple JDK versions (11, 17, 21), Maven 3.8/3.9, Gradle

### Dynamic Python Agent
- **Labels**: `python py dynamic`
- **Purpose**: Python builds, pytest, pip packages, virtual environments
- **Auto-provisioned**: Created on-demand, destroyed when idle (10 min timeout)
- **Capabilities**: Python 3.x, pip, pytest, common libraries, virtual environments

## 📁 Project Structure

```
jenkins-infrastructure/
├── .devcontainer/                  # VS Code dev container configuration
│   ├── devcontainer.json           # Container setup with UID 1001, Docker socket
│   ├── Dockerfile                  # Ubuntu 24.04 with Ansible + Docker
│   └── post-create.sh              # Auto-setup script
├── ansible/                        # Ansible infrastructure automation
│   ├── site.yml                    # Main deployment playbook
│   ├── build-images.yml            # Playbook to build Jenkins images
│   ├── ansible.cfg                 # Ansible configuration
│   ├── requirements.yml            # Ansible collections
│   ├── inventory/hosts.yml         # Environment definitions
│   └── roles/                      # Ansible roles
│       ├── jenkins/                # Jenkins infrastructure role
│       ├── jenkins_image_builder/  # Role to build Jenkins images
│       └── monitoring/             # Role to setup monitoring
├── jenkins/                        # Jenkins pipelines
│   └── pipelines/
│       ├── build-images.groovy     # Pipeline to build Jenkins images
│       └── backup.groovy           # Pipeline to backup Jenkins
├── environments/                   # Platform-specific configurations
│   ├── dev-local.env              # Development environment
│   ├── prod-vm.env                # Production RHEL server
│   └── remote.env                 # Remote deployment template
├── scripts/                       # Deployment and management scripts
│   └── deploy.sh                  # Cross-platform deployment script
├── examples/                      # Sample configurations
│   └── sample-pipeline.groovy     # Pipeline examples for all agents
├── Makefile                       # Convenient command shortcuts
├── README.md                      # This file
└── IMPLEMENTATION_GUIDE.md        # Complete implementation guide
```

## ⚙️ Configuration

### Environment Variables

```bash
# Deployment mode
DEPLOYMENT_MODE=local              # or 'remote'

# Remote deployment
DOCKER_HOST_IP=192.168.1.100      # Target VM IP
ANSIBLE_USER=ubuntu                # SSH user with sudo access
SSH_KEY_PATH=~/.ssh/id_rsa         # SSH private key path

# Jenkins configuration
JENKINS_ADMIN_USER=admin           # Admin username
JENKINS_ADMIN_PASSWORD=admin123    # Admin password (change in production!)
JENKINS_DOMAIN=jenkins.company.com # Corporate domain
BASE_DOMAIN=company.com            # Base corporate domain

# SSL configuration
JENKINS_SSL_ENABLED=true           # Enable SSL/HTTPS
JENKINS_SSL_CERT_PATH=/opt/certs   # Certificate directory

# HAProxy configuration
HAPROXY_STATS_PASSWORD=admin123    # Stats interface password
```

### Ansible Collections

The project automatically installs these collections via `ansible/requirements.yml`:

```yaml
collections:
  - community.docker: ">=3.4.0,<4.0.0"  # Docker Compose v2 support
  - community.general: ">=7.0.0"         # General utilities
  - ansible.posix: ">=1.5.0"            # POSIX utilities
```


### Customizing Jenkins

#### Adding New Dynamic Agents

Edit `ansible/roles/jenkins/defaults/main.yml`:

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

#### Memory and Performance Tuning

```yaml
# Local development settings
jenkins_master_memory: "2g"
jenkins_master_memory_min: "1g"

# Production settings
jenkins_master_memory: "4g"
jenkins_master_memory_min: "2g"
```

## 🔍 Monitoring and Troubleshooting

### Health Checks

```bash
# Overall status
make status

# View logs
make logs                      # Local logs
make logs-remote              # Remote logs

# Container status
docker ps                     # Local containers
make shell-remote             # SSH to remote + check containers
```

### Common Issues

#### 1. Jenkins Won't Start
```bash
# Check logs for errors
make logs

# Common causes:
# - Port 8080 already in use
# - Insufficient memory
# - Docker socket permissions
# - Docker Compose v2 not available
```

#### 2. Docker Compose Version Issues
```bash
# Verify Docker Compose v2
docker compose version
# Should show v2.x.x, not v1.x.x

# If v1, update Docker Desktop or install Compose v2
```

#### 3. Dynamic Agents Not Starting
```bash
# Check Jenkins cloud configuration:
# Manage Jenkins > Clouds > docker-cloud

# Verify Docker connectivity
docker network ls | grep jenkins
make logs | grep -i "docker"
```

#### 4. Remote Deployment Fails
```bash
# Test SSH connectivity
ssh -o ConnectTimeout=5 $ANSIBLE_USER@$DOCKER_HOST_IP "echo 'Connection test'"

# Verify Docker on remote
ssh $ANSIBLE_USER@$DOCKER_HOST_IP "docker --version && docker compose version"

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

# HAProxy logs
docker logs -f haproxy
```

## 🔒 Security Considerations

### Production Checklist

- [ ] Change default Jenkins admin password
- [ ] Configure proper authentication (LDAP, OAuth, SAML)
- [ ] Enable HTTPS with valid SSL certificates
- [ ] Restrict Docker socket access
- [ ] Configure firewall rules
- [ ] Set up regular backups
- [ ] Review agent permissions
- [ ] Enable audit logging
- [ ] Configure CSRF protection
- [ ] Set up monitoring and alerting

### SSL Configuration

```bash
# Development (self-signed)
export JENKINS_SSL_ENABLED=true
export JENKINS_GENERATE_SELF_SIGNED=true

# Production (corporate certificates)
export JENKINS_SSL_ENABLED=true
export JENKINS_GENERATE_SELF_SIGNED=false
export JENKINS_SSL_CERT_PATH=/opt/corporate-certs
```

## 💾 Backup and Recovery

### Creating Backups

```bash
# Automated backup
make backup

# Manual backup with timestamp
timestamp=$(date +%Y%m%d_%H%M%S)
docker exec jenkins-master tar czf /tmp/jenkins_backup_$timestamp.tar.gz -C /var/jenkins_home .
docker cp jenkins-master:/tmp/jenkins_backup_$timestamp.tar.gz ./backups/
```

### Restoring from Backup

```bash
# Stop Jenkins
make destroy

# Restore data volume
docker run --rm -v jenkins_home:/data -v $(pwd)/backups:/backup alpine \
  tar xzf /backup/jenkins-backup-YYYYMMDD.tar.gz -C /data

# Restart Jenkins
make local  # or make remote
```

## 🚀 Advanced Usage

### Multi-Environment Deployments

```bash
# Development
source environments/dev-local.env && make local

# Staging
source environments/staging.env && make remote

# Production
source environments/prod-vm.env && make remote
```

### Custom Ansible Playbooks

```yaml
# monitoring.yml
- name: Deploy monitoring stack
  hosts: "{{ deployment_mode == 'local' and 'localhost' or 'docker_hosts' }}"
  roles:
    - prometheus
    - grafana
```

### Pipeline Libraries

Configure shared pipeline libraries in JCasC:

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

## 🛠️ Management Commands

### Make Commands

```bash
# Deployment
make init                      # Initialize dev environment
make local                     # Deploy locally
make remote                    # Deploy remotely (requires DOCKER_HOST_IP)
make rebuild                   # Force rebuild and redeploy

# Management
make status                    # Check deployment status
make logs                      # View local logs
make logs-remote              # View remote logs
make restart-local            # Restart local services
make restart-remote           # Restart remote services

# Maintenance
make backup                    # Create backup
make clean                     # Clean Docker resources
make destroy                   # Remove deployment
make validate                  # Validate configuration

# Development
make shell-local              # Shell into local Jenkins master
make shell-remote             # SSH to remote host
make test-local               # Test local deployment (dry-run)
make test-remote              # Test remote deployment (dry-run)
```

### Script Commands

```bash
# Direct script usage
scripts/deploy.sh --mode local deploy
scripts/deploy.sh --mode remote --verbose deploy
scripts/deploy.sh --mode local destroy
scripts/deploy.sh --mode remote status

# With environment variables
DOCKER_HOST_IP=192.168.1.100 scripts/deploy.sh --mode remote deploy
```

## 🤝 Contributing

1. **Development Setup**:
   ```bash
   git clone <repository>
   code .  # Opens in dev container
   # Environment automatically configured
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
   make test-remote      # Dry-run remote deployment
   ```

## 📝 Version Information

- **Ansible**: 5.0+ (community.docker 3.4+)
- **Docker**: 20.10+
- **Jenkins**: 2.401.3-LTS
- **Python**: 3.8+ (for Ansible execution)
- **Ubuntu**: 24.04 (dev container base)
- **HAProxy**: 2.8+

## 🔗 Quick Reference

```bash
# Access Jenkins (local)
open http://localhost:8080

# Access Jenkins (remote)
open http://$DOCKER_HOST_IP:8080

# HAProxy Stats (local)
open http://localhost:8404/stats

# HAProxy Stats (remote)
open http://$DOCKER_HOST_IP:8404/stats

# Default credentials
Username: admin
Password: admin123

# Available agent labels
dind docker-manager static privileged    # Static DIND agent
maven java dynamic                       # Dynamic Maven agents
python py dynamic                        # Dynamic Python agents
```

## 📚 Additional Resources

- [Jenkins Configuration as Code Documentation](https://jenkins.io/projects/jcasc/)
- [Ansible Docker Collection](https://docs.ansible.com/ansible/latest/collections/community/docker/)
- [HAProxy Configuration Reference](https://docs.haproxy.org/2.8/configuration.html)

---

## 💡 Suggestions for Improvement

* **Secret Management:** Currently, secrets are managed as Ansible variables. For a production environment, it is recommended to use a dedicated secret management solution like HashiCorp Vault or AWS Secrets Manager.
* **Logging:** The current logging setup is basic. For a production environment, it is recommended to use a dedicated logging stack like ELK (Elasticsearch, Logstash, and Kibana) or EFK (Elasticsearch, Fluentd, and Kibana) to aggregate and analyze logs from all the components of the infrastructure.
* **High Availability:** The current setup does not provide high availability for the Jenkins master. For a production environment, it is recommended to set up a multi-node Jenkins cluster with a load balancer to provide high availability.
* **Automated Backups:** The current backup solution is manual. For a production environment, it is recommended to automate the backup process and store the backups in a durable and secure location like an S3 bucket.

---

**Support**: For issues, questions, or contributions, please refer to the project's issue tracker and IMPLEMENTATION_GUIDE.md for detailed setup instructions.