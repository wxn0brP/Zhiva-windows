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

function Get-FreshPath {
    $systemPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath   = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    return "$systemPath;$userPath"
}

$LogDir  = "$env:USERPROFILE\.zhiva\logs"
$LogFile = "$LogDir\install.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$installScript = {
    $env:PATH = Get-FreshPath

    Start-Transcript -Path $using:LogFile -Append

    try {
        $ZhivaDir = "$env:USERPROFILE\.zhiva"

        if (-not (Test-Path $ZhivaDir)) {
            $baseUrl = "https://raw.githubusercontent.com/wxn0brP/Zhiva-windows/HEAD/scripts/"

            irm "$baseUrl`1.deps.ps1" | iex
            $env:PATH = Get-FreshPath

            irm "$baseUrl`2.base.ps1" | iex
            irm "$baseUrl`3.path.ps1" | iex
            $env:PATH = Get-FreshPath

            irm "$baseUrl`4.protocol.ps1" | iex
        }

        $env:PATH = Get-FreshPath

        $ZhivaCmd = "$ZhivaDir\bin\zhiva.cmd"
        Start-Process $ZhivaCmd -ArgumentList "self" -Wait
        Start-Process $ZhivaCmd -ArgumentList "install", "%%name%%" -Wait
    }
    finally {
        Stop-Transcript
    }
}

$progressTimer = New-Object System.Windows.Forms.Timer
$progressTimer.Interval = 2000

$progressTimer.Add_Tick({
    if ($script:job -and (Get-Job -Id $script:job.Id -ErrorAction SilentlyContinue).State -eq "Running") {
        if ($script:progress -lt 90) {
            $script:progress++
            $progressBar.Value = $script:progress
        }
    } else {
        $progressBar.Value = 100
        $label.Text = "Installation complete!"
        $closeButton.Enabled = $true
        $progressTimer.Stop()
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