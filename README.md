# Dev Environment Setup

PowerShell automation for preparing a Windows development workstation for Java backend, distributed systems, cloud and enterprise integration work.

This repository is deliberately more than an installer. It documents the complete evolution of a workstation bootstrap strategy, from a simple WinGet proof of concept to a resilient, observable and controlled V4 bootstrap.

## Real purpose

The real purpose of this project is to create a **repeatable engineering workstation without turning it into a black box**.

A serious Java backend environment can require multiple JDKs, build tools, databases, message brokers, Kafka, cloud CLIs, Kubernetes tooling and diagnostic utilities. Reinstalling all of this manually is slow, inconsistent and difficult to reproduce.

At the same time, hiding everything behind Docker or blindly creating services removes part of the engineering experience. PostgreSQL roles and databases, RabbitMQ services/plugins and Kafka KRaft storage/broker configuration are operational concerns worth understanding directly.

The project therefore follows a deliberate boundary:

- **Automate:** repetitive downloads, package installation, extraction, environment variables, PATH management and basic validation.
- **Observe:** log what happened, report failures and validate the resulting command-line environment.
- **Keep manual:** service lifecycle, credentials, users, databases, broker configuration, KRaft initialization, plugins, persistence, security and production-like operational decisions.
- **Do not use Docker for the workstation bootstrap.** The goal is to learn and operate the native Windows installations directly.

The result is a workstation that can be rebuilt consistently while still requiring the developer to understand what is actually running underneath it.

## Version history

### V1 — WinGet-first proof of concept

`setup-dev-v1.ps1` was the original approach: use **WinGet as much as possible** and install the development stack from package IDs.

It targeted PowerShell 7, Git, GitHub CLI, Temurin JDK 8/11/17/21/25, IntelliJ IDEA Ultimate, VS Code, Node.js LTS/npm, Python, MySQL, DBeaver, AWS CLI, Azure CLI, Google Cloud CLI, kubectl, Helm, 7-Zip, Maven, Gradle, PostgreSQL, RabbitMQ and Kafka.

#### What worked in the real execution

Many common tools were already installed or were successfully installed: Git, GitHub CLI, all five Temurin JDKs, IntelliJ IDEA Ultimate, VS Code, Node.js, Python, MySQL, DBeaver, AWS CLI, Azure CLI, Google Cloud CLI, kubectl, Helm and 7-Zip.

#### What failed / what we learned

WinGet could not reliably find the expected package IDs for **Maven, Gradle, PostgreSQL, RabbitMQ and Apache Kafka**.

**Lesson:** WinGet is excellent for many developer tools, but package-manager coverage is not uniform enough to be the only installation mechanism for a complete enterprise workstation.

### V2 — Hybrid installation and environment management

`setup-dev-v2.ps1` changed the architecture instead of fighting the package catalog.

- WinGet remained the preferred source where practical.
- Official Apache/Gradle/RabbitMQ archives were used where direct binary installation was more reliable.
- Distributions were extracted into predictable locations such as `C:\DevTools`.
- Machine-level variables were introduced: `JAVA_HOME`, `JAVA_HOME_8`, `JAVA_HOME_11`, `JAVA_HOME_17`, `JAVA_HOME_21`, `JAVA_HOME_25`, `MAVEN_HOME`, `GRADLE_HOME`, `POSTGRES_HOME`, `ERLANG_HOME`, `RABBITMQ_SERVER` and `KAFKA_HOME`.
- PATH management and command validation were added.

#### The important V2 discovery

The real execution found all five installed Temurin JDKs and correctly set Java 21 as `JAVA_HOME`. However, V2 also placed multiple JDK `bin` directories on PATH.

As a result, command resolution could select **Java 25** even though `JAVA_HOME` pointed to **Java 21**.

**Lesson:** `JAVA_HOME` and `PATH` are related but are not the same mechanism. Multi-JDK environments require deliberate PATH control.

### V3 — Controlled workstation bootstrap

`setup-dev-v3.ps1` kept the successful hybrid strategy and corrected the main V2 problems.

Key improvements:

1. **Java PATH control:** only the selected Java 21 `bin` directory was added by the script, reducing competition between JDKs.
2. **Environment refresh:** machine variables and PATH were refreshed during execution.
3. **Existing-install detection:** existing downloads/installations were detected before repeating work.
4. **Kafka extraction:** Windows `tar` was used to extract the official `.tgz` distribution.
5. **RabbitMQ dependency:** Erlang was handled explicitly as a RabbitMQ prerequisite.
6. **Operational separation:** PostgreSQL, RabbitMQ and Kafka were prepared at binary/PATH level, while service/application configuration remained manual.
7. **Validation:** commands such as `java`, `mvn`, `gradle`, `psql`, `erl`, `rabbitmqctl` and `kafka-topics` were checked.

V3 also exposed an important remaining limitation: avoiding new JDK PATH conflicts is not the same as cleaning every old JDK entry that may already exist in a user's machine PATH. V4 addresses that specific case.

### V4 — Final consolidated bootstrap

`setup-dev-v4.ps1` is the **final consolidated version**. It does not simply copy V3; it incorporates the lessons learned from the real V1/V2/V3 executions and makes the bootstrap more resilient and observable.

#### V4 includes

- WinGet for common tools where reliable.
- Automatic attempts to install missing Temurin JDKs 8, 11, 17, 21 and 25.
- `JAVA_HOME_8`, `_11`, `_17`, `_21`, `_25` plus Java 21 as the default `JAVA_HOME`.
- Machine PATH normalization for Eclipse Adoptium JDK entries so competing JDK `bin` directories do not remain ahead of the selected default.
- Maven 3.9.16 from the official Apache archive.
- Gradle 9.7.1 from the official Gradle archive.
- PostgreSQL 18 through WinGet.
- Erlang/OTP through WinGet.
- RabbitMQ 4.3.5 from the official release archive.
- Apache Kafka 4.3.1 from the official `.tgz` distribution.
- Git, GitHub CLI, Node/npm, Python, MySQL, DBeaver, AWS CLI, Azure CLI, Google Cloud CLI, kubectl, Helm and 7-Zip.
- Predictable `C:\DevTools` storage for manually managed distributions.
- Idempotent-ish detection of existing files and installations.
- Prerequisite checks for WinGet and Windows `tar`.
- Environment refresh before validation.
- Transcript logging under `C:\DevTools\logs`.
- Failure collection and a final issue summary instead of silently hiding installation problems.
- Final command validation.

### Why V4 is different from simply "install everything"

V4 is designed around four engineering properties:

```text
Repeatable
    +
Observable
    +
Resilient
    +
Operationally explicit
    =
Final workstation bootstrap
```

The script handles repetitive workstation preparation, but it does not pretend that installing binaries is the same thing as operating infrastructure.

## What V4 installs/configures

| Component | V4 behavior |
|---|---|
| PowerShell 7 | WinGet if missing |
| Git / GitHub CLI | WinGet if missing |
| Temurin JDK 8/11/17/21/25 | Detect and install if missing; configure `JAVA_HOME_*` |
| Java default | Java 21 via `JAVA_HOME` and PATH |
| Maven 3.9.16 | Official archive |
| Gradle 9.7.1 | Official archive |
| PostgreSQL 18 | WinGet; PATH and `POSTGRES_HOME` |
| Erlang/OTP | WinGet; PATH and `ERLANG_HOME` |
| RabbitMQ 4.3.5 | Official archive; binaries/PATH only |
| Apache Kafka 4.3.1 | Official archive; binaries/PATH only |
| Node.js / npm | WinGet if missing |
| Python | WinGet if missing |
| MySQL | WinGet if missing |
| DBeaver | WinGet if missing |
| AWS / Azure / GCP CLI | WinGet if missing |
| kubectl / Helm | WinGet if missing |
| 7-Zip | WinGet if missing |

> **Important:** V4 installs missing JDKs when the corresponding WinGet packages are available. If a package cannot be installed or detected, the problem is recorded in the final report and log.

## Java 8, 11, 17, 21 and 25

The multiple-JDK setup represents a realistic backend maintenance environment. Enterprise systems do not all move to the newest Java version at the same time.

The model is:

```text
JAVA_HOME_8   -> Java 8
JAVA_HOME_11  -> Java 11
JAVA_HOME_17  -> Java 17
JAVA_HOME_21  -> Java 21 (default)
JAVA_HOME_25  -> Java 25
JAVA_HOME     -> Java 21
PATH          -> Java 21 bin by default
```

The objective is not to run all versions simultaneously. It is to make version selection explicit and testable.

## Operational configuration remains manual by design

### PostgreSQL

V4 installs/exposes PostgreSQL but does not invent database credentials or application topology.

Manual work includes:

- initialization when required
- passwords
- roles/users
- databases
- schemas
- permissions
- application connection settings

Validation:

```powershell
psql --version
```

### RabbitMQ

V4 installs Erlang and RabbitMQ binaries and exposes the RabbitMQ commands on PATH. It does not automatically create/start the Windows service or enable plugins.

Manual learning/operation includes:

- service installation/start/stop
- users
- permissions
- virtual hosts
- management plugin
- queues/exchanges/bindings
- persistence and operational settings

Validation:

```powershell
rabbitmqctl status
```

### Kafka

V4 downloads and extracts Kafka and exposes `kafka-topics` on PATH. It does not automatically initialize KRaft storage, choose broker configuration, start the broker or create topics.

Manual learning/operation includes:

- KRaft storage initialization
- broker configuration
- startup/shutdown
- topics
- partitions
- replication
- client configuration

Validation:

```powershell
kafka-topics.bat --version
```

## Logging and troubleshooting

V4 creates a transcript under:

```text
C:\DevTools\logs\setup-dev-v4-YYYYMMDD-HHMMSS.log
```

The script also keeps an in-memory list of recorded failures and prints them at the end. This is important because a workstation bootstrap should make problems visible instead of ending with an ambiguous "something failed" message.

## Architecture

```text
                         Windows Workstation
                                  |
                         setup-dev-v4.ps1
                                  |
             +--------------------+--------------------+
             |                    |                    |
          WinGet            Official archives      Existing tools
             |                    |                    |
      common apps/CLIs     Maven / Gradle       already-installed
      Java / PostgreSQL    RabbitMQ / Kafka       components
      Erlang
             |                    |                    |
             +--------------------+--------------------+
                                  |
                         Environment + PATH
                                  |
                          Refresh environment
                                  |
                          Command validation
                                  |
                         Transcript + report
                                  |
                                  v
                  Manual operational configuration
             PostgreSQL | RabbitMQ | Kafka | Security
```

## Requirements

- Windows 10/11 x64
- Administrator PowerShell
- Internet connection
- WinGet for package-managed components
- Windows `tar` for Kafka `.tgz` extraction

## Usage

Open PowerShell as **Administrator**:

```powershell
git clone https://github.com/rob134/dev-environment-setup.git
cd dev-environment-setup
Set-ExecutionPolicy -Scope Process Bypass
.\setup-dev-v4.ps1
```

After completion, **close and reopen PowerShell** so the updated machine PATH and environment variables are loaded by the new shell process.

## V1 → V4 at a glance

| Version | Strategy | Main problem discovered | Engineering lesson |
|---|---|---|---|
| V1 | WinGet-first | Package availability/IDs | One installer source is not enough |
| V2 | WinGet + official archives + env vars | Multiple JDKs competed through PATH | Environment variables and PATH need deliberate design |
| V3 | Controlled hybrid bootstrap | Existing old JDK PATH entries could still interfere | Installation and operation should be separated |
| V4 | Consolidated + resilient + observable | Final focus is reliability and diagnostics | A good bootstrap is repeatable, visible and operationally explicit |

For the detailed history, see [`CHANGELOG.md`](CHANGELOG.md).

## Suggested learning path after V4

1. Verify the CLI tools.
2. Test Java 8/11/17/21/25 and understand `JAVA_HOME` versus PATH.
3. Configure PostgreSQL manually.
4. Create a database, role and permissions.
5. Configure and start RabbitMQ manually.
6. Create a RabbitMQ user/vhost and enable management when appropriate.
7. Initialize Kafka KRaft manually.
8. Start a Kafka broker and create topics.
9. Build a small Java producer/consumer.
10. Connect PostgreSQL + Kafka/RabbitMQ from Spring Boot.
11. Exercise failure, retry, idempotency and observability scenarios.
12. Practice switching Java versions and diagnosing PATH/runtime issues.

That is the real target: **not merely having the software installed, but being able to explain, configure, operate and troubleshoot the infrastructure behind a Java backend system.**

## Scope and philosophy

This repository is a **developer workstation bootstrap**, not a production infrastructure deployment tool.

For production environments, versions, checksums, service accounts, secrets, firewall rules, persistence, monitoring, backups, observability and security policies must be managed explicitly.

## License

No license has been added yet.
