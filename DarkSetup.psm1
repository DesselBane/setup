Import-Module ps-menu

function Install-Font {
    param(
        [string]
        $fontDir
    )

    Write-Host "Installing fonts of folder $fontDir"
    $fonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
    Get-ChildItem $fontDir `
    | Where-Object { $_.Name -match "(t|o)tf$" } `
    | ForEach-Object { $fonts.CopyHere($_.FullName) }
    
}
Export-ModuleMember -Function Install-Font

function Install-Programm {
    param (
        [string]
        $programmId
    )
    winget install $programmId --accept-package-agreements --accept-source-agreements
}
Export-ModuleMember -Function Install-Programm

function Handle-Fonts {
    param(
        $configItem
    )
    $id = $configItem.Id


    for ($ii = 0; $ii -lt $configItem.Fonts.Length; $ii++) {
        $outFolder = "$id.$ii"
        $outName = "$outFolder.zip"

        Invoke-WebRequest $configItem.Fonts[$ii] -OutFile $outName
        Expand-Archive $outName
        Install-Font -fontDir $outFolder

        Remove-Item -Recurse -Force $outFolder
        Remove-Item -Force $outName
    }
}

function Handle-Profile {
    param (
        $configItem
    )

    if ($null -eq $configItem.PwshProfile) {
        return
    }

    $exists = [System.IO.File]::Exists($PROFILE)

    if ( -Not $exists) {
        Write-Host "Creating Pwsh Profile: $PROFILE"
        New-Item -Path $PROFILE -ItemType File -Force
    }

    foreach ($line in $configItem.PwshProfile) {
        $profileContainsText = Select-String -Path $PROFILE -Pattern "$line" -SimpleMatch

        if ($null -eq $profileContainsText) {
            Write-Host "Appending '$line' to pwsh profile"
            Add-Content -Path $PROFILE -Value $line
        }
        else {
            Write-Host "'$line' is already part of pwsh profile"
        }
    }
    
}

function SetupFromConfig {
    param (
        [string]
        $configPath
    )
    $config = Get-Content -Path $configPath | ConvertFrom-Json

    $menuChoices = $config | Select-Object -ExpandProperty Name
    $options = Menu $menuChoices -ReturnIndex -Multiselect 

    foreach ($i in $options) {
        $configItem = $config[$i]

        Install-Programm -programmId $configItem.Id

        Handle-Fonts -configItem $configItem
        Handle-Profile -configItem $configItem
    }
}
Export-ModuleMember -Function SetupFromConfig