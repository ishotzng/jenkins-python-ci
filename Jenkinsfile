pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'jenkins-python-ci'
    }

    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    /*
     * SCM polling is part of the pipeline definition, so the job triggers
     * automatically even if the GitHub webhook is not configured.
     *
     * If the GitHub plugin is installed and you prefer push-triggered builds,
     * configure the webhook in the GitHub repository and enable
     * "GitHub hook trigger for GITScm polling" in the job. You can then add
     * githubPush() inside this triggers block as well.
     */
    triggers {
        pollSCM('H/5 * * * *')
    }

    parameters {
        booleanParam(
            name: 'PUSH_IMAGE',
            defaultValue: true,
            description: 'Push the built image to Docker Hub. Requires the dockerhub-credentials credential. Set to false for a dry run.'
        )
        string(
            name: 'NOTIFY_EMAIL',
            defaultValue: '',
            description: 'Optional address for failure notifications. Leave empty to log the notification in the console only.'
        )
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Getting project source code from GitHub'
                checkout scm
                sh 'git log -1 --pretty=format:"%h %an %ad %s" --date=short'
            }
        }

        stage('Setup Python') {
            steps {
                echo 'Creating a clean virtual environment and installing dependencies'
                sh 'rm -rf .venv'
                sh 'python3 --version'
                sh 'python3 -m venv .venv'
                sh '.venv/bin/python -m pip install -r requirements.txt'
            }
        }

        stage('Build') {
            steps {
                echo 'Compiling the Python application'
                sh '.venv/bin/python -m compileall -q app.py'
                sh '''
                    .venv/bin/python - <<'PY'
import app
print(app.greet("Jenkins"))
PY
                '''
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
                echo 'Packaging application source and Docker assets'
                sh 'mkdir -p dist'
                sh '''
                    tar -czf "dist/jenkins-python-ci-${BUILD_NUMBER}.tar.gz" \
                        app.py tests requirements.txt README.md Dockerfile .dockerignore
                '''
                archiveArtifacts artifacts: 'dist/*.tar.gz',
                                 fingerprint: true
            }
        }

        stage('Docker Build') {
            steps {
                echo 'Building the application image'
                sh '''
                    set -eu
                    docker build \
                        -t "${DOCKER_IMAGE}:${BUILD_NUMBER}" \
                        -t "${DOCKER_IMAGE}:latest" .
                    echo "Built ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                '''
                echo 'Running the image once as a container smoke test'
                sh 'docker run --rm "${DOCKER_IMAGE}:${BUILD_NUMBER}"'
            }
        }

        stage('Deploy') {
            when {
                expression { params.PUSH_IMAGE }
            }
            steps {
                echo 'Pushing the image to Docker Hub'
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set -eu
                        trap 'docker logout >/dev/null 2>&1 || true' EXIT

                        echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin

                        docker tag "${DOCKER_IMAGE}:${BUILD_NUMBER}" "${DOCKERHUB_USER}/${DOCKER_IMAGE}:${BUILD_NUMBER}"
                        docker tag "${DOCKER_IMAGE}:latest" "${DOCKERHUB_USER}/${DOCKER_IMAGE}:latest"

                        docker push "${DOCKERHUB_USER}/${DOCKER_IMAGE}:${BUILD_NUMBER}"
                        docker push "${DOCKERHUB_USER}/${DOCKER_IMAGE}:latest"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Build #${env.BUILD_NUMBER} succeeded. Image: ${env.DOCKER_IMAGE}:${env.BUILD_NUMBER}"
        }

        failure {
            echo "Build #${env.BUILD_NUMBER} FAILED. Check the failing stage and console output."
            script {
                if (params.NOTIFY_EMAIL?.trim()) {
                    try {
                        mail to: params.NOTIFY_EMAIL,
                             subject: "[Jenkins] FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                             body: "Build #${env.BUILD_NUMBER} failed.\n\nJob: ${env.JOB_NAME}\nConsole: ${env.BUILD_URL}console"
                    } catch (error) {
                        echo "Email notification could not be sent: ${error}"
                    }
                } else {
                    echo "Set the NOTIFY_EMAIL parameter and configure SMTP to receive failure emails."
                }
            }
        }

        unstable {
            echo "Build #${env.BUILD_NUMBER} is UNSTABLE."
        }

        always {
            echo "Pipeline finished with status: ${currentBuild.currentResult}"
        }
    }
}
