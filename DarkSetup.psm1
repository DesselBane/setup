Import-Module InteractiveMenu

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

    foreach ($configItem in $options) {
        $configItem `
        | Handle-Winget `
        | Handle-Fonts `
        | Handle-EnvVars `
        | Out-Null

        Write-Host "Installed $($configItem.Name)"
    }
}
Export-ModuleMember -Function SetupFromConfig
