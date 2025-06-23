# Custom Jenkins Master Image
# Based on official Jenkins LTS with pre-installed plugins and JCasC configuration

FROM jenkins/jenkins:2.401.3-lts

# Switch to root user to install additional packages
USER root

# Install additional system packages needed for your environment
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    vim \
    python3 \
    python3-pip \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Add Docker group and add jenkins user to it
RUN groupadd -g 999 docker || true
RUN usermod -aG docker jenkins

# Install Docker Compose
RUN curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose

# Copy corporate certificates if they exist
COPY certificates/*.crt /usr/local/share/ca-certificates/ 2>/dev/null || true
RUN update-ca-certificates

# Switch back to jenkins user
USER jenkins

# Set Jenkins environment variables
ENV JENKINS_OPTS="--httpPort=8080"
ENV JENKINS_SLAVE_AGENT_PORT=50000
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Xmx2g -Xms1g"

# Copy plugins list and install them
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Copy Jenkins Configuration as Code (JCasC) files
COPY jcasc/ /var/jenkins_home/casc_configs/

# Copy custom Groovy init scripts
COPY init-scripts/ /usr/share/jenkins/ref/init.groovy.d/

# Copy custom theme and branding (optional)
COPY theme/ /var/jenkins_home/userContent/

# Set the Jenkins Configuration as Code environment variable
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs

# Health check to ensure Jenkins is running properly
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/login || exit 1

# Expose Jenkins ports
EXPOSE 8080 50000

# Use the default Jenkins entrypoint
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/jenkins.sh"]