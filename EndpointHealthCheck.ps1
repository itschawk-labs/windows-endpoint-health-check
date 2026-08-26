Clear-Host

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "      WINDOWS ENDPOINT HEALTH CHECK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ----------------------------------------------------------
Write-Host "`n[1] OPERATING SYSTEM" -ForegroundColor Yellow

Get-CimInstance Win32_OperatingSystem |
Select-Object Caption, Version, OSArchitecture |
Format-Table -AutoSize |
Out-Host


# ----------------------------------------------------------
Write-Host "`n[2] SYSTEM UPTIME" -ForegroundColor Yellow

$OS = Get-CimInstance Win32_OperatingSystem
$Uptime = (Get-Date) - $OS.LastBootUpTime

Write-Host "Uptime: $($Uptime.Days) days, $($Uptime.Hours) hours"


# ----------------------------------------------------------
Write-Host "`n[3] PROCESSOR" -ForegroundColor Yellow

Get-CimInstance Win32_Processor |
Select-Object Name, NumberOfCores, NumberOfLogicalProcessors |
Format-Table -AutoSize |
Out-Host


# ----------------------------------------------------------
Write-Host "`n[4] MEMORY" -ForegroundColor Yellow

Get-CimInstance Win32_OperatingSystem |
Select-Object `
@{Name="Total RAM (GB)"; Expression={[math]::Round($_.TotalVisibleMemorySize / 1MB,1)}},
@{Name="Free RAM (GB)"; Expression={[math]::Round($_.FreePhysicalMemory / 1MB,1)}} |
Format-Table -AutoSize |
Out-Host


# ----------------------------------------------------------
Write-Host "`n[5] DISK HEALTH" -ForegroundColor Yellow

Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
Select-Object DeviceID,
@{Name="Size (GB)"; Expression={[math]::Round($_.Size / 1GB,1)}},
@{Name="Free (GB)"; Expression={[math]::Round($_.FreeSpace / 1GB,1)}},
@{Name="Free (%)"; Expression={[math]::Round(($_.FreeSpace / $_.Size) * 100,1)}} |
Format-Table -AutoSize |
Out-Host


# ----------------------------------------------------------
Write-Host "`n[6] MICROSOFT DEFENDER" -ForegroundColor Yellow

$Defender = Get-MpComputerStatus

[PSCustomObject]@{
    "Antivirus"         = $Defender.AntivirusEnabled
    "Real-Time Protect" = $Defender.RealTimeProtectionEnabled
    "Antispyware"       = $Defender.AntispywareEnabled
    "Signatures Updated"= $Defender.AntivirusSignatureLastUpdated
} |
Format-List |
Out-Host


# ----------------------------------------------------------
Write-Host "`n[7] FIVE MOST RECENT WINDOWS UPDATES" -ForegroundColor Yellow

Get-HotFix |
Sort-Object InstalledOn -Descending |
Select-Object -First 5 HotFixID, InstalledOn |
Format-Table -AutoSize |
Out-Host


# ----------------------------------------------------------
Write-Host "`n[8] AUTOMATED DISK ASSESSMENT" -ForegroundColor Yellow

$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$FreePercent = ($Disk.FreeSpace / $Disk.Size) * 100

if ($FreePercent -lt 20) {
    Write-Host "STATUS: WARNING - Disk space below 20%" -ForegroundColor Red
}
else {
    Write-Host "STATUS: HEALTHY - Disk space above 20%" -ForegroundColor Green
}


# ----------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "        HEALTH CHECK COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green