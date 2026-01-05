$LogFile = "$env:TEMP\zhiva-app-install.log"
Start-Transcript -Path $LogFile -Append -Force

$ZhivaDir = "$env:USERPROFILE\.zhiva"

if (-not (Test-Path $ZhivaDir)) {
    Write-Host "=============================================="
    Write-Host "ℹ️  Note: To complete the Zhiva system setup,"
    Write-Host "   it may be necessary to run"
    Write-Host "   this program 4-7 times."
    Write-Host "   The installation process will start now."
    Write-Host "=============================================="
    Write-Host ""

    $prepareScriptUrl = "https://raw.githubusercontent.com/wxn0brP/Zhiva/HEAD/install/prepare.ps1"
    $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"

    try {
        Write-Host "[Z-WIN-0-01] Retrieving the installation script..."
        Invoke-RestMethod -Uri $prepareScriptUrl -OutFile $tempScript

        for ($i = 1; $i -le 3; $i++) {
            Write-Host "[Z-WIN-0-02] Trying to run prepare.ps1 ($i/3)..."
            Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -Wait
        }
    } catch {
        Write-Host "[Z-WIN-0-03] Failed to download or execute the installation script: $_"
    } finally {
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force
        }
    }

    Write-Host "[Z-WIN-0-04] Program restart after 3 configuration attempts..."
    Start-Process -FilePath $MyInvocation.MyCommand.Definition
    exit
}

$ZhivaCmd = "$ZhivaDir\bin\zhiva.cmd"

Write-Host "[Z-WIN-0-07] Running zhiva install..."
Start-Process $ZhivaCmd -ArgumentList "self" -Wait
Start-Process $ZhivaCmd -ArgumentList "install", "%%name%%" -Wait

Write-Host "[Z-WIN-0-08] Done."
Stop-Transcript