#requires -RunAsAdministrator

<#[
.SYNOPSIS
    V4 - Final consolidated Windows developer workstation bootstrap.

.DESCRIPTION
    Consolidates the lessons from V1, V2 and V3 into one resilient, repeatable
    bootstrap for Java backend / distributed systems / cloud development.

    V4 automates:
      - WinGet package installation where reliable
      - official archive downloads for Maven, Gradle, RabbitMQ and Kafka
      - multiple Temurin JDKs (8/11/17/21/25)
      - environment variables and PATH management
      - idempotent-ish detection of existing installations
      - logging and final validation/reporting

    V4 deliberately does NOT automate operational decisions such as:
      - PostgreSQL roles, passwords, databases and permissions
      - RabbitMQ service lifecycle, users, vhosts and plugins
      - Kafka KRaft storage initialization, broker configuration and topics
      - production secrets, persistence, firewall, monitoring or security

    Docker is intentionally not part of this workstation bootstrap.
#>

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$DevTools = 'C:\DevTools'
$LogDir = Join-Path $DevTools 'logs'
$LogFile = Join-Path $LogDir ("setup-dev-v4-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $DevTools, $LogDir | Out-Null
Start-Transcript -Path $LogFile -Append | Out-Null

$script:Failures = New-Object System.Collections.Generic.List[string]

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Add-Failure {
    param([Parameter(Mandatory)][string]$Message)
    $script:Failures.Add($Message)
    Write-Warning $Message
}

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Add-SystemPath {
    param([Parameter(Mandatory)][string]$PathToAdd)
    if (-not (Test-Path -LiteralPath $PathToAdd)) { return }

    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $entries = $machinePath -split ';' | Where-Object { $_ -and $_.Trim() }
    $normalized = $PathToAdd.TrimEnd('\')

    if (-not ($entries | Where-Object { $_.TrimEnd('\') -ieq $normalized })) {
        [Environment]::SetEnvironmentVariable('Path', (($entries + $PathToAdd) -join ';'), 'Machine')
        Write-Host "PATH + $PathToAdd"
    }
}

function Remove-JavaBinsFromMachinePath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    if (-not $machinePath) { return }

    $entries = $machinePath -split ';' | Where-Object { $_ -and $_.Trim() }
    $filtered = $entries | Where-Object {
        $_ -notmatch '^C:\\Program Files\\Eclipse Adoptium\\jdk-[^;]+\\bin$'
    }

    if ($filtered.Count -ne $entries.Count) {
        [Environment]::SetEnvironmentVariable('Path', ($filtered -join ';'), 'Machine')
        Write-Host 'Removed competing Eclipse Adoptium JDK bin entries from machine PATH.'
    }
}

function Set-SystemVariable {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Machine')
    Set-Item -Path "Env:$Name" -Value $Value
    Write-Host "$Name = $Value"
}

function Refresh-Environment {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"

    foreach ($name in @(
        'JAVA_HOME','JAVA_HOME_8','JAVA_HOME_11','JAVA_HOME_17','JAVA_HOME_21','JAVA_HOME_25',
        'MAVEN_HOME','GRADLE_HOME','POSTGRES_HOME','ERLANG_HOME','RABBITMQ_SERVER','KAFKA_HOME'
    )) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Machine')
        if ($null -ne $value) { Set-Item -Path "Env:$name" -Value $value }
    }
}

function Download-File {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination
    )
    if (Test-Path -LiteralPath $Destination) {
        Write-Host "Already downloaded: $Destination"
        return $true
    }

    try {
        Write-Host "Downloading $Url"
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        Add-Failure "Download failed: $Url :: $($_.Exception.Message)"
        return $false
    }
}

function Install-WingetExact {
    param([Parameter(Mandatory)][string]$Id)

    if (-not (Test-CommandExists 'winget')) {
        Add-Failure "WinGet is not available. Cannot install package $Id."
        return $false
    }

    try {
        Write-Host "WinGet: $Id"
        & winget install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            Add-Failure "WinGet failed for $Id (exit code $LASTEXITCODE)."
            return $false
        }
        return $true
    } catch {
        Add-Failure "WinGet exception for $Id :: $($_.Exception.Message)"
        return $false
    }
}

function Ensure-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$Id
    )
    if (Test-CommandExists $Command) {
        Write-Host "Already available: $Command"
        return $true
    }
    return Install-WingetExact $Id
}

Write-Host '============================================================' -ForegroundColor Green
Write-Host ' DEV ENVIRONMENT SETUP V4 - FINAL CONSOLIDATED BOOTSTRAP' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host "Log: $LogFile"
Write-Host 'V4 consolidates the successful ideas and lessons from V1, V2 and V3.'
Write-Host 'Operational configuration of databases/brokers remains intentionally manual.'

try {
    Write-Step 'Prerequisites'

    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        Add-Failure 'This script is intended for Windows x64.'
    }

    if (-not (Test-CommandExists 'winget')) {
        Add-Failure 'WinGet is required for package-managed components.'
    }

    if (-not (Test-CommandExists 'tar')) {
        Add-Failure 'Windows tar is required to extract the Kafka .tgz archive.'
    }

    Write-Step 'Base developer tools'
    Ensure-WingetPackage 'pwsh' 'Microsoft.PowerShell' | Out-Null
    Ensure-WingetPackage 'git' 'Git.Git' | Out-Null
    Ensure-WingetPackage 'gh' 'GitHub.cli' | Out-Null
    Ensure-WingetPackage 'node' 'OpenJS.NodeJS.LTS' | Out-Null
    Ensure-WingetPackage 'python' 'Python.Python.3.12' | Out-Null
    Ensure-WingetPackage 'mysql' 'MySQL.MySQL' | Out-Null
    Ensure-WingetPackage 'dbeaver' 'DBeaver.DBeaver.Community' | Out-Null
    Ensure-WingetPackage 'aws' 'Amazon.AWSCLI' | Out-Null
    Ensure-WingetPackage 'az' 'Microsoft.AzureCLI' | Out-Null
    Ensure-WingetPackage 'gcloud' 'Google.CloudSDK' | Out-Null
    Ensure-WingetPackage 'kubectl' 'Kubernetes.kubectl' | Out-Null
    Ensure-WingetPackage 'helm' 'Helm.Helm' | Out-Null
    Ensure-WingetPackage '7z' '7zip.7zip' | Out-Null

    Write-Step 'Java 8 / 11 / 17 / 21 / 25'
    $javaVersions = 8, 11, 17, 21, 25
    $javaPackageIds = @{
        8  = 'EclipseAdoptium.Temurin.8.JDK'
        11 = 'EclipseAdoptium.Temurin.11.JDK'
        17 = 'EclipseAdoptium.Temurin.17.JDK'
        21 = 'EclipseAdoptium.Temurin.21.JDK'
        25 = 'EclipseAdoptium.Temurin.25.JDK'
    }

    foreach ($version in $javaVersions) {
        $jdkRoots = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -ErrorAction SilentlyContinue
        $jdk = $jdkRoots | Where-Object { $_.Name -match "^jdk-$version(\.|-)" } | Sort-Object Name -Descending | Select-Object -First 1

        if (-not $jdk) {
            Write-Host "Java $version not found. Attempting WinGet installation..."
            Install-WingetExact $javaPackageIds[$version] | Out-Null
            $jdkRoots = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -ErrorAction SilentlyContinue
            $jdk = $jdkRoots | Where-Object { $_.Name -match "^jdk-$version(\.|-)" } | Sort-Object Name -Descending | Select-Object -First 1
        }

        if ($jdk) {
            Set-SystemVariable "JAVA_HOME_$version" $jdk.FullName
        } else {
            Add-Failure "Java $version was not found after installation attempt."
        }
    }

    # V2 exposed a real problem: multiple JDK bins on PATH can override JAVA_HOME.
    # V4 normalizes that situation and keeps Java 21 as the default command-line JDK.
    Remove-JavaBinsFromMachinePath
    $jdk21 = [Environment]::GetEnvironmentVariable('JAVA_HOME_21', 'Machine')
    if ($jdk21 -and (Test-Path (Join-Path $jdk21 'bin\java.exe'))) {
        Set-SystemVariable 'JAVA_HOME' $jdk21
        Add-SystemPath (Join-Path $jdk21 'bin')
    } else {
        Add-Failure 'Java 21 is unavailable; JAVA_HOME could not be set to the default.'
    }

    Write-Step 'Maven 3.9.16'
    $mavenVersion = '3.9.16'
    $mavenHome = "$DevTools\apache-maven-$mavenVersion"
    if (-not (Test-Path (Join-Path $mavenHome 'bin\mvn.cmd'))) {
        $zip = "$DevTools\apache-maven-$mavenVersion-bin.zip"
        if (Download-File "https://dlcdn.apache.org/maven/maven-3/$mavenVersion/binaries/apache-maven-$mavenVersion-bin.zip" $zip) {
            try { Expand-Archive -Path $zip -DestinationPath $DevTools -Force } catch { Add-Failure "Maven extraction failed: $($_.Exception.Message)" }
        }
    }
    if (Test-Path (Join-Path $mavenHome 'bin\mvn.cmd')) {
        Set-SystemVariable 'MAVEN_HOME' $mavenHome
        Add-SystemPath (Join-Path $mavenHome 'bin')
    } else { Add-Failure 'Maven was not installed correctly.' }

    Write-Step 'Gradle 9.7.1'
    $gradleVersion = '9.7.1'
    $gradleHome = "$DevTools\gradle-$gradleVersion"
    if (-not (Test-Path (Join-Path $gradleHome 'bin\gradle.bat'))) {
        $zip = "$DevTools\gradle-$gradleVersion-bin.zip"
        if (Download-File "https://services.gradle.org/distributions/gradle-$gradleVersion-bin.zip" $zip) {
            try { Expand-Archive -Path $zip -DestinationPath $DevTools -Force } catch { Add-Failure "Gradle extraction failed: $($_.Exception.Message)" }
        }
    }
    if (Test-Path (Join-Path $gradleHome 'bin\gradle.bat')) {
        Set-SystemVariable 'GRADLE_HOME' $gradleHome
        Add-SystemPath (Join-Path $gradleHome 'bin')
    } else { Add-Failure 'Gradle was not installed correctly.' }

    Write-Step 'PostgreSQL 18'
    $postgres = Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $postgres) {
        Install-WingetExact 'PostgreSQL.PostgreSQL.18' | Out-Null
        $postgres = Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    }
    if ($postgres) {
        Set-SystemVariable 'POSTGRES_HOME' $postgres.FullName
        Add-SystemPath (Join-Path $postgres.FullName 'bin')
    } else { Add-Failure 'PostgreSQL installation was not detected.' }

    Write-Step 'Erlang / OTP'
    $erlang = Get-ChildItem 'C:\Program Files' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'erl*' -or $_.Name -like 'Erlang OTP*' } |
        Select-Object -First 1
    if (-not $erlang) {
        Install-WingetExact 'Erlang.ErlangOTP' | Out-Null
        $erlang = Get-ChildItem 'C:\Program Files' -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'erl*' -or $_.Name -like 'Erlang OTP*' } |
            Select-Object -First 1
    }
    if ($erlang -and (Test-Path (Join-Path $erlang.FullName 'bin\erl.exe'))) {
        Set-SystemVariable 'ERLANG_HOME' $erlang.FullName
        Add-SystemPath (Join-Path $erlang.FullName 'bin')
    } else { Add-Failure 'Erlang/OTP was not detected.' }

    Write-Step 'RabbitMQ 4.3.5 - binaries only'
    $rabbit = Get-ChildItem 'C:\Program Files' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'rabbitmq_server-*' -or $_.Name -like 'rabbitmq_*' } |
        Select-Object -First 1
    if (-not $rabbit) {
        $rabbitVersion = '4.3.5'
        $zip = "$DevTools\rabbitmq-server-windows-$rabbitVersion.zip"
        if (Download-File "https://github.com/rabbitmq/rabbitmq-server/releases/download/v$rabbitVersion/rabbitmq-server-windows-$rabbitVersion.zip" $zip) {
            try {
                Expand-Archive -Path $zip -DestinationPath 'C:\Program Files' -Force
                $rabbit = Get-ChildItem 'C:\Program Files' -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like 'rabbitmq_server-*' -or $_.Name -like 'rabbitmq_*' } |
                    Select-Object -First 1
            } catch { Add-Failure "RabbitMQ extraction failed: $($_.Exception.Message)" }
        }
    }
    if ($rabbit) {
        Set-SystemVariable 'RABBITMQ_SERVER' $rabbit.FullName
        Add-SystemPath (Join-Path $rabbit.FullName 'sbin')
    } else { Add-Failure 'RabbitMQ was not detected.' }

    Write-Step 'Kafka 4.3.1 - binaries only'
    $kafkaBase = "$DevTools\Kafka"
    New-Item -ItemType Directory -Force -Path $kafkaBase | Out-Null
    $kafkaVersion = '4.3.1'
    $kafkaArchive = "$kafkaBase\kafka_2.13-$kafkaVersion.tgz"
    $kafkaRoot = Get-ChildItem $kafkaBase -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'kafka_*' } | Select-Object -First 1
    if (-not $kafkaRoot) {
        if (Download-File "https://downloads.apache.org/kafka/$kafkaVersion/kafka_2.13-$kafkaVersion.tgz" $kafkaArchive) {
            try {
                & tar -xzf $kafkaArchive -C $kafkaBase
                if ($LASTEXITCODE -ne 0) { throw "tar exited with code $LASTEXITCODE" }
                $kafkaRoot = Get-ChildItem $kafkaBase -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like 'kafka_*' } | Select-Object -First 1
            } catch { Add-Failure "Kafka extraction failed: $($_.Exception.Message)" }
        }
    }
    if ($kafkaRoot) {
        Set-SystemVariable 'KAFKA_HOME' $kafkaRoot.FullName
        Add-SystemPath (Join-Path $kafkaRoot.FullName 'bin\windows')
    } else { Add-Failure 'Kafka was not detected.' }

    Write-Step 'Common PATH normalization'
    foreach ($path in @(
        'C:\Program Files\Git\cmd',
        'C:\Program Files\GitHub CLI',
        'C:\Program Files\nodejs',
        'C:\Program Files\Python312',
        'C:\Program Files\MySQL\MySQL Server 8.4\bin',
        'C:\Program Files\DBeaver',
        'C:\Program Files\Amazon\AWSCLIV2',
        'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin',
        'C:\Program Files\Google\Cloud SDK\google-cloud-sdk\bin',
        'C:\Program Files\Kubernetes\bin',
        'C:\Program Files\7-Zip'
    )) { Add-SystemPath $path }

    Refresh-Environment

    Write-Step 'Validation'
    $commands = @(
        'java','javac','mvn','gradle','git','gh','node','npm','python',
        'mysql','psql','erl','rabbitmqctl','kafka-topics'
    )

    $validation = foreach ($cmd in $commands) {
        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($found) {
            Write-Host ("OK   {0} -> {1}" -f $cmd, $found.Source) -ForegroundColor Green
            [PSCustomObject]@{ Command = $cmd; Status = 'OK'; Path = $found.Source }
        } else {
            Write-Warning "MISS $cmd"
            [PSCustomObject]@{ Command = $cmd; Status = 'MISS'; Path = '' }
        }
    }

    Write-Step 'Java environment'
    foreach ($version in $javaVersions) {
        $home = [Environment]::GetEnvironmentVariable("JAVA_HOME_$version", 'Machine')
        if ($home) { Write-Host "Java $version -> $home" }
    }
    Write-Host "JAVA_HOME -> $([Environment]::GetEnvironmentVariable('JAVA_HOME','Machine'))"

    Write-Step 'Operational boundary reminder'
    Write-Host 'PostgreSQL: create/configure roles, passwords, databases and permissions manually.' -ForegroundColor Yellow
    Write-Host 'RabbitMQ: configure service, users, vhosts and plugins manually.' -ForegroundColor Yellow
    Write-Host 'Kafka: initialize KRaft storage, configure/start broker and create topics manually.' -ForegroundColor Yellow
    Write-Host 'Production concerns (secrets, persistence, firewall, monitoring, security) remain manual.' -ForegroundColor Yellow

    Write-Step 'Final result'
    if ($script:Failures.Count -eq 0) {
        Write-Host 'V4 completed without recorded installation failures.' -ForegroundColor Green
    } else {
        Write-Warning ("V4 completed with {0} recorded issue(s):" -f $script:Failures.Count)
        $script:Failures | ForEach-Object { Write-Warning " - $_" }
    }
    Write-Host "Log saved to: $LogFile"
    Write-Host 'IMPORTANT: close and reopen PowerShell after this script.' -ForegroundColor Yellow

} finally {
    Stop-Transcript | Out-Null
}
