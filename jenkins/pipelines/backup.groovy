pipeline {
    agent any
    stages {
        stage('Backup Jenkins Home') {
            steps {
                script {
                    def backupDir = "/mnt/backups"
                    def backupFile = "jenkins-backup-${new Date().format('yyyy-MM-dd_HH-mm-ss')}.tar.gz"
                    sh "tar -czf ${backupDir}/${backupFile} -C /var/jenkins_home ."
                }
            }
        }
    }
}
