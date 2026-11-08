# Jenkins Python CI/CD Project

A small Python application used to demonstrate a complete Jenkins CI/CD
pipeline. The pipeline runs on every push/changeset, validates the code with
unit tests, packages the source, builds a Docker image, smoke-tests the
container, and pushes the image to Docker Hub using Jenkins credentials.

## Overview

| Item | Value |
|---|---|
| Application | Python 3 CLI (`app.py`) |
| Tests | `unittest` (`tests/test_app.py`) |
| CI server | Jenkins (declarative Pipeline) |
| Container | Docker / Docker Hub |
| Triggers | SCM polling (and optional GitHub webhook) |
| Credentials | `dockerhub-credentials` (Jenkins Credentials Binding) |
| Source control | GitHub |

## Architecture

```text
 GitHub (main)
      |
      | push / pollSCM
      v
 +-------------------------------------------------------+
 | Jenkins                                               |
 |                                                       |
 |  1 Checkout        git checkout                       |
 |  2 Setup Python    venv + pip install                 |
 |  3 Build           compileall + import smoke test     |
 |  4 Test            unittest                           |
 |  5 Package         tar.gz + archiveArtifacts          |
 |  6 Docker Build    docker build + docker run          |
 |  7 Deploy          docker login/push -> Docker Hub    |
 |                                                       |
 |  post { failure { mail / console notification } }     |
 +---------------------------+---------------------------+
                             |
                             v
                Docker Hub: <user>/jenkins-python-ci
                tags: <build-number>, latest
```

## Repository layout

```text
.
├── app.py                  # application code
├── tests/test_app.py       # unittest suite
├── requirements.txt        # Python dependencies (none required)
├── Dockerfile              # application image
├── .dockerignore           # keeps the build context small
├── Jenkinsfile             # 7-stage declarative pipeline
├── README.md
└── .gitignore
```

## Pipeline stages

| # | Stage | What it does | Evidence |
|---|---|---|---|
| 1 | **Checkout** | Pulls the triggering commit and prints its SHA | Console log |
| 2 | **Setup Python** | Creates a clean `.venv`, installs `requirements.txt` | Console log |
| 3 | **Build** | `compileall` plus an import smoke test | Console log |
| 4 | **Test** | Runs the `unittest` suite | Console test output |
| 5 | **Package** | Creates `dist/jenkins-python-ci-<build>.tar.gz` and archives it | Jenkins **Artifacts** |
| 6 | **Docker Build** | Builds `jenkins-python-ci:<build>` and `:latest`; runs the image | Console log, `docker images` |
| 7 | **Deploy** | Logs in with Jenkins credentials, tags and pushes to Docker Hub | Console log, Docker Hub tags |

The pipeline also defines:

- `triggers { pollSCM('H/5 * * * *') }` — automatic builds every five minutes
  when the repository changes. An optional GitHub webhook gives immediate
  builds.
- `post { failure { ... } }` — logs a failure notification and sends an email
  when `NOTIFY_EMAIL` is set and SMTP is configured.
- `withCredentials` — the Docker Hub token never appears in the repository or
  the Jenkinsfile.

Key excerpts:

```groovy
triggers {
    pollSCM('H/5 * * * *')
}

stage('Deploy') {
    when { expression { params.PUSH_IMAGE } }
    steps {
        withCredentials([
            usernamePassword(
                credentialsId: 'dockerhub-credentials',
                usernameVariable: 'DOCKERHUB_USER',
                passwordVariable: 'DOCKERHUB_TOKEN'
            )
        ]) {
            sh '''
                echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin
                docker tag  "${DOCKER_IMAGE}:${BUILD_NUMBER}" "${DOCKERHUB_USER}/${DOCKER_IMAGE}:${BUILD_NUMBER}"
                docker push "${DOCKERHUB_USER}/${DOCKER_IMAGE}:${BUILD_NUMBER}"
            '''
        }
    }
}

post {
    failure {
        echo "Build #${env.BUILD_NUMBER} FAILED"
        script {
            if (params.NOTIFY_EMAIL?.trim()) {
                mail to: params.NOTIFY_EMAIL, subject: 'Jenkins build failed', body: 'See the console output.'
            }
        }
    }
}
```

## Prerequisites

- Jenkins with the **Pipeline**, **Git**, **GitHub**, and **Credentials Binding**
  plugins.
- Docker Engine on the Jenkins agent/controller.
- A Docker Hub account and an access token.
- Python 3.9+ locally (optional, for running tests outside Jenkins).

## Jenkins setup

### 1. Install Docker

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker

# Let the Jenkins service use the Docker socket
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Verify as the Jenkins user
sudo -u jenkins docker info
```

RHEL/Rocky/Alma:

```bash
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
sudo -u jenkins docker info
```

> The Docker group is effectively root-equivalent on the host. Treat access to
> the Docker socket as an administrative privilege and only run trusted
> repositories on this Jenkins instance.

If Jenkins itself runs in a container, mount the host socket and ensure the
container user is in the matching group:

```bash
-v /var/run/docker.sock:/var/run/docker.sock
```

### 2. Install/verify Jenkins plugins

**Manage Jenkins → Plugins → Available plugins**:

| Plugin | Why |
|---|---|
| Pipeline (`workflow-aggregator`) | Declarative pipeline |
| Git | `checkout scm` |
| GitHub | Webhook trigger support (optional) |
| Credentials Binding | `withCredentials` |
| Timestamper | `timestamps()` |
| Docker Pipeline (optional) | Not required by this Jenkinsfile, which uses the Docker CLI |

`pollSCM`, `archiveArtifacts`, `mail` and `timeout` are provided by core/bundled
components.

### 3. Create the Docker Hub credential

1. Docker Hub → **Account Settings → Security → New Access Token**.
2. Give it a name such as `jenkins-python-ci` and **Read & Write** permission.
3. Copy the token once — Docker Hub will not show it again.
4. Jenkins → **Manage Jenkins → Credentials → System → Global credentials →
   Add Credentials**.
5. Kind: **Username with password**.
6. ID: **`dockerhub-credentials`** (must match the Jenkinsfile exactly).
7. Username: your Docker Hub username.
8. Password: the access token (not your Docker Hub account password).
9. Save.

The image is pushed as:

```text
<DOCKERHUB_USER>/jenkins-python-ci:<BUILD_NUMBER>
<DOCKERHUB_USER>/jenkins-python-ci:latest
```

Create the `jenkins-python-ci` repository on Docker Hub, or let the first push
create it under your account.

### 4. Create the Jenkins job

1. **New Item → Pipeline** → name it `jenkins-python-ci` → OK.
2. **Pipeline → Definition: Pipeline script from SCM**.
3. SCM: **Git**; Repository URL:
   `https://github.com/ishotzng/jenkins-python-ci.git`.
4. Branch Specifier: `*/main`.
5. Script Path: `Jenkinsfile`.
6. **Build Triggers**:
   - **Poll SCM**: `H/5 * * * *` (also defined in the Jenkinsfile).
   - Optional: **GitHub hook trigger for GITScm polling** if you configure a
     webhook.
7. Save and click **Build Now**.

### 5. Optional: immediate builds with a GitHub webhook

The pipeline already polls SCM, so builds are automatic without a webhook.
For immediate builds:

1. GitHub repository → **Settings → Webhooks → Add webhook**.
2. Payload URL: `http://<JENKINS_URL>:8080/github-webhook/`
   (the trailing slash matters; use HTTPS if behind a proxy/tunnel).
3. Content type: `application/json`.
4. Event: **Just the push event**.
5. Enable **GitHub hook trigger for GITScm polling** in the Jenkins job.
6. Push a commit and check GitHub **Recent Deliveries** for HTTP `200`.

If Jenkins is not reachable from GitHub (private IP/laptop), keep `pollSCM` and
mention that choice in your report.

## Pipeline parameters

| Parameter | Default | Purpose |
|---|---|---|
| `PUSH_IMAGE` | `true` | Push the image to Docker Hub. Set to `false` for a dry run without Docker Hub credentials. |
| `NOTIFY_EMAIL` | empty | Failure email recipient. Leave empty to keep the notification in the console. |

For the first run, if you have not created the Docker Hub credential yet, run
**Build with Parameters** with `PUSH_IMAGE=false`; the Deploy stage is skipped
and the rest of the pipeline can still be validated. For the submission
screenshot, configure the credential and run with `PUSH_IMAGE=true` so the
Deploy stage is green and the image is visible on Docker Hub.

## Run locally

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

# Run the application
python app.py

# Run the test suite
python -m unittest discover -s tests -v
```

Expected test output:

```text
Ran 4 tests in 0.001s
OK
```

## Build and run the container locally

```bash
docker build -t jenkins-python-ci:local .
docker run --rm jenkins-python-ci:local
```

Expected container output:

```text
Hello, DevOps Engineer! Welcome to Jenkins CI/CD.
2 + 3 = 5
```

To push manually (optional):

```bash
echo "<DOCKERHUB_TOKEN>" | docker login -u "<DOCKERHUB_USER>" --password-stdin
docker tag jenkins-python-ci:local "<DOCKERHUB_USER>/jenkins-python-ci:local"
docker push "<DOCKERHUB_USER>/jenkins-python-ci:local"
docker logout
```

## Screenshots and submission evidence

### Previous run — 5-stage pipeline

These screenshots show the earlier version of the pipeline (Checkout, Setup,
Build, Test, Package). They are kept as history. The Docker Build and Deploy
stages were added after this run, so **new screenshots are required** for the
updated submission.

<img width="1158" height="582" alt="Screenshot 2026-11-07 162207" src="https://github.com/user-attachments/assets/bb95b679-268c-4e16-a731-b47105de5795" />
<img width="1887" height="797" alt="Screenshot 2026-11-07 160308" src="https://github.com/user-attachments/assets/2e98aa7f-44df-4b28-bf4d-99701bc16185" />
<img width="1505" height="788" alt="Screenshot 2026-11-07 150109" src="https://github.com/user-attachments/assets/5622a3b0-f817-4c02-b2de-d3185b005a0f" />
<img width="1742" height="826" alt="Screenshot 2026-11-07 145840" src="https://github.com/user-attachments/assets/d56f3e62-8106-47d7-a774-3e97bb9de847" />
<img width="1637" height="936" alt="Screenshot 2026-11-07 145728" src="https://github.com/user-attachments/assets/5dd5bab6-d52b-47a3-8bdc-41d3256f1d0d" />

### New evidence to capture after the Docker update

| # | Screenshot | What it must show |
|---|---|---|
| 1 | `01-stage-view.png` | **All seven stages green**: Checkout, Setup Python, Build, Test, Package, Docker Build, Deploy |
| 2 | `02-docker-build-console.png` | `docker build` output, image tags and the `docker run` smoke-test output |
| 3 | `03-deploy-console.png` | Docker login (token masked), `docker push` digest for `<build>` and `latest` |
| 4 | `04-dockerhub-tags.png` | Docker Hub repository with the build-number and `latest` tags |
| 5 | `05-artifacts.png` | `dist/jenkins-python-ci-<build>.tar.gz` in Jenkins |
| 6 | `06-pipeline-config.png` | Pipeline from SCM, branch `*/main`, script path `Jenkinsfile` |
| 7 | `07-triggers.png` | Poll SCM `H/5 * * * *` and/or GitHub webhook with a `200` delivery |
| 8 | `08-failed-build.png` | A deliberately failed build showing the `post { failure { ... } }` message |
| 9 | `09-email-notification.png` | Optional: failure email when `NOTIFY_EMAIL` and SMTP are configured |

To demonstrate the failure notification, temporarily break one test (for
example, change `assertEqual(result, 5)` to `assertEqual(result, 6)`), push,
capture the red **Test** stage and the `Build #... FAILED` console line, then
revert the change.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `docker: command not found` | Docker is not installed on the Jenkins agent | Install Docker and restart the Jenkins service |
| `permission denied while trying to connect to the Docker daemon socket` | Jenkins user is not in the `docker` group | `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins`; verify with `sudo -u jenkins docker info` |
| `Could not find credentials entry with ID 'dockerhub-credentials'` | Credential missing or wrong ID | Create the Username/Password credential with that exact ID |
| `denied: requested access to the resource is denied` | Wrong Docker Hub user or token lacks write permission | Use the correct username and a Read & Write access token |
| `unauthorized: incorrect username or password` | Account password used instead of token | Create an access token and update the Jenkins credential |
| `Cannot connect to the Docker daemon` | Docker service stopped | `sudo systemctl start docker` |
| `PUSH_IMAGE=false` leaves Deploy grey | Stage is intentionally skipped | Run with `PUSH_IMAGE=true` after configuring the credential |
| SCM polling does not start builds | Job is not configured from SCM, or wrong branch | Use **Pipeline script from SCM**, branch `*/main`, Script Path `Jenkinsfile` |
| Webhook returns 404 | URL missing `/github-webhook/` or trigger not enabled | Fix the payload URL and enable the hook trigger |
| `mail` step fails | SMTP not configured | Configure **Manage Jenkins → System → E-mail Notification**, or leave `NOTIFY_EMAIL` empty and use the console message |
| `pip install` fails | No internet/proxy from the agent | Check outbound access; `requirements.txt` currently has no third-party packages |
| Tests fail after checkout | Python version or stale `.venv` | The pipeline recreates `.venv`; check `python3 --version` |
| Docker build is slow | Pulling `python:3.12-slim` again | The base image is cached after the first build; avoid `--no-cache` unless needed |

## Security notes

- The Docker Hub token is stored only in Jenkins Credentials and injected with
  `withCredentials`.
- `docker login` uses `--password-stdin`; the token is not passed on the command
  line.
- A `trap` logs out of Docker Hub even if the push fails.
- The image runs as a non-root user (`appuser`).
- Docker group membership is root-equivalent on the host; restrict who can
  change the Jenkinsfile and who can access Jenkins.
- Do not commit `.env`, `.venv`, tokens or kubeconfigs. The `.gitignore` covers
  local Python and build output.

## Cleanup

```bash
# Remove local images created by test runs
docker rmi jenkins-python-ci:latest || true
docker image prune -f

# Remove old Jenkins builds/artifacts if disk usage grows
# Manage Jenkins -> Disk usage, or delete old builds from the job page
```

If you created a temporary Docker Hub token for the course, revoke it after the
submission.

## Future improvements

- Publish JUnit XML and coverage from the test stage (for example with
  `pytest`/`pytest-cov` or `unittest-xml-reporting`).
- Add an image vulnerability scan (`trivy image ...`) before the push.
- Use a multi-stage Docker build and pin the base image by digest.
- Push to GitHub Container Registry/Amazon ECR in addition to Docker Hub.
- Add a real deployment stage (SSH/Kubernetes) that consumes the pushed image
  rather than only publishing it.
