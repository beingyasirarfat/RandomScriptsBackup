# backup-wsl.ps1
# Script by: @Yasir Arfat

# Load BurntToast module (used for toast notifications)
Import-Module BurntToast -ErrorAction SilentlyContinue

# Set up dynamic window title
$host.UI.RawUI.WindowTitle = "WSL Backup - Initializing"

Write-Host "====================================="
Write-Host " WSL Backup Utility - by @Yasir Arfat "
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Styled countdown with color change effect
for ($i = 10; $i -ge 1; $i--) {
    $color = if ($i % 2 -eq 0) { "Red" } else { "DarkRed" }
    Write-Host -NoNewline "`rStarting backup in $i seconds..." -ForegroundColor $color
    Start-Sleep -Seconds 1
}
Write-Host "`rStarting backup now...                          " -ForegroundColor Green
Start-Sleep -Seconds 1

# Define paths
$source = "C:\Linux\Distros\Ubuntu24\ext4.vhdx"
$destinationFolder = "D:\.Backup\WSL"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupFile = Join-Path $destinationFolder "ext4-backup-$timestamp.vhdx"
$logFile = Join-Path $destinationFolder "backup-log.txt"

# Make sure destination folder exists
if (-not (Test-Path $destinationFolder)) {
    New-Item -Path $destinationFolder -ItemType Directory | Out-Null
    Write-Host "Created backup directory at $destinationFolder" -ForegroundColor Yellow
}

# Update window title
$host.UI.RawUI.WindowTitle = "WSL Backup - Checking WSL State"

# Check if WSL is running
$wslRunning = Get-Process -Name "wsl" -ErrorAction SilentlyContinue

if ($wslRunning) {
    Write-Host "`nWARNING: WSL is running." -ForegroundColor Yellow
    Write-Host "Do you want to force shutdown WSL to continue the backup? (Y/N)" -ForegroundColor Red

    $response = $null
    $timeout = 10
    
    for ($remaining = $timeout; $remaining -ge 1; $remaining--) {
        Write-Host -NoNewline "`rAutomatically cancelling in $remaining seconds... " -ForegroundColor DarkYellow
    
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        while ($timer.Elapsed.TotalSeconds -lt 1) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true).Key
                if ($key -eq 'Y') { $response = 'Y'; break }
                elseif ($key -eq 'N') { $response = 'N'; break }
            }
            Start-Sleep -Milliseconds 100
        }
        if ($response) { break }
    }
    
    Write-Host ""  # clean up newline after countdown

    if (-not $response) {
        $host.UI.RawUI.WindowTitle = "WSL Active:Aborting..."
        $message = "WSL is currently running. Backup aborted to avoid corruption."

        # Toast & log
        New-BurntToastNotification -Text "WSL Backup Skipped", "WSL appears to be running."
        Add-Content -Path $logFile -Value "$(Get-Date): $message"

        Write-Host ""
        Write-Host "=========================================================" -ForegroundColor Yellow
        Write-Host " WSL is active. Backup has been safely skipped." -ForegroundColor Red
        Write-Host " Please close Ubuntu/WSL instances and rerun the backup." -ForegroundColor Yellow
        Write-Host "=========================================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host ""
        # Styled countdown with color change effect
        for ($i = 5; $i -ge 1; $i--) {
            $color = if ($i % 2 -eq 0) { "Red" } else { "DarkRed" }
            Write-Host -NoNewline "`rClosing window in...$i" -ForegroundColor $color
            Start-Sleep -Seconds 1
        }
        Write-Host ""
        Write-Host "Good Bye!" -ForegroundColor Green
        Start-Sleep -Seconds 1
        exit
    }

    if ($response -eq 'N') {
        $host.UI.RawUI.WindowTitle = "User Aborted Operation"
        $message = "User aborted the backup operation."
    
        # Toast & log
        New-BurntToastNotification -Text "WSL Backup Aborted", "User aborted the backup operation."
        Add-Content -Path $logFile -Value "$(Get-Date): $message"
    
        Write-Host ""
        Write-Host "=========================================================" -ForegroundColor Yellow
        Write-Host " WSL is active. Backup has been safely skipped for file lock safety." -ForegroundColor Red
        Write-Host " Please close Ubuntu/WSL instances and rerun the backup." -ForegroundColor Yellow
        Write-Host "=========================================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host ""
        # Styled countdown with color change effect
        for ($i = 3; $i -ge 1; $i--) {
            $color = if ($i % 2 -eq 0) { "Red" } else { "DarkRed" }
            Write-Host -NoNewline "`rClosing window in...$i" -ForegroundColor $color
            Start-Sleep -Seconds 1
        }
        Write-Host ""
        Write-Host "Good Bye! Have a nice Day!" -ForegroundColor Green
        Start-Sleep -Seconds 1
        exit
    }

    if ($response -eq 'Y') {
        $host.UI.RawUI.WindowTitle = "WSL Active:Force Stopping..."
        Write-Host "`nUser confirmed. Force stopping WSL processes..." -ForegroundColor Red
        Get-Process -Name "wsl" -ErrorAction SilentlyContinue | Stop-Process -Force
        Add-Content -Path $logFile -Value "$(Get-Date): WSL forcefully stopped for backup."
        Start-Sleep -Seconds 2
    }
}
# Check if WSL is running
$wslRunning = Get-Process -Name "wsl" -ErrorAction SilentlyContinue
if ($wslRunning) {
    Write-Host ""
    Write-Host "=========================================================" -ForegroundColor Red
    Write-Host " Warning! Failled To Force Shutdown WSL" -ForegroundColor Red
    Write-Host " Please Menually Close all the WSL Processes and Try Again Later" -ForegroundColor Red
    Write-Host "=========================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host ""
    exit
}
else {
    Write-Host ""
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host " Successfully Closed WSL. Starting backup..." -ForegroundColor Green
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host ""
}
# Log start of backup
Add-Content -Path $logFile -Value "$(Get-Date): $message"
New-BurntToastNotification -Text "WSL Backup Started", "Preparation in progress..."
wsl --shutdown
Start-Sleep -Seconds 1

# Begin backup
Write-Host ""
Write-Host "Backing up WSL virtual disk..." -ForegroundColor Gray
Write-Host "From: $source"
Write-Host "To:   $backupFile`n"

# Update window title
$host.UI.RawUI.WindowTitle = "WSL Backup - Copying Disk ext4.vhdx "

# Spinner animation during copy
$spinner = "/-\|"
$i = 0

$copyJob = Start-Job -ScriptBlock {
    param($src, $dst)
    #Copy-Item -Path $src -Destination $dst -Force
} -ArgumentList $source, $backupFile

while (($copyJob.State -eq 'Running') -or ($copyJob.State -eq 'NotStarted')) {
    Write-Host -NoNewline "`rCopying... $($spinner[$i % $spinner.Length])"
    Start-Sleep -Milliseconds 200
    $i++
}
Receive-Job $copyJob | Out-Null
Remove-Job $copyJob

Write-Host "`rCopy completed successfully.              " -ForegroundColor Green

# Update window title
$host.UI.RawUI.WindowTitle = "WSL Backup - Cleanup"

# Cleanup older backups (keep 2)
$backups = Get-ChildItem -Path $destinationFolder -Filter "ext4-backup-*.vhdx" |
Sort-Object LastWriteTime -Descending

if ($backups.Count -gt 2) {
    $backupsToRemove = $backups | Select-Object -Skip 2
    foreach ($old in $backupsToRemove) {
        Remove-Item $old.FullName -Force
        Write-Host "Deleted old backup: $($old.Name)" -ForegroundColor DarkGray
    }
}

# Final message
Write-Host "`nBackup complete! File saved as:" -ForegroundColor Cyan
Write-Host "$backupFile" -ForegroundColor Green

# Final window title
$host.UI.RawUI.WindowTitle = "WSL Backup - Complete"

# Exit countdown
Write-Host ""
for ($i = 5; $i -ge 1; $i--) {
    Write-Host -NoNewline "`rClosing in $i seconds..." -ForegroundColor DarkGreen
    Start-Sleep -Seconds 1
}
Write-Host "`rBackup finished. Window will now close.     " -ForegroundColor Green
Start-Sleep -Seconds 1