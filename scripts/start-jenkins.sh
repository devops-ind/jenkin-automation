#!/bin/bash

# Jenkins Startup Script with DIND Agent
# Builds and starts Jenkins with static DIND agent and dynamic Python/Maven agents

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_ROOT/docker"

echo -e "${BLUE}🚀 Starting Jenkins with DIND Agent and Dynamic Nodes${NC}"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Navigate to docker directory
cd "$DOCKER_DIR"

# Create necessary directories
echo -e "${BLUE}📁 Creating directories...${NC}"
mkdir -p certificates
mkdir -p backups
mkdir -p jenkins/master/jcasc
mkdir -p jenkins/agents

# Check if JCasC config exists
if [ ! -f "jenkins/master/jcasc/jenkins.yml" ]; then
    echo -e "${YELLOW}⚠️  JCasC configuration not found at jenkins/master/jcasc/jenkins.yml${NC}"
    echo -e "${YELLOW}   Please ensure the configuration file is in place.${NC}"
    exit 1
fi

# Check if plugins.txt exists
if [ ! -f "jenkins/master/plugins.txt" ]; then
    echo -e "${YELLOW}⚠️  Plugins configuration not found at jenkins/master/plugins.txt${NC}"
    echo -e "${YELLOW}   Please ensure the plugins file is in place.${NC}"
    exit 1
fi

# Check if DIND agent Dockerfile exists
if [ ! -f "jenkins/agents/Dockerfile.dind" ]; then
    echo -e "${YELLOW}⚠️  DIND agent Dockerfile not found at jenkins/agents/Dockerfile.dind${NC}"
    echo -e "${YELLOW}   Please ensure the DIND agent configuration is in place.${NC}"
    exit 1
fi

# Build and start services
echo -e "${BLUE}🔨 Building Jenkins images...${NC}"
docker-compose -f docker-compose.jenkins.yml build --no-cache

echo -e "${BLUE}🚀 Starting Jenkins infrastructure...${NC}"
docker-compose -f docker-compose.jenkins.yml up -d

# Wait for Jenkins to be ready
echo -e "${BLUE}⏳ Waiting for Jenkins to start...${NC}"
timeout=300
counter=0

while [ $counter -lt $timeout ]; do
    if curl -s http://localhost:8080/login >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Jenkins is ready!${NC}"
        break
    fi
    
    echo -n "."
    sleep 5
    counter=$((counter + 5))
done

if [ $counter -ge $timeout ]; then
    echo -e "${RED}❌ Jenkins failed to start within $timeout seconds${NC}"
    echo -e "${YELLOW}💡 Check logs with: docker-compose -f docker-compose.jenkins.yml logs jenkins-master${NC}"
    exit 1
fi

# Wait a bit more for the DIND agent to connect
echo -e "${BLUE}⏳ Waiting for DIND agent to connect...${NC}"
sleep 15

echo ""
echo -e "${GREEN}🎉 Jenkins Infrastructure is running!${NC}"
echo ""
echo -e "${BLUE}📋 Access Information:${NC}"
echo -e "   🌐 Jenkins UI:    http://localhost:8080"
echo -e "   👤 Username:      admin"
echo -e "   🔐 Password:      admin123"
echo ""
echo -e "${BLUE}🔧 Available Agents:${NC}"
echo -e "   • dind docker-manager static privileged    - Static DIND agent for Docker operations"
echo -e "   • maven java dynamic                       - Dynamic Maven/Java agents"
echo -e "   • python py dynamic                        - Dynamic Python agents"
echo ""
echo -e "${BLUE}💡 Useful Commands:${NC}"
echo -e "   • View all logs:      docker-compose -f docker-compose.jenkins.yml logs -f"
echo -e "   • View master logs:   docker-compose -f docker-compose.jenkins.yml logs -f jenkins-master"
echo -e "   • View agent logs:    docker-compose -f docker-compose.jenkins.yml logs -f jenkins-agent-dind"
echo -e "   • Stop Jenkins:       docker-compose -f docker-compose.jenkins.yml down"
echo -e "   • Restart:            docker-compose -f docker-compose.jenkins.yml restart"
echo -e "   • Check containers:   docker ps"
echo ""
echo -e "${YELLOW}📝 Notes:${NC}"
echo -e "   • Static DIND agent is always available for Docker operations"
echo -e "   • Dynamic agents will be created automatically when jobs run"
echo -e "   • Use 'dind' label for jobs that need privileged Docker access"
echo -e "   • Use 'maven' or 'python' labels for regular build jobs"   • Stop Jenkins:   docker-compose -f docker-compose.jenkins.yml down"
echo -e "   • Restart:        docker-compose -f docker-compose.jenkins.yml restart"
echo ""
echo -e "${YELLOW}📝 Note: Dynamic agents will be created automatically when jobs run!${NC}"