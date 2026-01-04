$logFile = Join-Path $env:TEMP "zhiva-bootstrap.log"
function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    $logMessage | Tee-Object -FilePath $logFile -Append
    Write-Output $Message
}

$gitPath = Get-Command git -ErrorAction SilentlyContinue

if (-not $gitPath) {
    Write-Log "[Z-WIN-1-01] Git is not installed. Attempting installation via winget..."

    try {
        $wingetArgs = @("install", "--id", "Git.Git", "-e", "--silent", "--accept-source-agreements", "--accept-package-agreements")
        $wingetResult = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -ErrorAction Stop

        if ($wingetResult.ExitCode -ne 0) {
            Write-Log "[Z-WIN-1-02] Failed to install Git via winget. Exit code: $($wingetResult.ExitCode)"
            exit 1
        } else {
            Write-Log "[Z-WIN-1-03] Git installed successfully."
        }
    } catch {
        Write-Log "[Z-WIN-1-04] Exception while installing Git via winget: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Log "[Z-WIN-1-05] Git is already installed."
}

$userHome = [Environment]::GetFolderPath('UserProfile')
$zhivaPath = Join-Path $userHome ".zhiva"

if (-not (Test-Path -Path $zhivaPath -PathType Container)) {
    Write-Log "[Z-WIN-1-06] Folder .zhiva not found. Running remote preparation script..."

    try {
        irm https://raw.githubusercontent.com/wxn0brP/Zhiva/HEAD/install/prepare.ps1 | iex
        Write-Log "[Z-WIN-1-07] Remote script executed successfully."
    } catch {
        Write-Log "[Z-WIN-1-08] Error executing remote PowerShell script: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Log "[Z-WIN-1-09] Folder .zhiva already exists."
}

Start-Process (Join-Path (Join-Path $env:USERPROFILE ".zhiva\bin") "zhiva.cmd") -ArgumentList "self" -Wait

Write-Log "[Z-WIN-1-10] Setup completed successfully."