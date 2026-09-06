#requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$DevTools = 'C:\DevTools'
New-Item -ItemType Directory -Force -Path $DevTools | Out-Null

function Add-SystemPath {
    param([Parameter(Mandatory)][string]$PathToAdd)
    if (-not (Test-Path $PathToAdd)) { return }
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $entries = $machinePath -split ';' | Where-Object { $_ -and $_.Trim() }
    if ($entries -notcontains $PathToAdd) {
        [Environment]::SetEnvironmentVariable('Path', (($entries + $PathToAdd) -join ';'), 'Machine')
        Write-Host "PATH + $PathToAdd"
    }
}

function Set-SystemVariable {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value)
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Machine')
    Set-Item -Path "Env:$Name" -Value $Value
    Write-Host "$Name = $Value"
}

function Refresh-Environment {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
    foreach ($name in @('JAVA_HOME','JAVA_HOME_8','JAVA_HOME_11','JAVA_HOME_17','JAVA_HOME_21','JAVA_HOME_25','MAVEN_HOME','GRADLE_HOME','POSTGRES_HOME','ERLANG_HOME','RABBITMQ_SERVER','KAFKA_HOME')) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Machine')
        if ($null -ne $value) { Set-Item -Path "Env:$name" -Value $value }
    }
}

function Download-File {
    param([Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)][string]$Destination)
    if (Test-Path $Destination) { return }
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
}

function Install-WingetExact {
    param([Parameter(Mandatory)][string]$Id)
    Write-Host "Installing $Id"
    winget install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements
}

Write-Host '=== DEV ENVIRONMENT SETUP V3 ===' -ForegroundColor Cyan
Write-Host 'Automates installation and PATH setup; service/application configuration remains manual.'

# PowerShell 7
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Install-WingetExact 'Microsoft.PowerShell'
}

# Java 8/11/17/21/25
$jdkRoots = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -ErrorAction SilentlyContinue
$javaVersions = 8,11,17,21,25
foreach ($version in $javaVersions) {
    $jdk = $jdkRoots | Where-Object { $_.Name -match "^jdk-$version(\.|-)" } | Select-Object -First 1
    if ($jdk) {
        Set-SystemVariable "JAVA_HOME_$version" $jdk.FullName
    } else {
        Write-Warning "Java $version not found. Install Temurin JDK $version if required."
    }
}

$jdk21 = [Environment]::GetEnvironmentVariable('JAVA_HOME_21','Machine')
if ($jdk21) {
    Set-SystemVariable 'JAVA_HOME' $jdk21
    # Put only the default JDK on PATH to avoid java.exe resolving to another JDK.
    Add-SystemPath "$jdk21\bin"
}

# Maven
$mavenVersion = '3.9.16'
$mavenHome = "$DevTools\apache-maven-$mavenVersion"
if (-not (Test-Path (Join-Path $mavenHome 'bin\mvn.cmd'))) {
    $zip = "$DevTools\apache-maven-$mavenVersion-bin.zip"
    Download-File "https://dlcdn.apache.org/maven/maven-3/$mavenVersion/binaries/apache-maven-$mavenVersion-bin.zip" $zip
    Expand-Archive -Path $zip -DestinationPath $DevTools -Force
}
Set-SystemVariable 'MAVEN_HOME' $mavenHome
Add-SystemPath "$mavenHome\bin"

# Gradle
$gradleVersion = '9.7.1'
$gradleHome = "$DevTools\gradle-$gradleVersion"
if (-not (Test-Path (Join-Path $gradleHome 'bin\gradle.bat'))) {
    $zip = "$DevTools\gradle-$gradleVersion-bin.zip"
    Download-File "https://services.gradle.org/distributions/gradle-$gradleVersion-bin.zip" $zip
    Expand-Archive -Path $zip -DestinationPath $DevTools -Force
}
Set-SystemVariable 'GRADLE_HOME' $gradleHome
Add-SystemPath "$gradleHome\bin"

# PostgreSQL
$postgres = Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if (-not $postgres) {
    Install-WingetExact 'PostgreSQL.PostgreSQL.18'
    $postgres = Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
}
if ($postgres) {
    Set-SystemVariable 'POSTGRES_HOME' $postgres.FullName
    Add-SystemPath "$($postgres.FullName)\bin"
}

# Erlang
$erlang = Get-ChildItem 'C:\Program Files' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'erl*' -or $_.Name -like 'Erlang OTP*' } |
    Select-Object -First 1
if (-not $erlang) {
    Install-WingetExact 'Erlang.ErlangOTP'
    $erlang = Get-ChildItem 'C:\Program Files' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'erl*' -or $_.Name -like 'Erlang OTP*' } |
        Select-Object -First 1
}
if ($erlang -and (Test-Path (Join-Path $erlang.FullName 'bin\erl.exe'))) {
    Set-SystemVariable 'ERLANG_HOME' $erlang.FullName
    Add-SystemPath "$($erlang.FullName)\bin"
}

# RabbitMQ - binaries only; service setup is intentionally manual
$rabbit = Get-ChildItem 'C:\Program Files' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'rabbitmq_server-*' -or $_.Name -like 'rabbitmq_*' } |
    Select-Object -First 1
if (-not $rabbit) {
    $rabbitVersion = '4.3.5'
    $zip = "$DevTools\rabbitmq-server-windows-$rabbitVersion.zip"
    Download-File "https://github.com/rabbitmq/rabbitmq-server/releases/download/v$rabbitVersion/rabbitmq-server-windows-$rabbitVersion.zip" $zip
    Expand-Archive -Path $zip -DestinationPath 'C:\Program Files' -Force
    $rabbit = Get-ChildItem 'C:\Program Files' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'rabbitmq_server-*' -or $_.Name -like 'rabbitmq_*' } |
        Select-Object -First 1
}
if ($rabbit) {
    Set-SystemVariable 'RABBITMQ_SERVER' $rabbit.FullName
    Add-SystemPath "$($rabbit.FullName)\sbin"
}

# Kafka - binaries only; KRaft initialization and startup are intentionally manual
$kafkaBase = "$DevTools\Kafka"
New-Item -ItemType Directory -Force -Path $kafkaBase | Out-Null
$kafkaVersion = '4.3.1'
$kafkaArchive = "$kafkaBase\kafka_2.13-$kafkaVersion.tgz"
$kafkaRoot = Get-ChildItem $kafkaBase -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'kafka_*' } | Select-Object -First 1
if (-not $kafkaRoot) {
    Download-File "https://downloads.apache.org/kafka/$kafkaVersion/kafka_2.13-$kafkaVersion.tgz" $kafkaArchive
    # Windows 10/11 includes tar. It can extract gzip-compressed tar archives directly.
    & tar -xzf $kafkaArchive -C $kafkaBase
    $kafkaRoot = Get-ChildItem $kafkaBase -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'kafka_*' } | Select-Object -First 1
}
if ($kafkaRoot) {
    Set-SystemVariable 'KAFKA_HOME' $kafkaRoot.FullName
    Add-SystemPath "$($kafkaRoot.FullName)\bin\windows"
}

# Common tools
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

Write-Host ''
Write-Host '=== VALIDATION ===' -ForegroundColor Green
$commands = 'java','javac','mvn','gradle','git','gh','node','npm','python','mysql','psql','erl','rabbitmqctl','kafka-topics'
foreach ($cmd in $commands) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) { Write-Host "OK   $cmd -> $($found.Source)" }
    else { Write-Warning "MISS $cmd" }
}

Write-Host ''
Write-Host 'Java installations:' -ForegroundColor Yellow
foreach ($version in $javaVersions) {
    $home = [Environment]::GetEnvironmentVariable("JAVA_HOME_$version",'Machine')
    if ($home) { Write-Host "Java $version -> $home" }
}
Write-Host "JAVA_HOME -> $([Environment]::GetEnvironmentVariable('JAVA_HOME','Machine'))"
Write-Host ''
Write-Host 'IMPORTANT: reopen PowerShell after this script.' -ForegroundColor Yellow
Write-Host 'PostgreSQL, RabbitMQ and Kafka are installed/configured at binary/PATH level only.'
Write-Host 'Service creation, passwords, users, databases, RabbitMQ plugins and Kafka KRaft setup remain manual.'
