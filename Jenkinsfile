pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 10, unit: 'MINUTES')
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Getting project source code from GitHub'
                checkout scm
            }
        }

        stage('Setup Python') {
            steps {
                sh 'python3 --version'
                sh 'python3 -m venv .venv'
                sh '.venv/bin/python -m pip install -r requirements.txt'
            }
        }

        stage('Build') {
            steps {
                echo 'Building Python application'
                sh '.venv/bin/python -m compileall -q app.py'
            }
        }

        stage('Test') {
            steps {
                echo 'Running unit tests'
                sh '.venv/bin/python -m unittest discover -s tests -v'
            }
        }

        stage('Package') {
            steps {
                echo 'Packaging application'
                sh 'mkdir -p dist'
                sh 'tar -czf "dist/jenkins-python-ci-${BUILD_NUMBER}.tar.gz" app.py tests requirements.txt README.md'

                archiveArtifacts artifacts: 'dist/*.tar.gz',
                                 fingerprint: true
            }
        }
    }
}
