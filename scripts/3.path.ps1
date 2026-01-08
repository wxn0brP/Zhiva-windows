Write-Host "[Z-WIN-3-01] Adding Zhiva to PATH."

if (-not ("Win32.NativeMethods" -as [Type])) {
    Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
}

function Publish-Env {
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x1a
    $result = [UIntPtr]::Zero
    [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE,
        [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result) | Out-Null
}

function Write-Env {
    param([String]$Key, [String]$Value)
    $RegisterKey = Get-Item -Path 'HKCU:'
    $EnvRegisterKey = $RegisterKey.OpenSubKey('Environment', $true)
    if ($null -eq $Value) {
        $EnvRegisterKey.DeleteValue($Key)
    } else {
        $RegistryValueKind = if ($Value.Contains('%')) {
            [Microsoft.Win32.RegistryValueKind]::ExpandString
        } elseif ($EnvRegisterKey.GetValue($Key)) {
            $EnvRegisterKey.GetValueKind($Key)
        } else {
            [Microsoft.Win32.RegistryValueKind]::String
        }
        $EnvRegisterKey.SetValue($Key, $Value, $RegistryValueKind)
    }
    Publish-Env
}

function Get-Env {
    param([String]$Key)
    $RegisterKey = Get-Item -Path 'HKCU:'
    $EnvRegisterKey = $RegisterKey.OpenSubKey('Environment')
    $EnvRegisterKey.GetValue($Key, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
}

Write-Host "[Z-WIN-3-02] Adding Zhiva to PATH via registry and current session."

$currentPathFromRegistry = Get-Env -Key "PATH"
$zhivaBinPath = Join-Path $HOME ".zhiva" "bin"
$zhivaBinPathNormalized = $zhivaBinPath.TrimEnd('\')

$pathArray = @()
if ($currentPathFromRegistry) {
    $pathArray = $currentPathFromRegistry -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $zhivaBinPathNormalized }
}
$updatedPathValue = ($pathArray + @($zhivaBinPathNormalized)) -join ';'

Write-Env -Key "PATH" -Value $updatedPathValue
$env:PATH = $updatedPathValue

Write-Host "[Z-WIN-3-03] Added to user PATH: $zhivaBinPath"