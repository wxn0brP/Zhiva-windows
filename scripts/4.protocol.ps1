Write-Host "[Z-WIN-4-01] Installing Zhiva protocol..."

$protocol = "zhiva"
$zhivaExe = Join-Path $HOME ".zhiva" "bin" "zhiva.cmd"

New-Item "HKCU:\Software\Classes\$protocol" -Force | Out-Null
New-ItemProperty "HKCU:\Software\Classes\$protocol" -Name "URL Protocol" -Value "" -Force | Out-Null
New-Item "HKCU:\Software\Classes\$protocol\shell\open\command" -Force | Out-Null
Set-ItemProperty "HKCU:\Software\Classes\$protocol\shell\open\command" -Name "(default)" -Value "`"$zhivaExe`" protocol `"%1`"" -Force

Write-Host "[Z-WIN-4-02] Zhiva protocol installed."