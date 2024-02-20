Import-Module InteractiveMenu

$choicesYesNo = '&Yes', '&No'


function SetupSSHForGit {
    if ($Host.UI.PromptForChoice("", 'Do you want to setup SSH for Git?', $choicesYesNo, 1) -ne 0) {
        return 0
    }

    Write-Host "Installing OpenSSH Client"
    Add-WindowsCapability -Online -Name OpenSSH.Client*

    Write-Host "Installing OpenSSH Server"
    Add-WindowsCapability -Online -Name OpenSSH.Server*

    Write-Host "Adding OpenSSH to Path"
    ReloadPathEnvironment
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Windows\System32\OpenSSH", [System.EnvironmentVariableTarget]::Machine)
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    ReloadPathEnvironment

    Write-Host "Setting up SSH-Agent"
    Get-Service ssh-agent | Set-Service -StartupType Automatic -PassThru | Start-Service

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

function SetupDotConfig {
    if ($Host.UI.PromptForChoice("", 'Do you want to setup dot config?', $choicesYesNo, 1) -ne 0) {
        return 0
    }

    git clone --bare git@github.com:DesselBane/config.git $env:USERPROFILE/.dotCfg
    git --git-dir=$env:USERPROFILE/.dotCfg --work-tree=$env:USERPROFILE checkout master -f
}

function Handle-Winget {
    param (
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
        $configItem
    )

    if ($null -eq $configItem.Winget) {
        return $configItem
    }

    winget install $configItem.Winget.Id --accept-package-agreements --accept-source-agreements

    return $configItem
}

function Handle-Fonts {
    param(
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
        $configItem
    )

    if ($null -eq $configItem.Fonts) {
        return $configItem
    }

    $id = $configItem.Id
    $fonts = (New-Object -ComObject Shell.Application).Namespace(0x14)


    for ($ii = 0; $ii -lt $configItem.Fonts.Length; $ii++) {
        $outFolder = "$id.$ii"
        $outName = "$outFolder.zip"

        Invoke-WebRequest $configItem.Fonts[$ii] -OutFile $outName
        Expand-Archive $outName

        Write-Host "Installing fonts of folder $outFolder"
        Get-ChildItem $outFolder `
        | Where-Object { $_.Name -match "(t|o)tf$" } `
        | ForEach-Object { $fonts.CopyHere($_.FullName) }

        Remove-Item -Recurse -Force $outFolder
        Remove-Item -Force $outName
    }

    return $configItem
}

function Handle-EnvVars {
    param (
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
        $configItem
    )

    if ($null -eq $configItem.EnvVars) {
        return $configItem
    }

    foreach ($item in $configItem.EnvVars.PSObject.Properties) {
        Write-Host "Setting user scoped environment variable '$($item.Name)' to value '$($item.Value)'"
        [System.Environment]::SetEnvironmentVariable($item.Name, $item.Value, [System.EnvironmentVariableTarget]::User)
    }

    return $configItem
}

function SetupFromConfig {
    param (
        [string]
        $configPath
    )
    $config = Get-Content -Path $configPath | ConvertFrom-Json

    $menuItems = $config | ForEach-Object { $i = 0 } {
        Get-InteractiveMultiMenuOption -Item $_ `
            -Label $_.Name `
            -Order $i `
            -Info $(ConvertTo-Json -InputObject $_ -Depth 10);
        $i++
    }

    $options = Get-InteractiveMenuUserSelection -Header "What should be installed?" -Items $menuItems

    Clear-Host

    foreach ($configItem in $options) {
        Write-Host "Installing package: $($configItem.Name)..."
        $configItem `
        | Handle-Winget `
        | Handle-Fonts `
        | Handle-EnvVars `
        | Out-Null

        Write-Host "Done Installing: $($configItem.Name)"
    }

    SetupSSHForGit
    SetupDotConfig
}
Export-ModuleMember -Function SetupFromConfig
