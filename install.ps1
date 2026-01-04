$logFile = Join-Path $env:TEMP "zhiva-app-install.log"
function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    $logMessage | Tee-Object -FilePath $logFile -Append
    Write-Host $Message
}

$ZhivaFolder = Join-Path $env:USERPROFILE ".zhiva"

if (-not (Test-Path $ZhivaFolder)) {
    Write-Log "[Z-WIN-2-01] .zhiva folder does not exist. Downloading bootstrap..."
    
    $BootstrapUrl = "https://github.com/wxn0brP/Zhiva-windows/releases/download/native/zhiva-bootstrap.exe"
    $TempFile = Join-Path $env:TEMP "zhiva-bootstrap.exe"
    Write-Log "[Z-WIN-2-02] Bootstrap temp file: $TempFile"

    Invoke-WebRequest -Uri $BootstrapUrl -OutFile $TempFile

    Write-Log "[Z-WIN-2-03] Running bootstrap..."
    Start-Process -FilePath $TempFile -Wait
    Remove-Item $TempFile -Force
    $env:Path += ";$ZhivaFolder\bin"
}

Write-Log "[Z-WIN-2-04] Running zhiva install..."
Start-Process "zhiva install" -ArgumentList "%%name%%" -Wait

Write-Log "[Z-WIN-2-05] Done."
