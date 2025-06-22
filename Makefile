# Unified Jenkins Infrastructure Management Makefile
# Ansible + Jenkins deployment for both local and remote environments

.DEFAULT_GOAL := help
.PHONY: help local remote destroy status logs validate clean setup rebuild

# Colors for pretty output
BLUE := \033[36m
GREEN := \033[32m
RED := \033[31m
YELLOW := \033[33m
RESET := \033[0m

# Configuration
SCRIPT_DIR := scripts
DEPLOY_SCRIPT := $(SCRIPT_DIR)/deploy.sh

help: ## Show this help message
	@echo "$(BLUE)Unified Jenkins Infrastructure Management$(RESET)"
	@echo ""
	@echo "$(GREEN)Deployment Commands:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-15s$(RESET) %s\n", $1, $2}'
	@echo ""
	@echo "$(GREEN)Examples:$(RESET)"
	@echo "  make local          # Deploy Jenkins locally in dev container"
	@echo "  make remote         # Deploy Jenkins to remote VM"
	@echo "  make logs           # View Jenkins logs"
	@echo "  make status         # Check deployment status"
	@echo "  make rebuild        # Force rebuild and redeploy"

setup: ## Set up development environment
	@echo "$(BLUE)Setting up Ansible + Jenkins development environment...$(RESET)"
	@if [ -f "ansible/requirements.yml" ]; then \
		ansible-galaxy install -r ansible/requirements.yml --force; \
	fi
	@chmod +x $(DEPLOY_SCRIPT)
	@echo "$(GREEN)✓ Development environment ready$(RESET)"

local: setup ## Deploy Jenkins infrastructure locally for development
	@echo "$(BLUE)Deploying Jenkins locally in dev container...$(RESET)"
	@DEPLOYMENT_MODE=local $(DEPLOY_SCRIPT) deploy

remote: setup ## Deploy Jenkins infrastructure to remote VM
	@echo "$(BLUE)Deploying Jenkins to remote VM...$(RESET)"
	@if [ -z "$DOCKER_HOST_IP" ]; then \
		echo "$(RED)Error: DOCKER_HOST_IP environment variable is required$(RESET)"; \
		echo "Example: DOCKER_HOST_IP=192.168.1.100 make remote"; \
		exit 1; \
	fi
	@DEPLOYMENT_MODE=remote $(DEPLOY_SCRIPT) deploy

destroy: ## Destroy the deployed infrastructure (prompts for confirmation)
	@echo "$(YELLOW)Warning: This will destroy the deployed Jenkins infrastructure$(RESET)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	if [[ $REPLY =~ ^[Yy]$ ]]; then \
		echo ""; \
		if docker ps --filter "name=jenkins" -q | grep -q .; then \
			echo "$(BLUE)Destroying local deployment...$(RESET)"; \
			DEPLOYMENT_MODE=local $(DEPLOY_SCRIPT) destroy; \
		fi; \
		if [ -n "$DOCKER_HOST_IP" ]; then \
			echo "$(BLUE)Destroying remote deployment...$(RESET)"; \
			DEPLOYMENT_MODE=remote $(DEPLOY_SCRIPT) destroy; \
		fi; \
	else \
		echo ""; \
		echo "$(GREEN)Operation cancelled$(RESET)"; \
	fi

status: ## Show status of deployed services
	@echo "$(BLUE)Checking deployment status...$(RESET)"
	@if docker ps --filter "name=jenkins" -q | grep -q .; then \
		echo "$(GREEN)Local deployment status:$(RESET)"; \
		DEPLOYMENT_MODE=local $(DEPLOY_SCRIPT) status; \
	fi
	@if [ -n "$DOCKER_HOST_IP" ]; then \
		echo "$(GREEN)Remote deployment status:$(RESET)"; \
		DEPLOYMENT_MODE=remote $(DEPLOY_SCRIPT) status; \
	fi

logs: ## Show logs from Jenkins services (local by default, use 'make logs-remote' for remote)
	@echo "$(BLUE)Showing local Jenkins logs...$(RESET)"
	@DEPLOYMENT_MODE=local $(DEPLOY_SCRIPT) logs jenkins-master

logs-remote: ## Show logs from remote Jenkins services
	@echo "$(BLUE)Showing remote Jenkins logs...$(RESET)"
	@if [ -z "$DOCKER_HOST_IP" ]; then \
		echo "$(RED)Error: DOCKER_HOST_IP environment variable is required$(RESET)"; \
		exit 1; \
	fi
	@DEPLOYMENT_MODE=remote $(DEPLOY_SCRIPT) logs jenkins-master

validate: ## Validate Ansible configuration without deploying
	@echo "$(BLUE)Validating Ansible configuration...$(RESET)"
	@$(DEPLOY_SCRIPT) validate --mode local

test-local: ## Test local deployment (dry-run)
	@echo "$(BLUE)Testing local deployment (dry-run)...$(RESET)"
	@DEPLOYMENT_MODE=local $(DEPLOY_SCRIPT) deploy --dry-run

test-remote: ## Test remote deployment (dry-run)
	@echo "$(BLUE)Testing remote deployment (dry-run)...$(RESET)"
	@if [ -z "$DOCKER_HOST_IP" ]; then \
		echo "$(RED)Error: DOCKER_HOST_IP environment variable is required$(RESET)"; \
		exit 1; \
	fi
	@DEPLOYMENT_MODE=remote $(DEPLOY_SCRIPT) deploy --dry-run

rebuild: ## Force rebuild Docker images and redeploy locally
	@echo "$(BLUE)Rebuilding Jenkins infrastructure...$(RESET)"
	@DEPLOYMENT_MODE=local $(DEPLOY_SCRIPT) rebuild

rebuild-remote: ## Force rebuild Docker images and redeploy remotely
	@echo "$(BLUE)Rebuilding Jenkins infrastructure on remote VM...$(RESET)"
	@if [ -z "$DOCKER_HOST_IP" ]; then \
		echo "$(RED)Error: DOCKER_HOST_IP environment variable is required$(RESET)"; \
		exit 1; \
	fi
	@DEPLOYMENT_MODE=remote $(DEPLOY_SCRIPT) rebuild

clean: ## Clean up Docker resources and temporary files
	@echo "$(BLUE)Cleaning up Docker resources...$(RESET)"
	@docker system prune -f --volumes 2>/dev/null || true
	@docker network prune -f 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup completed$(RESET)"

dev: local ## Alias for local deployment
	@echo "$(GREEN)✓ Development environment is ready$(RESET)"
	@echo "Access Jenkins at: http://localhost:8080"
	@echo "Username: admin | Password: admin123"

prod: remote ## Alias for remote deployment

restart-local: ## Restart local Jenkins services
	@echo "$(BLUE)Restarting local Jenkins services...$(RESET)"
	@if [ -d "/workspace/jenkins-deploy" ]; then \
		cd /workspace/jenkins-deploy && docker-compose -f docker-compose.jenkins.yml restart; \
	else \
		echo "$(RED)Local deployment not found$(RESET)"; \
	fi

restart-remote: ## Restart remote Jenkins services
	@echo "$(BLUE)Restarting remote Jenkins services...$(RESET)"
	@if [ -z "$DOCKER_HOST_IP" ]; then \
		echo "$(RED)Error: DOCKER_HOST_IP environment variable is required$(RESET)"; \
		exit 1; \
	fi
	@ssh ${ANSIBLE_USER:-ubuntu}@$DOCKER_HOST_IP \
		"cd /opt/jenkins && docker-compose -f docker-compose.jenkins.yml restart" 2>/dev/null || \
		echo "$(RED)Could not restart remote services$(RESET)"

backup: ## Create backup of Jenkins data
	@echo "$(BLUE)Creating Jenkins backup...$(RESET)"
	@timestamp=$(date +%Y%m%d_%H%M%S); \
	if docker ps --filter "name=jenkins-master" -q | grep -q .; then \
		echo "Backing up local Jenkins data..."; \
		mkdir -p ./backups; \
		docker exec jenkins-master tar czf /tmp/jenkins_backup_$timestamp.tar.gz -C /var/jenkins_home .; \
		docker cp jenkins-master:/tmp/jenkins_backup_$timestamp.tar.gz ./backups/; \
		echo "$(GREEN)✓ Local backup saved to ./backups/jenkins_backup_$timestamp.tar.gz$(RESET)"; \
	else \
		echo "$(YELLOW)No local Jenkins deployment found$(RESET)"; \
	fi

shell-local: ## Open shell in local Jenkins master container
	@if docker ps --filter "name=jenkins-master" -q | grep -q .; then \
		docker exec -it jenkins-master /bin/bash; \
	else \
		echo "$(RED)Local Jenkins master container not found$(RESET)"; \
	fi

shell-remote: ## Open SSH session to remote Docker host
	@if [ -z "$DOCKER_HOST_IP" ]; then \
		echo "$(RED)Error: DOCKER_HOST_IP environment variable is required$(RESET)"; \
		exit 1; \
	fi
	@ssh ${ANSIBLE_USER:-ubuntu}@$DOCKER_HOST_IP

# Development workflow targets
init: setup local ## Initialize development environment (setup + local deploy)

reset: destroy clean setup local ## Reset everything and redeploy locally

# Create necessary directories
$(shell mkdir -p backups logs)