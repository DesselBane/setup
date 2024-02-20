function ReloadPathEnvironment {
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Write-Host "Bootstraping Windows, hold on to your socks"

$tempDir = Join-Path $([System.IO.Path]::GetTempPath()) $([System.Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir

try {
  Set-Location $tempDir

  Write-Host "Checking for WinGet"
  $wingetVersion = winget -v

  if (-not $wingetVersion.StartsWith("v")) {
    Write-Host "Did not find Winget. Installing..."

    Invoke-WebRequest -Uri https://github.com/microsoft/winget-cli/releases/download/v1.6.3482/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle -OutFile winget-setup.msixbundle

    & ./winget-setup.msixbundle
  }

  $wingetVersion = winget -v

  if (-not $wingetVersion.StartsWith("v")) {
    Write-Host "Winget installation failed. Exiting..."

    Return -1
  }

  Write-Host "Installing Git"
  winget install Git.Git --accept-package-agreements --accept-source-agreements

  Write-Host "Cloning repo"
  git clone https://github.com/DesselBane/setup.git
  Set-Location setup

  Write-Host "Installing InteractiveMenu"
  Install-Module InteractiveMenu

  Write-Host "Importing Module DarkSetup"
  Import-Module .\DarkSetup.psm1

  Write-Host "Running Setup"
  SetupFromConfig .\program.config.json
}
finally {
  Write-Host "Removing temp dir: $tempDir"
  Set-Location ~
  Remove-Item -Path $tempDir -Recurse -Force
}
