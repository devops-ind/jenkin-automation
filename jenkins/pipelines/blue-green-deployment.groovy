pipeline {
    agent any

    parameters {
        string(name: 'IMAGE_TAG', defaultValue: 'latest', description: 'The image tag to deploy')
    }

    stages {
        stage('Deploy to Green') {
            steps {
                script {
                    sh "ansible-playbook ansible/site.yml -e 'jenkins_master_image_tag=${params.IMAGE_TAG} deployment_color=green'"
                }
            }
        }

        stage('Test Green') {
            steps {
                // Add tests here to verify the green environment
                sh "echo 'Testing green environment...'"
            }
        }

        stage('Switch to Green') {
            steps {
                script {
                    sh "ansible-playbook ansible/switch-to-green.yml"
                }
            }
        }

        stage('Tear Down Blue') {
            steps {
                script {
                    sh "ansible-playbook ansible/teardown-blue.yml"
                }
            }
        }
    }
}
