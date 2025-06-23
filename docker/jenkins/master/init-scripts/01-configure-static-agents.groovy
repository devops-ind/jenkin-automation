#!/usr/bin/env groovy

/**
 * Jenkins Initialization Script
 * Configures static agents and prepares for dynamic slave provisioning
 */

import jenkins.model.*
import hudson.model.*
import hudson.slaves.*
import hudson.slaves.DumbSlave
import hudson.plugins.sshslaves.SSHLauncher
import hudson.tools.*
import jenkins.plugins.git.GitSCMSource
import org.jenkinsci.plugins.workflow.libs.*
import hudson.util.Secret

// Get Jenkins instance
def jenkins = Jenkins.getInstance()

println "=== Configuring Static Jenkins Agents ==="

// Configure static agents if they don't exist
def configureStaticAgent(String name, String description, String labels, int executors, String remoteFS) {
    // Check if agent already exists
    def existingAgent = jenkins.getNode(name)
    if (existingAgent != null) {
        println "Agent '${name}' already exists, skipping..."
        return
    }
    
    println "Creating agent: ${name}"
    
    // Create agent launcher (we'll use JNLP since agents connect to master)
    def launcher = new JNLPLauncher(true)
    
    // Create retention strategy (keep agent online)
    def retentionStrategy = new RetentionStrategy.Always()
    
    // Create node properties
    def nodeProperties = []
    
    // Add environment variables
    def envVars = [
        "AGENT_NAME": name,
        "AGENT_LABELS": labels,
        "DOCKER_HOST": "unix:///var/run/docker.sock"
    ]
    
    def envProperty = new EnvironmentVariablesNodeProperty(
        envVars.collect { key, value -> 
            new EnvironmentVariablesNodeProperty.Entry(key, value) 
        }
    )
    nodeProperties.add(envProperty)
    
    // Create the slave
    def slave = new DumbSlave(
        name,                    // name
        description,             // description  
        remoteFS,               // remote root directory
        executors.toString(),    // number of executors
        Node.Mode.NORMAL,       // mode
        labels,                 // labels
        launcher,               // launcher
        retentionStrategy,      // retention strategy
        nodeProperties          // node properties
    )
    
    // Add the agent to Jenkins
    jenkins.addNode(slave)
    
    println "Successfully created agent: ${name}"
}

// Configure static agents
try {
    // General purpose agent
    configureStaticAgent(
        "static-general-agent",
        "Static general purpose agent with Docker support",
        "docker general linux static",
        2,
        "/home/jenkins/agent"
    )
    
    // Maven/Java agent
    configureStaticAgent(
        "static-maven-agent", 
        "Static Maven/Java agent with multiple JDK versions",
        "maven java gradle jdk11 jdk17 jdk21 static",
        2,
        "/home/jenkins/agent"
    )
    
    // Node.js agent
    configureStaticAgent(
        "static-nodejs-agent",
        "Static Node.js agent with frontend tooling",
        "nodejs npm yarn javascript frontend testing static",
        2,
        "/home/jenkins/agent"
    )
    
    println "=== Static agents configuration completed ==="
    
} catch (Exception e) {
    println "Error configuring static agents: ${e.getMessage()}"
    e.printStackTrace()
}

// Configure global tools if not already configured
println "=== Configuring Global Tools ==="

try {
    def toolDescriptor = jenkins.getDescriptor("hudson.model.JDK")
    def installations = toolDescriptor.getInstallations()
    
    if (installations.length == 0) {
        println "Configuring JDK installations..."
        
        def jdkInstallations = [
            new JDK("OpenJDK-11", "/opt/java/openjdk-11"),
            new JDK("OpenJDK-17", "/opt/java/openjdk-17"), 
            new JDK("OpenJDK-21", "/opt/java/openjdk-21")
        ]
        
        toolDescriptor.setInstallations(jdkInstallations as JDK[])
        toolDescriptor.save()
        
        println "JDK installations configured"
    }
    
} catch (Exception e) {
    println "Error configuring tools: ${e.getMessage()}"
}

// Configure Maven installations
try {
    def mavenDescriptor = jenkins.getDescriptor("hudson.tasks.Maven")
    if (mavenDescriptor != null) {
        def mavenInstallations = mavenDescriptor.getInstallations()
        
        if (mavenInstallations.length == 0) {
            println "Configuring Maven installations..."
            
            def mavenInstalls = [
                new Maven.MavenInstallation("Maven-3.8", "/opt/maven/maven-3.8", []),
                new Maven.MavenInstallation("Maven-3.9", "/opt/maven/maven-3.9", [])
            ]
            
            mavenDescriptor.setInstallations(mavenInstalls as Maven.MavenInstallation[])
            mavenDescriptor.save()
            
            println "Maven installations configured"
        }
    }
} catch (Exception e) {
    println "Error configuring Maven: ${e.getMessage()}"
}

// Save Jenkins configuration
jenkins.save()

println "=== Jenkins agent and tool configuration completed ==="