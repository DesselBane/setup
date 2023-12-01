function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

function Write-TimeStamped {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [string]
        $message
    )

    Write-Output "$( Get-TimeStamp ) $message"
}

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string]$name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

function Install-WSLScheduledTask {
    $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument '/c echo "Starting WSL..." & wsl "exit"'
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$(whoami)"
    $settings = New-ScheduledTaskSettingsSet
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings
    Register-ScheduledTask -TaskName 'Start WSL (for linux docker)' -InputObject $task
}
Export-ModuleMember -Function Install-WSLScheduledTask

function Install-DockerWindows {
    #Requires -RunAsAdministrator

    $dockerForWindowsUrl = "https://download.docker.com/win/static/stable/x86_64/docker-24.0.7.zip"
    $dockerTempPath = Join-Path (New-TemporaryDirectory) "docker.zip"

    $ConfirmPreference = "None"

    Write-TimeStamped "Downloading Docker for Windows into $dockerTempPath"
    Invoke-WebRequest -Uri $dockerForWindowsUrl -OutFile $dockerTempPath

    Write-TimeStamped "Extracting docker files into C:\"
    Expand-Archive $dockerTempPath -DestinationPath C:\

    Write-TimeStamped "Removing temp file"
    Remove-Item $dockerTempPath -Recurse -Force

    Write-TimeStamped "Adding docker to Path"
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\docker", [System.EnvironmentVariableTarget]::Machine)
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

    Write-TimeStamped "Registering docker service"
    dockerd --register-service

    Write-TimeStamped "Starting docker service"
    Start-Service docker
    docker version

    Write-TimeStamped "Configuring docker to be exposed on tcp://127.0.0.1:2374"
    "{ `"hosts`": [`"tcp://127.0.0.1:2374`"], `"api-cors-header`": `"*`" }" | Out-File "C:\ProgramData\docker\config\daemon.json"
    Restart-Service docker

    Install-WSLScheduledTask
}
Export-ModuleMember -Function Install-DockerWindows
function Install-DockerLinux {
    try {
        wsl --set-default-version 2
        wsl --status
        Write-TimeStamped "Verified that WSL exists and is set to version 2"
    }
    catch {
        Write-TimeStamped "Windows Subsystem for Linux (WSL) is not installed."
        $installWsl = Read-Host "You need to activate WSL in order to continue. Do you want to install WSL now? [y/n]"

        if ($installWsl.ToLower() -eq 'y') {
            Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -NoRestart:$False
            Write-TimeStamped "Please restart you system. Afterwards rerun this script."
            Pause
            return 1
        }
        else {
            Write-Error "Cannot continue without WSL, exiting." -ErrorAction Stop
            return 2
        }
    }

    $isUbuntuInstalled = ((wsl --list) -like "ubuntu*").Count -gt 0

    if ($isUbuntuInstalled) {
        Write-TimeStamped "Ubuntu is already installed, skipping install step."
    }
    else {
        Write-TimeStamped "Installing Ubuntu WSL distro."
        wsl --install -d Ubuntu
        Write-TimeStamped "Please follow the instructions in the new terminal window to complete the setup. Once the installation is complete continue this script."
        Pause

        $isUbuntuInstalled = ((wsl --list) -like "ubuntu*").Count -gt 0

        if (-not $isUbuntuInstalled) {
            Write-Error "Ubuntu installation failed. Please install ubuntu manually, then rerun this script."
        }
    }

    $distro = "Ubuntu"


    Write-TimeStamped "TODO setup systemd"
    # https://devblogs.microsoft.com/commandline/systemd-support-is-now-available-in-wsl/
    # https://askubuntu.com/questions/1192347/temporary-failure-in-name-resolution-on-wsl
    #wsl -d $distro -u root curl -L -O "https://raw.githubusercontent.com/nullpo-head/wsl-distrod/v0.1.4/install.sh"
    #wsl -d $distro -u root chmod +x install.sh
    #wsl -d $distro -u root ./install.sh install
    #wsl -d $distro -u root /opt/distrod/bin/distrod enable
    #wsl --terminate $distro

    Write-TimeStamped "Installing docker inside WSL"
    wsl -d $distro -u root apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    wsl -d $distro -u root curl -fsSL https://download.docker.com/linux/ubuntu/gpg `| gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    wsl -d $distro -u root echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu `$( lsb_release -cs ) stable" `| tee /etc/apt/sources.list.d/docker.list `> /dev/null
    wsl -d $distro -u root apt-get update
    wsl -d $distro -u root apt-get install -y docker-ce docker-ce-cli containerd.io
    wsl -d $distro -u root docker version

    Write-TimeStamped "Configure docker to run on startup"
    wsl -d $distro -u root systemctl enable docker.service
    wsl -d $distro -u root systemctl enable containerd.service

    Write-TimeStamped "Configuring docker to be exposed on tcp://127.0.0.1:2375"
    wsl -d $distro -u root cp /lib/systemd/system/docker.service /etc/systemd/system/
    wsl -d $distro -u root sed -i 's/\ -H\ fd:\/\//\ -H\ fd:\/\/\ -H\ tcp:\/\/127.0.0.1:2375 --api-cors-header */g' /etc/systemd/system/docker.service
    wsl -d $distro -u root systemctl daemon-reload
    Start-Sleep -Seconds 1
    wsl -d $distro -u root systemctl restart docker.service
}
Export-ModuleMember -Function Install-DockerLinux
