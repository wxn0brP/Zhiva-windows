$LogFile = "$env:TEMP\zhiva-app-install.log"
Start-Transcript -Path $LogFile -Append -Force

$ZhivaDir = "$env:USERPROFILE\.zhiva"

function Get-FreshPath {
    $systemPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath   = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    return "$systemPath;$userPath"
}

$env:PATH = Get-FreshPath

if (-not (Test-Path $ZhivaDir)) {
    Write-Host "=============================================="
    Write-Host "   Note: To complete the Zhiva system setup,"
    Write-Host "   it may be necessary to run"
    Write-Host "   this program 4-7 times."
    Write-Host "   The installation process will start now."
    Write-Host "=============================================="
    Write-Host ""
    Write-Host "Starting in 5 seconds..."
    Start-Sleep -Seconds 5

    $prepareScriptUrl = "https://raw.githubusercontent.com/wxn0brP/Zhiva/HEAD/install/prepare.ps1"
    $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"

    try {
        Write-Host "[Z-WIN-0-01] Retrieving the installation script..."
        Invoke-RestMethod -Uri $prepareScriptUrl -OutFile $tempScript

        for ($i = 1; $i -le 3; $i++) {
            Write-Host "[Z-WIN-0-02] Trying to run prepare.ps1..."
            
            $env:PATH = Get-FreshPath
            Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -Wait
            $env:PATH = Get-FreshPath
        }
    } catch {
        Write-Host "[Z-WIN-0-03] Failed to download or execute the installation script: $_"
    } finally {
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force
        }
    }

    $env:PATH = Get-FreshPath
}

$ZhivaCmd = "$ZhivaDir\bin\zhiva.cmd"

Write-Host "[Z-WIN-0-07] Running zhiva install..."
$env:PATH = Get-FreshPath
Start-Process $ZhivaCmd -ArgumentList "self" -Wait
Start-Process $ZhivaCmd -ArgumentList "install", "%%name%%" -Wait

Write-Host "[Z-WIN-0-08] Done."
Stop-Transcript