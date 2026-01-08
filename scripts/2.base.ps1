$zhivaPath = Join-Path $HOME ".zhiva"
$zhivaBinPath = Join-Path $zhivaPath "bin"
$zhivaScriptsPath = Join-Path $zhivaPath "scripts"

New-Item -ItemType Directory -Path $zhivaBinPath -Force | Out-Null
Write-Host "[Z-WIN-2-01] Bin folder created."

if (-not (Test-Path $zhivaScriptsPath)) {
    git clone https://github.com/wxn0brP/Zhiva-scripts.git $zhivaScriptsPath
} else {
    git -C $zhivaScriptsPath pull
}
Write-Host "[Z-WIN-2-02] Zhiva-scripts cloned."

Copy-Item -Path (Join-Path $zhivaScriptsPath "package.json") -Destination (Join-Path $zhivaPath "package.json") -Force
Set-Location $zhivaPath
bun install --production --force
bun run scripts/src/cli.ts self
Write-Host "[Z-WIN-2-03] Zhiva-scripts is installed."

$cmdContent = @"
@echo off

if defined _ZHIVA_BG_RUN (
    bun run "%USERPROFILE%\.zhiva\scripts\src\cli.ts" %*
    exit /b
)

if defined _ZHIVA_BG (
	set _ZHIVA_BG_RUN=1
	start "" /min cmd /c "%~f0" %*
    exit /b
)

bun run "%USERPROFILE%\.zhiva\scripts\src\cli.ts" %*
"@

$cmdContent | Set-Content -Path (Join-Path $zhivaBinPath "zhiva.cmd") -Force