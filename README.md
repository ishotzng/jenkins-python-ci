# Jenkins Python CI/CD Project

## Overview
A simple Python application demonstrating Continuous Integration and Continuous Delivery (CI/CD) using Jenkins and GitHub.

## Technologies
- Python 3
- Git and GitHub
- Jenkins
- Linux (Ubuntu)
- Unit Testing

## Application Features
- Displays a welcome message.
- Performs basic mathematical calculations.
- Includes automated unit tests.

## Jenkins Pipeline
The Jenkins pipeline automates the following stages:

1. Checkout – Retrieves source code from GitHub.
2. Setup Python – Creates a virtual environment and installs requirements.
3. Build – Compiles the Python application.
4. Test – Executes automated unit tests.
5. Package – Creates and archives the application.

## Run Locally

Create and activate a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
