# syntax=docker/dockerfile:1
#
# Project 8 - container image for the Jenkins Python CI/CD demo.
#
# The application is a short-lived CLI, so there is no EXPOSE/health endpoint.
# The Jenkins pipeline runs the image once as a smoke test, then tags and pushes
# it to Docker Hub.

FROM python:3.12-slim

LABEL org.opencontainers.image.title="jenkins-python-ci"
LABEL org.opencontainers.image.description="Python CI/CD demo application built by Jenkins"
LABEL org.opencontainers.image.source="https://github.com/ishotzng/jenkins-python-ci"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Run as a non-root user. The app does not need write access to the image.
RUN useradd --create-home --shell /usr/sbin/nologin appuser

COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appuser app.py .

# Fail the image build if the application has a syntax error.
RUN python -m compileall -q app.py

USER appuser

CMD ["python", "app.py"]
