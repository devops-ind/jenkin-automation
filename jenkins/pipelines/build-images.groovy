pipeline {
    agent {
        label 'dind'
    }

    environment {
        HARBOR_CREDENTIALS = credentials('harbor-credentials')
        HARBOR_REGISTRY = "harbor.example.com"
    }

    stages {
        stage('Login to Harbor') {
            steps {
                sh "echo $HARBOR_CREDENTIALS_PSW | docker login $HARBOR_REGISTRY -u $HARBOR_CREDENTIALS_USR --password-stdin"
            }
        }

        stage('Build and Push Images') {
            steps {
                script {
                    sh "ansible-playbook ansible/build-images.yml"
                }
            }
        }

        stage('Logout from Harbor') {
            steps {
                sh "docker logout $HARBOR_REGISTRY"
            }
        }
    }
}
