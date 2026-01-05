$LogFile = "$env:TEMP\zhiva-app-install.log"
Start-Transcript -Path $LogFile -Append -Force

$ZhivaDir = "$env:USERPROFILE\.zhiva"

if (-not (Test-Path $ZhivaDir)) {
    Write-Host "[Z-WIN-0-01] .zhiva folder missing. Bootstrapping..."
    irm https://raw.githubusercontent.com/wxn0brP/Zhiva/HEAD/install/prepare.ps1 | iex
    Write-Host "[Z-WIN-0-02] Restarting script..."
    Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Wait
    exit
}

$ZhivaCmd = "$ZhivaDir\bin\zhiva.cmd"

Write-Host "[Z-WIN-0-07] Running zhiva install..."
Start-Process $ZhivaCmd -ArgumentList "self" -Wait
Start-Process $ZhivaCmd -ArgumentList "install", "%%name%%" -Wait

Write-Host "[Z-WIN-0-08] Done."
Stop-Transcript