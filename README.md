# Dev Environment Setup

PowerShell automation for preparing a Windows development workstation for Java backend, distributed systems, cloud and enterprise integration work.

This repository is deliberately more than an installation script. It documents the **evolution of an environment bootstrap strategy**: from a simple WinGet-based installer, through a hybrid installer with official binary downloads and environment management, to a controlled workstation bootstrap that automates repetitive work while leaving important operational configuration manual.

## Real purpose of the project

The real purpose is to create a **repeatable engineering workstation** without turning the workstation into a black box.

A real backend/enterprise developer needs much more than a JDK and an IDE. The environment may involve multiple Java LTS/non-LTS versions, build tools, databases, message brokers, Kafka, cloud CLIs, Kubernetes tooling and diagnostic utilities. Installing all of that manually every time is slow, inconsistent and difficult to reproduce.

At the same time, blindly hiding everything behind Docker or a one-click service installer removes an important part of the learning experience. PostgreSQL roles and databases, RabbitMQ services/plugins and Kafka KRaft storage/broker configuration are operational concerns that are worth understanding directly.

Therefore this project follows a deliberate boundary:

- **Automate:** repetitive downloads, package installation, extraction, environment variables, PATH entries and basic command validation.
- **Keep manual:** service creation/startup, credentials, users, databases, broker configuration, KRaft initialization, plugins, persistence, security and production-like operational decisions.
- **Do not use Docker for this workstation bootstrap.** The goal is to learn and operate the native Windows installations directly.

The result is a workstation that can be rebuilt consistently while still requiring the developer to understand what is actually running underneath it.

## Version history

### V1 — WinGet-first bootstrap

`setup-dev-v1.ps1` is the original approach.

The idea was intentionally simple: use **WinGet as much as possible** and install the development stack from package IDs.

It attempted to install:

- PowerShell 7
- Git
- GitHub CLI
- Temurin JDK 8, 11, 17, 21 and 25
- IntelliJ IDEA Ultimate
- Visual Studio Code
- Node.js LTS / npm
- Python
- MySQL
- DBeaver Community
- AWS CLI
- Azure CLI
- Google Cloud CLI
- kubectl
- Helm
- 7-Zip
- Maven
- Gradle
- PostgreSQL
- RabbitMQ
- Apache Kafka

**What V1 taught us:** package-manager coverage is not uniform. Some tools were already installed, while others could not be found through the expected WinGet package IDs. In particular, Maven, Gradle, PostgreSQL, RabbitMQ and Kafka exposed the limitation of assuming that every developer dependency has a stable package entry that behaves the same way.

V1 was useful as a proof of concept, but it was too dependent on the package catalog.

### V2 — Hybrid installation and environment management

`setup-dev-v2.ps1` was the first major architectural improvement.

Instead of forcing every component through WinGet, V2 uses the appropriate installation mechanism for each dependency:

- WinGet for components with a practical package path.
- Official Apache/Gradle/RabbitMQ archives for components where direct binary installation is more reliable.
- Automatic extraction into `C:\DevTools` where appropriate.
- Machine-level environment variables such as `JAVA_HOME`, `MAVEN_HOME`, `GRADLE_HOME`, `POSTGRES_HOME`, `ERLANG_HOME`, `RABBITMQ_SERVER` and `KAFKA_HOME`.
- Machine PATH management.
- A validation phase using the actual command-line tools.

V2 also established the Java multi-version model:

```text
JAVA_HOME_8
JAVA_HOME_11
JAVA_HOME_17
JAVA_HOME_21
JAVA_HOME_25
JAVA_HOME
```

Java 21 was selected as the default `JAVA_HOME` when available.

**What V2 taught us:** installing multiple JDKs is not enough. Windows command resolution depends on PATH order, so simply putting every JDK `bin` directory on PATH can make `java.exe` resolve to a different version than the one represented by `JAVA_HOME`. That operational detail led directly to the V3 correction.

### V3 — Controlled workstation bootstrap

`setup-dev-v3.ps1` is the current version.

V3 keeps the successful hybrid strategy from V2 but tightens the boundary between **installation** and **operation**.

Key improvements:

1. **Java PATH control** — only the selected Java 21 `bin` directory is added to PATH, avoiding the previous situation where several JDKs competed in PATH order.
2. **Explicit environment refresh** — machine variables and PATH are refreshed during execution so validation can happen immediately.
3. **Idempotent-ish behavior** — existing files and installations are detected before downloading/extracting again.
4. **Kafka extraction fix** — Windows `tar` is used to extract the official `.tgz` distribution directly.
5. **RabbitMQ dependency handling** — Erlang is treated explicitly as a prerequisite for RabbitMQ.
6. **Operational separation** — PostgreSQL, RabbitMQ and Kafka are prepared at binary/PATH level, but their operational setup remains intentionally manual.
7. **Validation** — the script checks commands such as `java`, `mvn`, `gradle`, `psql`, `erl`, `rabbitmqctl` and `kafka-topics` after setup.

## What V3 installs/configures

- PowerShell 7
- Temurin JDK 8, 11, 17, 21 and 25 **when already installed**
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

> **Important:** V3 detects the installed Temurin JDKs and configures their `JAVA_HOME_*` variables. It does not install missing JDK versions automatically.

## Why Java 8, 11, 17, 21 and 25?

The multiple-JDK setup represents a realistic backend maintenance environment. Enterprise systems do not all move to the newest Java version at the same time. A developer may need to maintain a Java 8 application, work on Java 11/17 systems, build modern Java 21 services and experiment with newer releases.

The goal is not to run all versions simultaneously. The goal is to make switching and testing versions an explicit engineering task.

## Architecture of the setup

```text
                    Windows Workstation
                           |
                 setup-dev-v3.ps1
                           |
        +------------------+------------------+
        |                  |                  |
   WinGet packages    Official archives   Existing tools
        |                  |                  |
        |          +-------+-------+          |
        |          |       |       |          |
      Tools      Maven   Gradle RabbitMQ/Kafka |
                           |       |           |
                         Java    Erlang       Git/CLIs
                           |
                     Environment/PATH
                           |
                    Command validation
                           |
             Manual operational configuration
```

## Manual configuration by design

### PostgreSQL

The script exposes `psql` and prepares the installation. Database initialization, passwords, roles, databases, permissions and application connection settings remain manual.

Validation:

```powershell
psql --version
```

### RabbitMQ

The script installs the RabbitMQ binaries and Erlang dependency and exposes RabbitMQ commands on PATH. It does **not** create/start the Windows service or enable plugins automatically.

Validation:

```powershell
rabbitmqctl status
```

Afterward, the developer can learn the real operational workflow: service installation, startup, users, permissions, virtual hosts, plugins and management access.

### Kafka

The script downloads and extracts the Kafka binaries and exposes `kafka-topics` on PATH. It does **not** initialize KRaft storage, generate broker IDs/configuration, start the broker or create topics automatically.

Validation:

```powershell
kafka-topics.bat --version
```

Afterward, the developer can practice the actual Kafka lifecycle: KRaft storage initialization, broker configuration, startup, topics, partitions, replication and client configuration.

## Requirements

- Windows 10/11 x64
- Administrator PowerShell
- Internet connection
- WinGet for packages that are not already installed
- `tar` available on Windows for Kafka extraction

## Usage

Clone the repository and open PowerShell as **Administrator**:

```powershell
git clone https://github.com/rob134/dev-environment-setup.git
cd dev-environment-setup
Set-ExecutionPolicy -Scope Process Bypass
.\setup-dev-v3.ps1
```

After completion, **close and reopen PowerShell** so the updated machine PATH and environment variables are loaded by the new shell process.

## Project evolution at a glance

| Version | Main strategy | Main limitation | Result |
|---|---|---|---|
| V1 | WinGet-first | Package availability and inconsistent IDs | Fast proof of concept |
| V2 | WinGet + official archives | Multiple JDKs could conflict through PATH | Much more complete workstation bootstrap |
| V3 | Controlled hybrid bootstrap | Operational setup intentionally remains manual | Reproducible environment + hands-on enterprise administration |

## Scope and philosophy

This repository is a **developer workstation bootstrap**, not a production infrastructure deployment tool.

It is intentionally useful for learning backend and enterprise technologies such as:

- Java and JVM version management
- Maven and Gradle
- PostgreSQL and MySQL
- RabbitMQ and Erlang
- Apache Kafka and KRaft
- Git and GitHub workflows
- AWS, Azure and Google Cloud CLIs
- Kubernetes and Helm
- Local integration testing
- Enterprise-style messaging and database configuration

For production environments, versions, checksums, service accounts, secrets, firewall rules, persistence, monitoring, backups, observability and security policies must be managed explicitly.

## Suggested learning path after V3

1. Verify all CLI tools.
2. Configure PostgreSQL manually.
3. Create a database, role and permissions.
4. Configure and start RabbitMQ manually.
5. Create a virtual host/user and enable the management plugin when appropriate.
6. Initialize Kafka KRaft manually.
7. Start a Kafka broker and create topics.
8. Build a small Java producer/consumer application.
9. Connect PostgreSQL + Kafka/RabbitMQ from Spring Boot.
10. Exercise failure, retry, idempotency and observability scenarios.

That final stage is the real target: **not merely having the software installed, but being able to explain, configure, operate and troubleshoot the infrastructure behind a Java backend system.**

## License

No license has been added yet.
