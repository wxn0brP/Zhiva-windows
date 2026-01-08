if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Output "[Z-WIN-1-01] Git is not installed. Installing..."
    winget install --id Git.Git -e --silent --scope user
} else {
    Write-Output "[Z-WIN-1-02] Git is already installed."
}

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Output "[Z-WIN-1-03] Bun is not installed. Installing..."
    winget install --id Oven-sh.Bun -e --silent --scope user
} else {
    Write-Output "[Z-WIN-1-04] Bun is already installed."
}

Write-Output "[Z-WIN-1-05] Dependencies are installed."