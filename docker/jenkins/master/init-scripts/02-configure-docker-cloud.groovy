#!/usr/bin/env groovy

/**
 * Jenkins Docker Cloud Configuration
 * Sets up dynamic Docker-based slave provisioning
 */

import com.nirima.jenkins.plugins.docker.*
import com.nirima.jenkins.plugins.docker.launcher.*
import com.nirima.jenkins.plugins.docker.strategy.*
import io.jenkins.docker.connector.*
import jenkins.model.*
import hudson.model.*

def jenkins = Jenkins.getInstance()

println "=== Configuring Docker Cloud for Dynamic Slaves ==="

try {
    // Check if Docker cloud already exists
    def existingClouds = jenkins.clouds.findAll { it instanceof DockerCloud }
    if (!existingClouds.isEmpty()) {
        println "Docker cloud already configured, skipping..."
        return
    }

    // Docker API configuration
    def dockerApi = new DockerAPI(new DockerServerEndpoint("unix:///var/run/docker.sock", ""))
    
    // Create Docker templates for different types of builds
    def templates = []
    
    // Template 1: General purpose dynamic agent
    def generalTemplate = new DockerTemplate(
        "jenkins/inbound-agent:latest",                    // image
        "",                                                // dockerCommand  
        "",                                                // lxcConfString
        "",                                                // hostname
        "/home/jenkins/agent",                            // remoteFs
        1,                                                 // instanceCap
        "docker dynamic-general linux",                   // labelString
        "",                                                // credentialsId
        "NORMAL",                                         // mode
        "",                                                // retentionStrategy
        new DockerComputerAttachConnector(),              // connector
        [],                                                // buildHostOptions
        "",                                                // network
        [],                                                // dnsHosts
        [],                                                // volumesString
        [],                                                // environmentsString
        "",                                                // bindPorts
        0,                                                 // bindAllPorts
        true,                                              // privileged
        false,                                             // tty
        "",                                                // macAddress
        ""                                                 // extraHosts
    )
    
    // Configure general template properties
    generalTemplate.setInstanceCapStr("5")
    generalTemplate.setRemoteFs("/home/jenkins/agent")
    generalTemplate.setConnector(new DockerComputerAttachConnector("jenkins"))
    generalTemplate.setRetentionStrategy(new DockerOnceRetentionStrategy(5))
    generalTemplate.setPullStrategy(DockerImagePullStrategy.PULL_LATEST)
    generalTemplate.setRemoveVolumes(true)
    
    // Add Docker mounts for general template
    def generalMounts = [
        "/var/run/docker.sock:/var/run/docker.sock",
        "jenkins-workspace:/home/jenkins/agent"
    ]
    generalTemplate.setVolumesString(generalMounts.join("\n"))
    
    // Add environment variables
    def generalEnvs = [
        "DOCKER_HOST=unix:///var/run/docker.sock",
        "JENKINS_AGENT_WORKDIR=/home/jenkins/agent"
    ]
    generalTemplate.setEnvironmentsString(generalEnvs.join("\n"))
    
    templates.add(generalTemplate)
    
    // Template 2: Maven/Java dynamic agent
    def mavenTemplate = new DockerTemplate(
        "jenkins-maven-agent:latest",                      // Custom built image
        "",                                                // dockerCommand
        "",                                                // lxcConfString  
        "",                                                // hostname
        "/home/jenkins/agent",                            // remoteFs
        1,                                                 // instanceCap
        "maven java gradle dynamic jdk11 jdk17",         // labelString
        "",                                                // credentialsId
        "NORMAL",                                         // mode
        "",                                                // retentionStrategy
        new DockerComputerAttachConnector(),              // connector
        [],                                                // buildHostOptions
        "",                                                // network
        [],                                                // dnsHosts
        [],                                                // volumesString
        [],                                                // environmentsString
        "",                                                // bindPorts
        0,                                                 // bindAllPorts
        false,                                             // privileged
        false,                                             // tty
        "",                                                // macAddress
        ""                                                 // extraHosts
    )
    
    mavenTemplate.setInstanceCapStr("3")
    mavenTemplate.setConnector(new DockerComputerAttachConnector("jenkins"))
    mavenTemplate.setRetentionStrategy(new DockerOnceRetentionStrategy(10))
    mavenTemplate.setPullStrategy(DockerImagePullStrategy.PULL_LATEST)
    mavenTemplate.setRemoveVolumes(true)
    
    // Maven template mounts
    def mavenMounts = [
        "/var/run/docker.sock:/var/run/docker.sock",
        "maven-cache:/home/jenkins/.m2",
        "gradle-cache:/home/jenkins/.gradle",
        "jenkins-workspace:/home/jenkins/agent"
    ]
    mavenTemplate.setVolumesString(mavenMounts.join("\n"))
    
    // Maven environment variables
    def mavenEnvs = [
        "JAVA_HOME=/opt/java/openjdk-11",
        "MAVEN_HOME=/opt/maven/maven-3.9",
        "MAVEN_OPTS=-Xmx2g -Xms512m",
        "DOCKER_HOST=unix:///var/run/docker.sock"
    ]
    mavenTemplate.setEnvironmentsString(mavenEnvs.join("\n"))
    
    templates.add(mavenTemplate)
    
    // Template 3: Node.js dynamic agent
    def nodejsTemplate = new DockerTemplate(
        "jenkins-nodejs-agent:latest",                     // Custom built image
        "",                                                // dockerCommand
        "",                                                // lxcConfString
        "",                                                // hostname
        "/home/jenkins/agent",                            // remoteFs
        1,                                                 // instanceCap
        "nodejs npm yarn javascript frontend dynamic",    // labelString
        "",                                                // credentialsId
        "NORMAL",                                         // mode
        "",                                                // retentionStrategy
        new DockerComputerAttachConnector(),              // connector
        [],                                                // buildHostOptions
        "",                                                // network
        [],                                                // dnsHosts
        [],                                                // volumesString
        [],                                                // environmentsString
        "",                                                // bindPorts
        0,                                                 // bindAllPorts
        false,                                             // privileged
        false,                                             // tty
        "",                                                // macAddress
        ""                                                 // extraHosts
    )
    
    nodejsTemplate.setInstanceCapStr("3")
    nodejsTemplate.setConnector(new DockerComputerAttachConnector("jenkins"))
    nodejsTemplate.setRetentionStrategy(new DockerOnceRetentionStrategy(10))
    nodejsTemplate.setPullStrategy(DockerImagePullStrategy.PULL_LATEST)
    nodejsTemplate.setRemoveVolumes(true)
    
    // Node.js template mounts
    def nodejsMounts = [
        "/var/run/docker.sock:/var/run/docker.sock",
        "npm-cache:/home/jenkins/.npm",
        "yarn-cache:/home/jenkins/.yarn",
        "jenkins-workspace:/home/jenkins/agent"
    ]
    nodejsTemplate.setVolumesString(nodejsMounts.join("\n"))
    
    // Node.js environment variables
    def nodejsEnvs = [
        "NODE_VERSION=18.17.1",
        "NPM_CONFIG_CACHE=/home/jenkins/.npm",
        "YARN_CACHE_FOLDER=/home/jenkins/.yarn",
        "NODE_OPTIONS=--max-old-space-size=4096",
        "DOCKER_HOST=unix:///var/run/docker.sock"
    ]
    nodejsTemplate.setEnvironmentsString(nodejsEnvs.join("\n"))
    
    templates.add(nodejsTemplate)
    
    // Create the Docker cloud
    def dockerCloud = new DockerCloud(
        "docker-dynamic-cloud",                            // name
        templates,                                         // templates
        dockerApi,                                         // dockerApi
        10,                                                // containerCap
        10,                                                // connectTimeout
        10,                                                // readTimeout
        "",                                                // credentialsId
        "",                                                // version
        ""                                                 // dockerHostname
    )
    
    // Configure cloud properties
    dockerCloud.setContainerCapStr("10")
    dockerCloud.setConnectTimeout(10)
    dockerCloud.setReadTimeout(60)
    
    // Add the cloud to Jenkins
    jenkins.clouds.add(dockerCloud)
    
    println "Docker cloud configured successfully with ${templates.size()} templates"
    
    // List configured templates
    templates.each { template ->
        println "  - Template: ${template.getLabelString()}"
        println "    Image: ${template.getImage()}"
        println "    Instance Cap: ${template.getInstanceCapStr()}"
    }
    
} catch (Exception e) {
    println "Error configuring Docker cloud: ${e.getMessage()}"
    e.printStackTrace()
}

// Save configuration
jenkins.save()

println "=== Docker cloud configuration completed ==="