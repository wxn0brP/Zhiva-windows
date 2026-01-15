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
    irm https://bun.sh/install.ps1 | iex
} else {
    Write-Output "[Z-WIN-1-06] Bun is already installed."
}

Write-Output "[Z-WIN-1-07] Dependencies are installed."