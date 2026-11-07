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

<img width="1158" height="582" alt="Screenshot 2026-11-07 162207" src="https://github.com/user-attachments/assets/bb95b679-268c-4e16-a731-b47105de5795" />
<img width="1887" height="797" alt="Screenshot 2026-11-07 160308" src="https://github.com/user-attachments/assets/2e98aa7f-44df-4b28-bf4d-99701bc16185" />
<img width="1505" height="788" alt="Screenshot 2026-11-07 150109" src="https://github.com/user-attachments/assets/5622a3b0-f817-4c02-b2de-d3185b005a0f" />
<img width="1742" height="826" alt="Screenshot 2026-11-07 145840" src="https://github.com/user-attachments/assets/d56f3e62-8106-47d7-a774-3e97bb9de847" />
<img width="1637" height="936" alt="Screenshot 2026-11-07 145728" src="https://github.com/user-attachments/assets/5dd5bab6-d52b-47a3-8bdc-41d3256f1d0d" />
