#!/bin/bash

# Unified Jenkins Infrastructure Deployment Script
# Deploys Jenkins via Ansible to both local dev containers and remote VMs

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

# Default values
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-local}"
VERBOSE=""
DRY_RUN=""
TAGS=""
FORCE_REBUILD=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Unified Jenkins Infrastructure Deployment Script

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    deploy          Deploy Jenkins infrastructure (default)
    destroy         Remove all deployed services
    status          Show status of deployed services
    logs            Show logs from services
    validate        Validate configuration without deploying
    rebuild         Force rebuild Docker images and redeploy

OPTIONS:
    -m, --mode MODE     Deployment mode: local or remote (default: local)
    -v, --verbose       Enable verbose Ansible output
    -n, --dry-run       Show what would be done without executing
    -t, --tags TAGS     Run only tasks with specific tags
    -f, --force         Force rebuild Docker images
    -h, --help          Show this help message

ENVIRONMENT VARIABLES:
    DEPLOYMENT_MODE     Set deployment mode (local/remote)
    DOCKER_HOST_IP      IP address of remote Docker host (for remote mode)
    ANSIBLE_USER        SSH user for remote connections (default: ubuntu)
    SSH_KEY_PATH        Path to SSH private key (default: ~/.ssh/id_rsa)
    JENKINS_ADMIN_USER  Jenkins admin username (default: admin)
    JENKINS_ADMIN_PASSWORD  Jenkins admin password (default: admin123)

EXAMPLES:
    # Deploy locally in dev container
    $0 --mode local

    # Deploy to remote VM
    DOCKER_HOST_IP=192.168.1.100 $0 --mode remote

    # Force rebuild and redeploy locally
    $0 rebuild --mode local

    # Validate remote configuration
    $0 validate --mode remote --dry-run

    # Show logs from local deployment
    $0 logs --mode local

    # Destroy remote deployment
    $0 destroy --mode remote
EOF
}

validate_prerequisites() {
    log_info "Validating prerequisites for $DEPLOYMENT_MODE deployment..."
    
    # Check if we're in a dev container or have required tools
    if [ ! -f "/.dockerenv" ] && ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible is not installed. Please run this script in a dev container or install Ansible."
        exit 1
    fi
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        if [ -z "$DOCKER_HOST_IP" ]; then
            log_error "DOCKER_HOST_IP environment variable is required for remote deployment"
            exit 1
        fi
        
        # Test SSH connectivity
        log_info "Testing SSH connectivity to $DOCKER_HOST_IP..."
        if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${ANSIBLE_USER:-ubuntu}@$DOCKER_HOST_IP" "echo 'SSH connection successful'" &>/dev/null; then
            log_warning "SSH connection to $DOCKER_HOST_IP failed. Please check connectivity and SSH keys."
        fi
    fi
    
    # Check if Docker is available for local deployment
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        if ! docker info &>/dev/null; then
            log_error "Docker is not running or accessible. Please start Docker or check your dev container setup."
            exit 1
        fi
    fi
    
    log_success "Prerequisites validated"
}

run_ansible_playbook() {
    local playbook="$1"
    local extra_vars="$2"
    
    cd "$ANSIBLE_DIR"
    
    local ansible_cmd="ansible-playbook"
    ansible_cmd="$ansible_cmd $playbook"
    ansible_cmd="$ansible_cmd -e deployment_mode=$DEPLOYMENT_MODE"
    
    if [ -n "$extra_vars" ]; then
        ansible_cmd="$ansible_cmd -e $extra_vars"
    fi
    
    if [ -n "$VERBOSE" ]; then
        ansible_cmd="$ansible_cmd -vvv"
    fi
    
    if [ -n "$DRY_RUN" ]; then
        ansible_cmd="$ansible_cmd --check --diff"
    fi
    
    if [ -n "$TAGS" ]; then
        ansible_cmd="$ansible_cmd --tags $TAGS"
    fi
    
    if [ -n "$FORCE_REBUILD" ]; then
        ansible_cmd="$ansible_cmd -e jenkins_force_rebuild=true"
    fi
    
    log_info "Running: $ansible_cmd"
    
    if [ -n "$DRY_RUN" ]; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi
    
    eval "$ansible_cmd"
}

deploy_infrastructure() {
    log_info "🚀 Deploying Jenkins infrastructure in $DEPLOYMENT_MODE mode..."
    
    validate_prerequisites
    
    # Set environment variables for Ansible
    export DEPLOYMENT_MODE
    export DOCKER_HOST_IP
    export ANSIBLE_USER
    export SSH_KEY_PATH
    export JENKINS_ADMIN_USER
    export JENKINS_ADMIN_PASSWORD
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_STDOUT_CALLBACK=yaml
    
    run_ansible_playbook "site.yml"
    
    if [ $? -eq 0 ]; then
        log_success "🎉 Jenkins deployment completed successfully!"
        show_access_information
    else
        log_error "❌ Deployment failed!"
        exit 1
    fi
}

destroy_infrastructure() {
    log_warning "🗑️  Destroying Jenkins infrastructure in $DEPLOYMENT_MODE mode..."
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        log_info "Stopping and removing local containers..."
        
        # Navigate to deployment directory
        local deploy_dir="/workspace/jenkins-deploy"
        if [ -d "$deploy_dir" ] && [ -f "$deploy_dir/docker-compose.jenkins.yml" ]; then
            cd "$deploy_dir"
            docker-compose -f docker-compose.jenkins.yml down -v 2>/dev/null || true
            log_info "Cleaning up Docker resources..."
            docker network rm jenkins-network 2>/dev/null || true
            docker volume prune -f 2>/dev/null || true
        else
            log_warning "Local deployment directory not found"
        fi
    else
        log_info "Destroying remote infrastructure..."
        export DEPLOYMENT_MODE
        export DOCKER_HOST_IP
        export ANSIBLE_USER
        export SSH_KEY_PATH
        
        # Create a simple destroy playbook task
        run_ansible_playbook "site.yml" "jenkins_destroy=true"
    fi
    
    log_success "✅ Infrastructure destroyed"
}

show_status() {
    log_info "📊 Checking status of Jenkins infrastructure..."
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        local deploy_dir="/workspace/jenkins-deploy"
        if [ -d "$deploy_dir" ] && [ -f "$deploy_dir/docker-compose.jenkins.yml" ]; then
            cd "$deploy_dir"
            log_info "Local deployment status:"
            if docker-compose -f docker-compose.jenkins.yml ps | grep -q "jenkins"; then
                docker-compose -f docker-compose.jenkins.yml ps
                echo ""
                log_info "Jenkins URL: http://localhost:8080"
            else
                log_warning "No local Jenkins deployment found"
            fi
        else
            log_warning "No local deployment directory found"
        fi
    else
        log_info "Checking remote deployment status..."
        if [ -n "$DOCKER_HOST_IP" ]; then
            ssh "${ANSIBLE_USER:-ubuntu}@$DOCKER_HOST_IP" "
                if [ -f /opt/jenkins/docker-compose.jenkins.yml ]; then
                    cd /opt/jenkins
                    docker-compose -f docker-compose.jenkins.yml ps
                    echo 'Jenkins URL: http://$DOCKER_HOST_IP:8080'
                else
                    echo 'No remote deployment found'
                fi
            " 2>/dev/null || log_warning "Could not connect to remote host"
        else
            log_error "DOCKER_HOST_IP not set for remote status check"
        fi
    fi
}

show_logs() {
    local service="${1:-jenkins-master}"
    
    log_info "📋 Showing logs for $service..."
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        local deploy_dir="/workspace/jenkins-deploy"
        if [ -d "$deploy_dir" ] && [ -f "$deploy_dir/docker-compose.jenkins.yml" ]; then
            cd "$deploy_dir"
            if docker-compose -f docker-compose.jenkins.yml ps | grep -q "$service"; then
                docker-compose -f docker-compose.jenkins.yml logs -f "$service"
            else
                log_error "Service $service not found locally"
            fi
        else
            log_error "Local deployment not found"
        fi
    else
        log_info "Fetching logs from remote deployment..."
        if [ -n "$DOCKER_HOST_IP" ]; then
            ssh "${ANSIBLE_USER:-ubuntu}@$DOCKER_HOST_IP" "
                cd /opt/jenkins 2>/dev/null && docker-compose -f docker-compose.jenkins.yml logs -f $service
            " 2>/dev/null || log_error "Could not fetch logs from remote host"
        else
            log_error "DOCKER_HOST_IP not set for remote logs"
        fi
    fi
}

validate_configuration() {
    log_info "🔍 Validating Ansible configuration..."
    
    cd "$ANSIBLE_DIR"
    
    # Check syntax
    if ansible-playbook site.yml --syntax-check; then
        log_success "✅ Playbook syntax is valid"
    else
        log_error "❌ Playbook syntax validation failed"
        exit 1
    fi
    
    # Check inventory
    if ansible-inventory --list > /dev/null; then
        log_success "✅ Inventory configuration is valid"
    else
        log_error "❌ Inventory configuration is invalid"
        exit 1
    fi
    
    # Dry run deployment
    log_info "Running deployment dry-run..."
    DRY_RUN="--check --diff"
    run_ansible_playbook "site.yml"
}

rebuild_infrastructure() {
    log_info "🔄 Rebuilding Jenkins infrastructure in $DEPLOYMENT_MODE mode..."
    FORCE_REBUILD="true"
    deploy_infrastructure
}

show_access_information() {
    log_info "🌐 Access Information:"
    echo ""
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        echo "Jenkins UI:       http://localhost:8080"
        echo "Health Check:     curl http://localhost:8080/login"
    else
        echo "Jenkins UI:       http://$DOCKER_HOST_IP:8080"
        echo "Health Check:     curl http://$DOCKER_HOST_IP:8080/login"
        echo "SSH Access:       ssh ${ANSIBLE_USER:-ubuntu}@$DOCKER_HOST_IP"
    fi
    
    echo ""
    echo "Default Credentials:"
    echo "Username: ${JENKINS_ADMIN_USER:-admin}"
    echo "Password: ${JENKINS_ADMIN_PASSWORD:-admin123}"
    echo ""
    echo "Available Agent Labels:"
    echo "• dind docker-manager static privileged    - Static DIND agent"
    echo "• maven java dynamic                       - Dynamic Maven agents"
    echo "• python py dynamic                        - Dynamic Python agents"
    echo ""
    echo "📋 Useful Commands:"
    echo "  View logs:         $0 logs --mode $DEPLOYMENT_MODE"
    echo "  Check status:      $0 status --mode $DEPLOYMENT_MODE"
    echo "  Rebuild:           $0 rebuild --mode $DEPLOYMENT_MODE"
    echo "  Destroy:           $0 destroy --mode $DEPLOYMENT_MODE"
}

# Parse command line arguments
COMMAND="deploy"
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            DEPLOYMENT_MODE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="-vvv"
            shift
            ;;
        -n|--dry-run)
            DRY_RUN="--check --diff"
            shift
            ;;
        -t|--tags)
            TAGS="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_REBUILD="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        deploy|destroy|status|logs|validate|rebuild)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate deployment mode
if [[ "$DEPLOYMENT_MODE" != "local" && "$DEPLOYMENT_MODE" != "remote" ]]; then
    log_error "Invalid deployment mode: $DEPLOYMENT_MODE. Must be 'local' or 'remote'"
    exit 1
fi

# Export environment variables for Ansible
export DEPLOYMENT_MODE
export DOCKER_HOST_IP
export ANSIBLE_USER
export SSH_KEY_PATH
export JENKINS_ADMIN_USER
export JENKINS_ADMIN_PASSWORD

# Execute the requested command
log_info "🎯 Executing command: $COMMAND (mode: $DEPLOYMENT_MODE)"

case $COMMAND in
    deploy)
        deploy_infrastructure
        ;;
    destroy)
        destroy_infrastructure
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "${2:-jenkins-master}"
        ;;
    validate)
        validate_configuration
        ;;
    rebuild)
        rebuild_infrastructure
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac#!/bin/bash

# Jenkins Infrastructure Deployment Script
# Supports both local development and remote VM deployment

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

# Default values
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-local}"
VERBOSE=""
DRY_RUN=""
TAGS=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Jenkins Infrastructure Deployment Script

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    deploy          Deploy the Jenkins infrastructure (default)
    destroy         Remove all deployed services
    status          Show status of deployed services
    logs            Show logs from services
    validate        Validate configuration without deploying

OPTIONS:
    -m, --mode MODE     Deployment mode: local or remote (default: local)
    -v, --verbose       Enable verbose output
    -n, --dry-run       Show what would be done without executing
    -t, --tags TAGS     Run only tasks with specific tags
    -h, --help          Show this help message

ENVIRONMENT VARIABLES:
    DEPLOYMENT_MODE     Set deployment mode (local/remote)
    DOCKER_HOST_IP      IP address of remote Docker host (for remote mode)
    ANSIBLE_USER        SSH user for remote connections (default: ubuntu)
    SSH_KEY_PATH        Path to SSH private key (default: ~/.ssh/id_rsa)
    JENKINS_ADMIN_PASSWORD  Jenkins admin password (default: admin123)

EXAMPLES:
    # Deploy locally for development
    $0 --mode local

    # Deploy to remote VM
    DOCKER_HOST_IP=192.168.1.100 $0 --mode remote

    # Validate configuration
    $0 validate --mode remote --dry-run

    # Show logs from local deployment
    $0 logs --mode local

    # Destroy remote deployment
    $0 destroy --mode remote
EOF
}

validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check if we're in a dev container or have required tools
    if [ ! -f "/.dockerenv" ] && ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible is not installed. Please run this script in a dev container or install Ansible."
        exit 1
    fi
    
    if [ "$DEPLOYMENT_MODE" = "remote" ]; then
        if [ -z "$DOCKER_HOST_IP" ]; then
            log_error "DOCKER_HOST_IP environment variable is required for remote deployment"
            exit 1
        fi
        
        # Test SSH connectivity
        log_info "Testing SSH connectivity to $DOCKER_HOST_IP..."
        if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${ANSIBLE_USER:-ubuntu}@$DOCKER_HOST_IP" "echo 'SSH connection successful'" &>/dev/null; then
            log_warning "SSH connection to $DOCKER_HOST_IP failed. Please check connectivity and SSH keys."
        fi
    fi
    
    # Check if Docker is available for local deployment
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        if ! docker info &>/dev/null; then
            log_error "Docker is not running or accessible. Please start Docker or check your dev container setup."
            exit 1
        fi
    fi
    
    log_success "Prerequisites validated"
}

run_ansible_playbook() {
    local playbook="$1"
    local extra_vars="$2"
    
    cd "$ANSIBLE_DIR"
    
    local ansible_cmd="ansible-playbook"
    ansible_cmd="$ansible_cmd $playbook"
    ansible_cmd="$ansible_cmd -e deployment_mode=$DEPLOYMENT_MODE"
    
    if [ -n "$extra_vars" ]; then
        ansible_cmd="$ansible_cmd -e $extra_vars"
    fi
    
    if [ -n "$VERBOSE" ]; then
        ansible_cmd="$ansible_cmd -vvv"
    fi
    
    if [ -n "$DRY_RUN" ]; then
        ansible_cmd="$ansible_cmd --check --diff"
    fi
    
    if [ -n "$TAGS" ]; then
        ansible_cmd="$ansible_cmd --tags $TAGS"
    fi
    
    log_info "Running: $ansible_cmd"
    
    if [ -n "$DRY_RUN" ]; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi
    
    eval "$ansible_cmd"
}

deploy_infrastructure() {
    log_info "Deploying Jenkins infrastructure in $DEPLOYMENT_MODE mode..."
    
    validate_prerequisites
    
    # Set environment variables for Ansible
    export DEPLOYMENT_MODE
    export ANSIBLE_HOST_KEY_CHECKING=False
    export ANSIBLE_STDOUT_CALLBACK=yaml
    
    run_ansible_playbook "site.yml"
    
    if [ $? -eq 0 ]; then
        log_success "Deployment completed successfully!"
        show_access_information
    else
        log_error "Deployment failed!"
        exit 1
    fi
}

destroy_infrastructure() {
    log_warning "Destroying Jenkins infrastructure in $DEPLOYMENT_MODE mode..."
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        log_info "Stopping and removing local containers..."
        docker compose -f "$ANSIBLE_DIR/docker-compose.yml" down -v 2>/dev/null || true
        docker network rm jenkins-network 2>/dev/null || true
        docker volume prune -f 2>/dev/null || true
    else
        log_info "Destroying remote infrastructure..."
        run_ansible_playbook "destroy.yml"
    fi
    
    log_success "Infrastructure destroyed"
}

show_status() {
    log_info "Checking status of Jenkins infrastructure..."
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        if docker network ls | grep -q jenkins-network; then
            log_info "Local deployment status:"
            docker ps --filter "network=jenkins-network" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            log_warning "No local deployment found"
        fi
    else
        log_info "Checking remote deployment status..."
        run_ansible_playbook "status.yml" || log_warning "Status check failed"
    fi
}

show_logs() {
    local service="${1:-jenkins-master}"
    
    log_info "Showing logs for $service..."
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        if docker ps --format "{{.Names}}" | grep -q "$service"; then
            docker logs -f "$service"
        else
            log_error "Service $service not found locally"
        fi
    else
        log_info "Fetching logs from remote deployment..."
        # SSH into remote host and show docker logs
        ssh "${ANSIBLE_USER:-ubuntu}@$DOCKER_HOST_IP" "docker logs -f $service" 2>/dev/null || \
            log_error "Could not fetch logs from remote host"
    fi
}

validate_configuration() {
    log_info "Validating Ansible configuration..."
    
    cd "$ANSIBLE_DIR"
    
    # Check syntax
    if ansible-playbook site.yml --syntax-check; then
        log_success "Playbook syntax is valid"
    else
        log_error "Playbook syntax validation failed"
        exit 1
    fi
    
    # Check inventory
    if ansible-inventory --list > /dev/null; then
        log_success "Inventory configuration is valid"
    else
        log_error "Inventory configuration is invalid"
        exit 1
    fi
    
    # Dry run deployment
    log_info "Running deployment dry-run..."
    DRY_RUN="--check --diff"
    run_ansible_playbook "site.yml"
}

show_access_information() {
    log_info "Access Information:"
    echo ""
    
    if [ "$DEPLOYMENT_MODE" = "local" ]; then
        echo "🌐 Jenkins UI:       http://localhost:8080"
        echo "📊 HAProxy Stats:    http://localhost:8404/stats"
        echo "🔍 Health Check:     curl http://localhost:8080/login"
    else
        echo "🌐 Jenkins UI:       http://$DOCKER_HOST_IP:8080"
        echo "📊 HAProxy Stats:    http://$DOCKER_HOST_IP:8404/stats"
        echo "🔍 Health Check:     curl http://$DOCKER_HOST_IP:8080/login"
        echo "🔐 SSH Access:       ssh ${ANSIBLE_USER:-ubuntu}@$DOCKER_HOST_IP"
    fi
    
    echo ""
    echo "Default Credentials:"
    echo "Username: ${JENKINS_ADMIN_USER:-admin}"
    echo "Password: ${JENKINS_ADMIN_PASSWORD:-admin123}"
    echo ""
    echo "📋 Useful Commands:"
    echo "  View logs:         $0 logs --mode $DEPLOYMENT_MODE"
    echo "  Check status:      $0 status --mode $DEPLOYMENT_MODE"
    echo "  Destroy:           $0 destroy --mode $DEPLOYMENT_MODE"
}

# Parse command line arguments
COMMAND="deploy"
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            DEPLOYMENT_MODE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="-vvv"
            shift
            ;;
        -n|--dry-run)
            DRY_RUN="--check --diff"
            shift
            ;;
        -t|--tags)
            TAGS="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        deploy|destroy|status|logs|validate)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate deployment mode
if [[ "$DEPLOYMENT_MODE" != "local" && "$DEPLOYMENT_MODE" != "remote" ]]; then
    log_error "Invalid deployment mode: $DEPLOYMENT_MODE. Must be 'local' or 'remote'"
    exit 1
fi

# Export environment variables for Ansible
export DEPLOYMENT_MODE
export DOCKER_HOST_IP
export ANSIBLE_USER
export SSH_KEY_PATH
export JENKINS_ADMIN_PASSWORD

# Execute the requested command
log_info "Executing command: $COMMAND (mode: $DEPLOYMENT_MODE)"

case $COMMAND in
    deploy)
        deploy_infrastructure
        ;;
    destroy)
        destroy_infrastructure
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "${2:-jenkins-master}"
        ;;
    validate)
        validate_configuration
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac