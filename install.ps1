$LogFile = "$env:TEMP\zhiva-app-install.log"
Start-Transcript -Path $LogFile -Append -Force

$ZhivaDir = "$env:USERPROFILE\.zhiva"

if (-not (Test-Path $ZhivaDir)) {
    Write-Host "[Z-WIN-0-01] .zhiva folder missing. Running bootstrap..."

    $prepareScriptUrl = "https://raw.githubusercontent.com/wxn0brP/Zhiva/HEAD/install/prepare.ps1"
    $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"

    try {
        Invoke-RestMethod -Uri $prepareScriptUrl -OutFile $tempScript
        Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -Wait
    } catch {
        Write-Host "[Z-WIN-0-02] Failed to run prepare.ps1: $_"
    } finally {
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force
        }
    }

    Write-Host "[Z-WIN-0-03] Restarting script to apply changes..."
    Start-Process -FilePath $MyInvocation.MyCommand.Definition
    exit
}

$ZhivaCmd = "$ZhivaDir\bin\zhiva.cmd"

Write-Host "[Z-WIN-0-07] Running zhiva install..."
Start-Process $ZhivaCmd -ArgumentList "self" -Wait
Start-Process $ZhivaCmd -ArgumentList "install", "%%name%%" -Wait

Write-Host "[Z-WIN-0-08] Done."
Stop-Transcript