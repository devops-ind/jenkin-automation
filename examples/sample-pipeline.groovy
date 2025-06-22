// Sample Jenkins Pipeline demonstrating different agent types
// Shows usage of static DIND agent and dynamic Python/Maven agents

pipeline {
    agent none // Don't use any agent by default
    
    options {
        // Keep builds for 10 days
        buildDiscarder(logRotator(daysToKeepStr: '10'))
        // Timeout after 30 minutes
        timeout(time: 30, unit: 'MINUTES')
        // Disable concurrent builds
        disableConcurrentBuilds()
    }
    
    environment {
        // Global environment variables
        BUILD_TIMESTAMP = sh(script: 'date +%Y%m%d_%H%M%S', returnStdout: true).trim()
        DOCKER_REGISTRY = 'your-registry.com'
    }
    
    stages {
        stage('Build Matrix') {
            parallel {
                
                // Python build using dynamic agent
                stage('Python Build') {
                    agent {
                        label 'python py dynamic'
                    }
                    steps {
                        echo "🐍 Running Python build on dynamic agent"
                        
                        // Checkout code
                        checkout scm
                        
                        // Python build steps
                        sh '''
                            echo "Python version:"
                            python3 --version
                            
                            echo "Installing dependencies..."
                            pip3 install --user pytest requests flask
                            
                            echo "Running Python tests..."
                            python3 -c "
import sys
print(f'Python executable: {sys.executable}')
print(f'Python version: {sys.version}')
print('✅ Python environment is working!')
"
                            
                            echo "Creating Python package..."
                            mkdir -p dist
                            echo "print('Hello from Python build!')" > dist/hello.py
                        '''
                        
                        // Archive artifacts
                        archiveArtifacts artifacts: 'dist/**', fingerprint: true
                    }
                }
                
                // Maven build using dynamic agent
                stage('Maven Build') {
                    agent {
                        label 'maven java dynamic'
                    }
                    steps {
                        echo "☕ Running Maven build on dynamic agent"
                        
                        // Checkout code
                        checkout scm
                        
                        // Maven build steps
                        sh '''
                            echo "Java version:"
                            java -version
                            
                            echo "Maven version:"
                            mvn --version
                            
                            echo "Creating sample Maven project..."
                            mkdir -p src/main/java/com/example
                            mkdir -p src/test/java/com/example
                            
                            # Create a simple Java class
                            cat > src/main/java/com/example/App.java << 'EOF'
package com.example;

public class App {
    public static void main(String[] args) {
        System.out.println("Hello from Maven build!");
    }
    
    public String getMessage() {
        return "Hello World!";
    }
}
EOF

                            # Create a simple test
                            cat > src/test/java/com/example/AppTest.java << 'EOF'
package com.example;

import org.junit.Test;
import static org.junit.Assert.*;

public class AppTest {
    @Test
    public void testGetMessage() {
        App app = new App();
        assertEquals("Hello World!", app.getMessage());
    }
}
EOF

                            # Create pom.xml
                            cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>sample-app</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>jar</packaging>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.13.2</version>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
EOF
                            
                            echo "Running Maven build..."
                            mvn clean compile test package
                        '''
                        
                        // Archive artifacts
                        archiveArtifacts artifacts: 'target/**/*.jar', fingerprint: true
                        
                        // Publish test results
                        publishTestResults testResultsPattern: 'target/surefire-reports/*.xml'
                    }
                }
            }
        }
        
        // Docker operations using static DIND agent
        stage('Docker Operations') {
            agent {
                label 'dind docker-manager static privileged'
            }
            steps {
                echo "🐳 Running Docker operations on static DIND agent"
                
                script {
                    // Copy artifacts from previous stages
                    copyArtifacts projectName: env.JOB_NAME, 
                                  selector: specific(env.BUILD_NUMBER),
                                  filter: '**/*'
                    
                    // Docker operations
                    sh '''
                        echo "Docker version:"
                        docker --version
                        docker compose version
                        
                        echo "Current running containers:"
                        docker ps
                        
                        echo "Available Docker images:"
                        docker images
                        
                        echo "Creating sample Dockerfile..."
                        cat > Dockerfile << 'EOF'
FROM openjdk:11-jre-slim

WORKDIR /app

# Copy artifacts if they exist
COPY target/*.jar app.jar 2>/dev/null || echo "No JAR files found"
COPY dist/*.py . 2>/dev/null || echo "No Python files found"

# Default command
CMD ["echo", "Hello from Docker build!"]
EOF
                        
                        echo "Building Docker image..."
                        docker build -t sample-app:${BUILD_TIMESTAMP} .
                        
                        echo "Running container to test..."
                        docker run --rm sample-app:${BUILD_TIMESTAMP}
                        
                        echo "Cleaning up test image..."
                        docker rmi sample-app:${BUILD_TIMESTAMP}
                        
                        echo "✅ Docker operations completed successfully!"
                    '''
                }
            }
        }
        
        // Deployment simulation
        stage('Deploy') {
            agent {
                label 'dind docker-manager static'
            }
            when {
                branch 'main'
            }
            steps {
                echo "🚀 Simulating deployment..."
                
                sh '''
                    echo "Deployment would happen here..."
                    echo "Branch: ${BRANCH_NAME}"
                    echo "Build: ${BUILD_NUMBER}"
                    echo "Timestamp: ${BUILD_TIMESTAMP}"
                    
                    # Simulate deployment steps
                    echo "✅ Deployment simulation completed!"
                '''
            }
        }
    }
    
    post {
        always {
            echo "🏁 Pipeline completed"
            
            // Clean workspace on agents
            cleanWs()
        }
        
        success {
            echo "✅ Pipeline succeeded!"
        }
        
        failure {
            echo "❌ Pipeline failed!"
        }
        
        unstable {
            echo "⚠️ Pipeline unstable!"
        }
    }
}