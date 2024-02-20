function ReloadPathEnvironment {
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function setupGit {
  Write-Host "Installing git"
  winget install Git.Git

  Write-Host "Installing OpenSSH Client"
  Add-WindowsCapability -Online -Name OpenSSH.Client*

  Write-Host "Installing OpenSSH Server"
  Add-WindowsCapability -Online -Name OpenSSH.Server*

  Write-Host "Adding OpenSSH to Path"
  [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Windows\System32\OpenSSH", [System.EnvironmentVariableTarget]::Machine)
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

  ReloadPathEnvironment

  Write-Host "Setting up SSH-Agent"
  Get-Service ssh-agent | Set-Service -StartupType Automatic -PassThru | Start-Service

  Write-Host "Starting SSH-AGent service"
  & start-ssh-agent.cmd

  Write-Host "Create git ssh folder"
  $gitSSHFolder = New-Item -ItemType Directory -Path ~/.ssh-git
  $gitSSHPrivateKeyPath = Join-Path $gitSSHFolder id_ed25519

  Write-Host "Creating SSH Key"
  ssh-keygen -t ed25519 -C "Git Key" -f  $gitSSHPrivateKeyPath

  $publicKey = Get-Content "$gitSSHPrivateKeyPath.pub"
  Write-Host "Public Key, you need to add this to your github/gitlab profile"
  Write-Host $publicKey

  Write-Host "Adding SSH Private Key to SSH-Agent"
  ssh-add $gitSSHPrivateKeyPath

  $secretsGitConfig = @"
[core]
  sshCommand = C:/Windows/System32/OpenSSH/ssh.exe
[user]
  signingKey = $gitSSHPrivateKeyPath
"@

  Write-Host "Saving secrets in home folder as secrets.gitconfig"
  Write-Output $secretsGitConfig > ~/secrets.gitconfig

  Write-Host ~/secrets.gitconfig
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


  setupGit

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
  Write-Host "Removing temp dir"
  Remove-Item -Path $tempDir -Recurse -Force
}
