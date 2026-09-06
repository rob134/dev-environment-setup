#requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host '=== DEV ENVIRONMENT SETUP V1 ===' -ForegroundColor Cyan
Write-Host 'Initial bootstrap based primarily on WinGet packages.'

function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)
    Write-Host "Installing $Id"
    winget install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements
}

# Initial package-based approach.
$packages = @(
    'Microsoft.PowerShell',
    'Git.Git',
    'GitHub.cli',
    'EclipseAdoptium.Temurin.8.JDK',
    'EclipseAdoptium.Temurin.11.JDK',
    'EclipseAdoptium.Temurin.17.JDK',
    'EclipseAdoptium.Temurin.21.JDK',
    'EclipseAdoptium.Temurin.25.JDK',
    'JetBrains.IntelliJIDEA.Ultimate',
    'Microsoft.VisualStudioCode',
    'OpenJS.NodeJS.LTS',
    'Python.Python.3.12',
    'MySQL.MySQL',
    'DBeaver.DBeaver.Community',
    'Amazon.AWSCLI',
    'Microsoft.AzureCLI',
    'Google.CloudSDK',
    'Kubernetes.kubectl',
    'Helm.Helm',
    '7zip.7zip',
    'Apache.Maven',
    'Gradle.Gradle',
    'PostgreSQL.PostgreSQL',
    'RabbitMQ.RabbitMQ',
    'Apache.Kafka'
)

foreach ($package in $packages) {
    Install-WingetPackage $package
}

Write-Host ''
Write-Host '=== V1 COMPLETE ===' -ForegroundColor Green
Write-Host 'Some packages may fail because WinGet package IDs can be unavailable or differ from the expected names.'
Write-Host 'V1 intentionally exposed those limitations so they could be addressed in later versions.'
Write-Host 'Restart PowerShell after installation.' -ForegroundColor Yellow
