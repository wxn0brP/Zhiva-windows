Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.Text = "Zhiva Installer"
$form.Size = New-Object System.Drawing.Size(400, 180)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true

$label = New-Object System.Windows.Forms.Label
$label.Text = "Click Start to begin installation."
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($label)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Style = "Continuous"
$progressBar.Size = New-Object System.Drawing.Size(340, 20)
$progressBar.Location = New-Object System.Drawing.Point(20, 50)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$form.Controls.Add($progressBar)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Start"
$startButton.Size = New-Object System.Drawing.Size(100, 30)
$startButton.Location = New-Object System.Drawing.Point(20, 80)
$form.Controls.Add($startButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close"
$closeButton.Size = New-Object System.Drawing.Size(100, 30)
$closeButton.Location = New-Object System.Drawing.Point(130, 80)
$closeButton.Enabled = $false
$closeButton.Add_Click({ $form.Close() })
$form.Controls.Add($closeButton)

$script:job = $null
$script:progress = 0
$LogFile = Join-Path $env:TEMP "zhiva-install.log"

$installScript = {
    function Get-FreshPath {
        $systemPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        $userPath   = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        return "$systemPath;$userPath"
    }

    $env:PATH = Get-FreshPath

    Start-Transcript -Path $using:LogFile -Append

    $ZhivaDir = "$env:USERPROFILE\.zhiva"
    Write-Host "[Z-WIN-0-01] Zhiva directory: $ZhivaDir"

    if (-not (Test-Path $ZhivaDir)) {
        Write-Host "[Z-WIN-0-02] Zhiva isn't alive. Installing..."
        $baseUrl = "https://raw.githubusercontent.com/wxn0brP/Zhiva-windows/HEAD/scripts/"

        try {
            $ErrorActionPreference = "Stop"
            irm "$baseUrl`1.deps.ps1" | iex
        } catch {
            throw "[Z-WIN-0-05] Dependencies setup failed: $_"
        }
        if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
            throw "[Z-WIN-0-06] Bun not found in PATH after deps setup."
        }
        $env:PATH = Get-FreshPath

        try {
            $ErrorActionPreference = "Stop"
            irm "$baseUrl`2.base.ps1" | iex
        } catch {
            throw "[Z-WIN-0-07] Base setup failed: $_"
        }

        try {
            $ErrorActionPreference = "Stop"
            irm "$baseUrl`3.path.ps1" | iex
        } catch {
            throw "[Z-WIN-0-08] PATH setup failed: $_"
        }
        $env:PATH = Get-FreshPath

        try {
            $ErrorActionPreference = "Stop"
            irm "$baseUrl`4.protocol.ps1" | iex
        } catch {
            throw "[Z-WIN-0-09] Protocol setup failed: $_"
        }
    }

    $env:PATH = Get-FreshPath

    Write-Host "[Z-WIN-0-03] Zhiva is alive."
    $ZhivaCmd = "$ZhivaDir\bin\zhiva.cmd"
    Start-Process $ZhivaCmd -ArgumentList "self" -Wait
    Start-Process $ZhivaCmd -ArgumentList "install", "%%name%%" -Wait
    Write-Host "[Z-WIN-0-04] Zhiva app installed."

    Stop-Transcript
}

$progressTimer = New-Object System.Windows.Forms.Timer
$progressTimer.Interval = 2000

$progressTimer.Add_Tick({
    $job = Get-Job -Id $script:job.Id -ErrorAction SilentlyContinue
    if ($job -and $job.State -eq "Running") {
        if ($script:progress -lt 90) {
            $script:progress++
            $progressBar.Value = $script:progress
        }
    } else {
        $progressBar.Value = 100
        $progressTimer.Stop()

        if ($job.State -eq "Failed") {
            $err = Receive-Job $job -ErrorAction SilentlyContinue
            $errMsg = if ($err -is [System.Management.Automation.ErrorRecord]) { $err.Exception.Message } else { "$err" }
            $label.Text = "Failed: $errMsg"
            $label.ForeColor = [System.Drawing.Color]::Red
        } else {
            $label.Text = "Installation complete!"
        }
        $closeButton.Enabled = $true
    }
})

$startButton.Add_Click({
    $startButton.Enabled = $false
    $label.Text = "Installing..."
    
    $script:job = Start-Job -ScriptBlock $installScript
    $script:progress = 0
    $progressBar.Value = 0

    $progressTimer.Start()
})

$form.ShowDialog() | Out-Null

if ($script:job) {
    Remove-Job $script:job -Force -ErrorAction SilentlyContinue
}
$progressTimer.Dispose()