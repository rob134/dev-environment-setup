# Changelog

## V4 — Final consolidated bootstrap

V4 consolidates the lessons from the first three iterations into a single final workstation bootstrap.

### What V4 keeps from previous versions

- WinGet for tools with reliable package IDs.
- Official binary archives for Maven, Gradle, RabbitMQ and Kafka.
- `C:\DevTools` for manually managed developer distributions.
- Machine-level environment variables for Java, Maven, Gradle, PostgreSQL, Erlang, RabbitMQ and Kafka.
- Post-install command validation.
- Multiple JDKs: 8, 11, 17, 21 and 25.
- Native Windows installation with no Docker dependency.
- Manual operational configuration for databases and brokers.

### V4 improvements

- Automatically attempts to install missing Temurin JDKs instead of only detecting them.
- Normalizes competing Eclipse Adoptium JDK `bin` entries from the machine PATH.
- Keeps Java 21 as the default command-line JDK while preserving `JAVA_HOME_8`, `JAVA_HOME_11`, `JAVA_HOME_17`, `JAVA_HOME_21` and `JAVA_HOME_25`.
- Adds transcript logging under `C:\DevTools\logs`.
- Records installation/download/extraction failures and prints a final issue summary instead of silently losing the error.
- Checks prerequisites such as WinGet and `tar`.
- Uses reusable helper functions for installation, download, PATH management, environment refresh and validation.
- Keeps the installation/operation boundary explicit.

## V3 — Controlled workstation bootstrap

V3 was created after real execution exposed two important problems in V2.

### Successful improvements

- Java 21 became the default JDK.
- Only Java 21 `bin` was added by the script to reduce JDK PATH competition.
- Environment variables and PATH were refreshed during execution.
- Existing downloads/installations were detected before repeating work.
- Kafka `.tgz` extraction was changed to Windows `tar`.
- Erlang was treated explicitly as a RabbitMQ prerequisite.
- PostgreSQL, RabbitMQ and Kafka operational setup was deliberately left manual.
- Validation was added for Java, Maven, Gradle, PostgreSQL, Erlang, RabbitMQ and Kafka commands.

### Problems that V3 addressed

- V2 could leave multiple JDK `bin` directories on PATH, causing `java.exe` to resolve to Java 25 even when `JAVA_HOME` pointed to Java 21.
- Kafka extraction needed a reliable Windows-native approach for the official `.tgz` archive.

## V2 — Hybrid installer

V2 moved away from a WinGet-only strategy.

### Successful improvements

- WinGet remained useful for common applications and CLIs.
- Official archives were used for Apache Maven, Gradle, RabbitMQ and Kafka.
- Installations were extracted to predictable locations.
- Machine environment variables were introduced.
- Multiple Java homes were explicitly represented as `JAVA_HOME_*` variables.
- A validation stage checked the resulting command-line environment.

### Problems discovered during real execution

- Maven, Gradle, PostgreSQL, RabbitMQ and Kafka were not reliably available through the expected WinGet package IDs used by V1.
- PostgreSQL, Erlang, RabbitMQ and Kafka were still not fully operational after the bootstrap; binary installation is different from service/application configuration.
- Most importantly, putting all JDK `bin` directories on PATH created a Java version resolution conflict.

## V1 — WinGet-first proof of concept

V1 intentionally tried to use WinGet for almost the entire workstation.

### Tools targeted

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

### What worked

The real V1 execution successfully installed or detected many common developer tools, including Git, GitHub CLI, all five Temurin JDKs, IntelliJ IDEA Ultimate, VS Code, Node.js, Python, MySQL, DBeaver, AWS CLI, Azure CLI, Google Cloud CLI, kubectl, Helm and 7-Zip.

### What failed or exposed a limitation

WinGet could not find reliable package entries for Apache Maven, Gradle, PostgreSQL, RabbitMQ and Apache Kafka using the package IDs expected by the script.

### Lesson

A package manager is useful, but it should not be treated as the only installation source for a complete enterprise development workstation.

## Final architectural lesson

The project evolved from:

```text
V1: "Install everything with WinGet"
             |
             v
V2: "Use the right source for each dependency"
             |
             v
V3: "Separate installation from operational configuration"
             |
             v
V4: "Make the whole bootstrap repeatable, observable and resilient"
```

The final goal is not a one-click production environment. It is a reproducible developer workstation that removes repetitive setup while preserving the engineering knowledge required to configure, operate and troubleshoot the underlying infrastructure.
