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
    $prepareScriptUrl = "https://raw.githubusercontent.com/wxn0brP/Zhiva/HEAD/install/prepare.ps1"
    $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"

    try {
        Write-Host "[Z-WIN-0-01] Retrieving the installation script..."
        Invoke-RestMethod -Uri $prepareScriptUrl -OutFile $tempScript
        Write-Host "[Z-WIN-0-02] Trying to run prepare.ps1..."

        for ($i = 1; $i -le 3; $i++) {
            $env:PATH = Get-FreshPath
            Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -Wait
            Write-Host ""
            Write-Host "Press Enter to continue..."
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
Write-Host ""
Write-Host "Press Enter to continue..."

$ZhivaCmd = "$ZhivaDir\bin\zhiva.cmd"

Write-Host "[Z-WIN-0-07] Running zhiva install..."
$env:PATH = Get-FreshPath
Start-Process $ZhivaCmd -ArgumentList "self" -Wait
Start-Process $ZhivaCmd -ArgumentList "install", "%%name%%" -Wait

Write-Host "[Z-WIN-0-08] Done."
Stop-Transcript