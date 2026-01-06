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

$installScript = {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $ZhivaDir = "$env:USERPROFILE\.zhiva"

    if (-not (Test-Path $ZhivaDir)) {
        $prepareScriptUrl = "https://raw.githubusercontent.com/wxn0brP/Zhiva/HEAD/install/prepare.ps1"
        $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
        try {
            Invoke-RestMethod -Uri $prepareScriptUrl -OutFile $tempScript
            for ($i = 1; $i -le 3; $i++) {
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -Wait
            }
        } finally {
            if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
        }
    }

    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $ZhivaCmd = "$ZhivaDir\bin\zhiva.cmd"
    Start-Process $ZhivaCmd -ArgumentList "self" -Wait
    Start-Process $ZhivaCmd -ArgumentList "install", "%%name%%" -Wait
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