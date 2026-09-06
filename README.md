# Dev Environment Setup

PowerShell automation for preparing a Windows development workstation for Java backend and enterprise integration work.

## What it installs/configures

- PowerShell 7
- Java 8, 11, 17, 21 and 25 (Temurin, when already installed)
- Maven 3.9.16
- Gradle 9.7.1
- PostgreSQL 18
- Erlang/OTP
- RabbitMQ 4.3.5
- Apache Kafka 4.3.1
- Git / GitHub CLI
- Node.js / npm
- Python
- MySQL
- DBeaver
- AWS CLI
- Azure CLI
- Google Cloud CLI
- kubectl
- Helm
- 7-Zip

## Philosophy

The script automates repetitive installation and environment-variable/PATH work, but intentionally does **not** hide operational configuration behind Docker or one-click service setup.

That means PostgreSQL, RabbitMQ and Kafka can be configured and operated manually afterward, which is useful for practicing real-world enterprise administration.

## Requirements

- Windows 10/11 x64
- Administrator PowerShell
- Internet connection
- `winget` for packages that are not already installed
- 7-Zip for Kafka archive extraction

## Usage

Open PowerShell as **Administrator** and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup-dev-v3.ps1
```

After completion, **close and reopen PowerShell** so the updated machine PATH and environment variables are loaded.

## Java versions

The script detects the installed Temurin JDKs and creates:

```text
JAVA_HOME_8
JAVA_HOME_11
JAVA_HOME_17
JAVA_HOME_21
JAVA_HOME_25
JAVA_HOME
```

`JAVA_HOME` defaults to Java 21 when Java 21 is available.

> Note: the script currently adds detected JDK `bin` directories to the machine PATH. Therefore `java` resolution may follow PATH order rather than `JAVA_HOME`. For switching Java versions deliberately, use `JAVA_HOME` and PATH management explicitly.

## Manual configuration after installation

### PostgreSQL

The script installs PostgreSQL and exposes `psql` on PATH. Database initialization, passwords, roles, databases and application configuration remain manual.

Example validation:

```powershell
psql --version
```

### RabbitMQ

The script installs RabbitMQ and Erlang and exposes RabbitMQ commands on PATH. It does **not** create/start the Windows service or enable plugins automatically.

Example validation:

```powershell
rabbitmqctl status
```

### Kafka

The script downloads and extracts Kafka binaries and exposes `kafka-topics` on PATH. KRaft storage initialization, broker configuration and startup remain manual.

Example validation:

```powershell
kafka-topics.bat --version
```

## Important

This repository is intended as a workstation bootstrap, not as a production infrastructure deployment tool.

For production environments, versions, checksums, service accounts, secrets, firewall rules, persistence, monitoring and security policies should be managed explicitly.

## License

No license has been added yet.
