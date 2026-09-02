if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Output "[Z-WIN-1-01] Git is not installed. Resolving latest version..."

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest"

    $asset = $release.assets | Where-Object {
        $_.name -match '64-bit\.exe$'
    } | Select-Object -First 1

    if (-not $asset) {
        throw "Git installer not found in latest release assets."
    }

    $installerPath = "$env:TEMP\$($asset.name)"

    Write-Output "[Z-WIN-1-02] Downloading $($asset.name)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath

    Write-Output "[Z-WIN-1-03] Installing Git silently..."
    Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT /NORESTART" -Wait

    Remove-Item $installerPath -Force
} else {
    Write-Output "[Z-WIN-1-04] Git is already installed."
}

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Output "[Z-WIN-1-05] Bun is not installed. Installing..."
    try {
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = "Stop"
        irm https://bun.sh/install.ps1 | iex
        $ErrorActionPreference = $prevEAP
    } catch {
        $ErrorActionPreference = $prevEAP
        Write-Output "[Z-WIN-1-08] Official installer failed: $_"
        Write-Output "[Z-WIN-1-09] Trying manual install..."

        $bunRoot = if ($env:BUN_INSTALL) { $env:BUN_INSTALL } else { Join-Path $HOME ".bun" }
        $bunBin = Join-Path $bunRoot "bin"
        New-Item -ItemType Directory -Path $bunBin -Force | Out-Null

        $zipPath = Join-Path $bunBin "bun.zip"
        $url = "https://github.com/oven-sh/bun/releases/latest/download/bun-windows-x64.zip"

        try {
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $bunBin -Force
            $extracted = Join-Path $bunBin "bun-windows-x64"
            if (Test-Path (Join-Path $extracted "bun.exe")) {
                Copy-Item (Join-Path $extracted "bun.exe") -Destination $bunBin -Force
                Remove-Item $extracted -Recurse -Force -ErrorAction SilentlyContinue
            }
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        } catch {
            throw "Failed to install Bun manually: $_"
        }

        if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
            $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
            if ($userPath -notlike "*$bunBin*") {
                [System.Environment]::SetEnvironmentVariable("PATH", "$userPath;$bunBin", "User")
                $env:PATH = "$env:PATH;$bunBin"
            }
        }

        if (-not (Test-Path (Join-Path $bunBin "bun.exe"))) {
            throw "Bun installation failed - bun.exe not found in $bunBin"
        }
        Write-Output "[Z-WIN-1-10] Bun installed manually to $bunBin"
    }
} else {
    Write-Output "[Z-WIN-1-06] Bun is already installed."
}

Write-Output "[Z-WIN-1-07] Dependencies are installed."
