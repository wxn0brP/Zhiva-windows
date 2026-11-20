$LogFile = Join-Path $env:TEMP "zhiva-install.log"

function Write-Log($Message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host $Message
}

function Get-FreshPath {
    $systemPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath   = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    return "$systemPath;$userPath"
}

try {
    $ErrorActionPreference = "Continue"
    $env:PATH = Get-FreshPath

    $ZhivaDir = "$env:USERPROFILE\.zhiva"
    Write-Log "[Z-WIN-0-01] Zhiva directory: $ZhivaDir"

    $AppName = "%%name%%"
    if ([string]::IsNullOrWhiteSpace($AppName) -or $AppName.Contains("%%")) {
        $AppName = "Zhiva-store-app"
    }

    if (-not (Test-Path $ZhivaDir)) {
        Write-Log "[Z-WIN-0-02] Zhiva isn't alive. Installing..."

        # Step 1: Dependencies
        Write-Log "[Z-WIN-1-01] Checking Git..."
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Log "[Z-WIN-1-01] Git is not installed. Resolving latest version..."
            $release = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest"
            $asset = $release.assets | Where-Object { $_.name -match '64-bit\.exe$' } | Select-Object -First 1
            if (-not $asset) { throw "Git installer not found in latest release assets." }
            $installerPath = "$env:TEMP\$($asset.name)"
            Write-Log "[Z-WIN-1-02] Downloading $($asset.name)..."
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath
            Write-Log "[Z-WIN-1-03] Installing Git silently..."
            Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT /NORESTART" -Wait
            Remove-Item $installerPath -Force
        } else {
            Write-Log "[Z-WIN-1-04] Git is already installed."
        }

        Write-Log "[Z-WIN-1-05] Checking Bun..."
        if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
            Write-Log "[Z-WIN-1-05] Bun is not installed. Installing..."
            $bunInstallScript = "$env:TEMP\bun-install.ps1"
            Invoke-RestMethod https://bun.sh/install.ps1 -OutFile $bunInstallScript -Headers @{"Cache-Control"="no-cache"}
            cmd /c "powershell -ExecutionPolicy Bypass -File `"$bunInstallScript`" 2>&1"
            Remove-Item $bunInstallScript -Force -ErrorAction SilentlyContinue
        } else {
            Write-Log "[Z-WIN-1-06] Bun is already installed."
        }
        Write-Log "[Z-WIN-1-07] Dependencies are installed."

        $env:PATH = Get-FreshPath
        $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
        if ((Test-Path (Join-Path $bunBin "bun.exe")) -and -not (($env:PATH -split ';') | Where-Object { $_.TrimEnd('\') -eq $bunBin.TrimEnd('\') })) {
            $env:PATH = "$env:PATH;$bunBin"
        }

        if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
            throw "[Z-WIN-0-06] Bun not found in PATH after deps setup."
        }

        # Step 2: Base setup
        Write-Log "[Z-WIN-2-01] Setting up base..."
        $zhivaPath = Join-Path $HOME ".zhiva"
        $zhivaBinPath = Join-Path $zhivaPath "bin"
        $zhivaScriptsPath = Join-Path $zhivaPath "scripts"

        New-Item -ItemType Directory -Path $zhivaBinPath -Force | Out-Null
        Write-Log "[Z-WIN-2-01] Bin folder created."

        if (-not (Test-Path $zhivaScriptsPath)) {
            cmd /c "git clone https://github.com/wxn0brP/Zhiva-scripts.git `"$zhivaScriptsPath`" 2>&1"
        } else {
            cmd /c "git -C `"$zhivaScriptsPath`" pull 2>&1"
        }
        Write-Log "[Z-WIN-2-02] Zhiva-scripts cloned."

        Copy-Item -Path (Join-Path $zhivaScriptsPath "package.json") -Destination (Join-Path $zhivaPath "package.json") -Force
        Set-Location $zhivaPath
        cmd /c "bun install --production --force 2>&1"
        cmd /c "bun run scripts/src/cli.ts self 2>&1"
        Write-Log "[Z-WIN-2-03] Zhiva-scripts is installed."

        $cmdContent = @"
@echo off
bun run "%USERPROFILE%\.zhiva\scripts\src\cli.ts" %*
"@

        $cmdContent | Set-Content -Path (Join-Path $zhivaBinPath "zhiva.cmd") -Force

        # Step 3: PATH setup
        Write-Log "[Z-WIN-3-01] Adding Zhiva to PATH."

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

        Write-Log "[Z-WIN-3-02] Adding Zhiva to PATH via registry and current session."

        $currentPathFromRegistry = Get-Env -Key "PATH"
        $zhivaBinPath = Join-Path (Join-Path $HOME ".zhiva") "bin"
        $zhivaBinPathNormalized = $zhivaBinPath.TrimEnd('\')

        $pathArray = @()
        if ($currentPathFromRegistry) {
            $pathArray = $currentPathFromRegistry -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $zhivaBinPathNormalized }
        }
        $updatedPathValue = ($pathArray + @($zhivaBinPathNormalized)) -join ';'

        Write-Env -Key "PATH" -Value $updatedPathValue
        $env:PATH = $updatedPathValue

        Write-Log "[Z-WIN-3-03] Added to user PATH: $zhivaBinPath"

        # Step 4: Protocol setup
        Write-Log "[Z-WIN-4-01] Installing Zhiva protocol..."

        $protocol = "zhiva"
        $zhivaExe = Join-Path (Join-Path (Join-Path $HOME ".zhiva") "bin") "zhiva.cmd"

        New-Item "HKCU:\Software\Classes\$protocol" -Force | Out-Null
        New-ItemProperty "HKCU:\Software\Classes\$protocol" -Name "URL Protocol" -Value "" -Force | Out-Null
        New-Item "HKCU:\Software\Classes\$protocol\shell\open\command" -Force | Out-Null
        Set-ItemProperty "HKCU:\Software\Classes\$protocol\shell\open\command" -Name "(default)" -Value "`"$zhivaExe`" protocol `"%1`"" -Force

        Write-Log "[Z-WIN-4-02] Zhiva protocol installed."
    }

    $env:PATH = Get-FreshPath

    $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
    $pathParts = $env:PATH -split ';' | Where-Object { $_ }
    if ((Test-Path $bunBin) -and -not ($pathParts | Where-Object { $_.TrimEnd('\') -eq $bunBin.TrimEnd('\') })) {
        $env:PATH = "$env:PATH;$bunBin"
        Write-Log "[Z-WIN-3-04] Added Bun to PATH for this session."
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is not installed or not in PATH. Install Git for Windows and run the installer again."
    }
    if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
        throw "Bun is not installed or not in PATH. Install Bun from https://bun.sh and run the installer again."
    }

    Write-Log "[Z-WIN-0-03] Zhiva is alive."
    $ZhivaCmd = "$ZhivaDir\bin\zhiva.cmd"
    if (-not (Test-Path $ZhivaCmd)) {
        throw "The Zhiva launcher is missing: $ZhivaCmd. Re-run the installer."
    }

    $selfProc = Start-Process cmd.exe -ArgumentList "/c", "`"$ZhivaCmd`" self" -Wait -PassThru
    if ($selfProc.ExitCode -ne 0) {
        throw "Updating Zhiva failed with exit code $($selfProc.ExitCode). Log: $LogFile"
    }

    $appInstallOutput = Join-Path $env:TEMP "zhiva-app-install.log"
    Remove-Item $appInstallOutput -Force -ErrorAction SilentlyContinue
    $installProc = Start-Process cmd.exe -ArgumentList "/c", "`"$ZhivaCmd`" install `"$AppName`" > `"$appInstallOutput`" 2>&1" -Wait -PassThru
    if ($installProc.ExitCode -ne 0) {
        if (Test-Path $appInstallOutput) {
            Get-Content $appInstallOutput | ForEach-Object { Write-Log "[Z-WIN-APP-OUTPUT] $_" }
        }
        throw "Installing $AppName failed with exit code $($installProc.ExitCode). Log: $LogFile"
    }
    Write-Log "[Z-WIN-0-04] Zhiva app installed."
    
    $successBanner = @"

============================================================
============================================================
============================================================

   ███████╗██╗   ██╗ ██████╗ ██████╗███████╗███████╗███████╗
   ██╔════╝██║   ██║██╔════╝██╔════╝██╔════╝██╔════╝██╔════╝
   ███████╗██║   ██║██║     ██║     █████╗  ███████╗███████╗
   ╚════██║██║   ██║██║     ██║     ██╔══╝  ╚════██║╚════██║
   ███████║╚██████╔╝╚██████╗╚██████╗███████╗███████║███████║
   ╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝╚══════╝╚══════╝╚══════╝
                                                              

============================================================
============================================================
============================================================

"@
    Write-Log $successBanner

} catch {
    Write-Log "[Z-WIN-ERROR] $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Installation failed. Full log: $LogFile" -ForegroundColor Red
}

Read-Host "Press Enter to exit"
