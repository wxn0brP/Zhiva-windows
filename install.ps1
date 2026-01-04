$LogFile = "$env:TEMP\zhiva-app-install.log"
Start-Transcript -Path $LogFile -Append -Force

$ZhivaDir = "$env:USERPROFILE\.zhiva"

if (-not (Test-Path $ZhivaDir)) {
    Write-Host "[Z-WIN-0-01] .zhiva folder missing. Downloading bootstrap..."
    irm https://raw.githubusercontent.com/wxn0brP/Zhiva/HEAD/install/prepare.ps1 | iex
}

$ZhivaCmd = "$ZhivaDir\bin\zhiva.cmd"

Write-Host "[Z-WIN-0-02] Running zhiva install..."
Start-Process $ZhivaCmd -ArgumentList "self" -Wait
Start-Process $ZhivaCmd -ArgumentList "install", "%%name%%" -Wait

Write-Host "[Z-WIN-0-03] Done."
Stop-Transcript