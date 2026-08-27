<#
.SYNOPSIS
    Performs a read-only Windows endpoint health check.

.DESCRIPTION
    Collects operating system, uptime, processor, memory,
    disk-space, Microsoft Defender, and installed hotfix
    information.

    The script also performs a basic free-space assessment
    of the Windows system drive.

.NOTES
    This script is read-only and does not modify system
    configuration.

    Running PowerShell as Administrator is recommended for
    consistent access to all checks.
#>

Clear-Host

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "      WINDOWS ENDPOINT HEALTH CHECK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan


# ----------------------------------------------------------
Write-Host "`n[1] OPERATING SYSTEM" -ForegroundColor Yellow

$OS = Get-CimInstance Win32_OperatingSystem

$OS |
Select-Object Caption, Version, OSArchitecture |
Format-Table -AutoSize |
Out-Host


# ----------------------------------------------------------
Write-Host "`n[2] SYSTEM UPTIME" -ForegroundColor Yellow

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

$OS |
Select-Object `
    @{Name="Total RAM (GB)"; Expression={
        [math]::Round($_.TotalVisibleMemorySize / 1MB, 1)
    }},
    @{Name="Free RAM (GB)"; Expression={
        [math]::Round($_.FreePhysicalMemory / 1MB, 1)
    }} |
Format-Table -AutoSize |
Out-Host


# ----------------------------------------------------------
Write-Host "`n[5] DISK SPACE" -ForegroundColor Yellow

$FixedDisks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

$FixedDisks |
Select-Object DeviceID,
    @{Name="Size (GB)"; Expression={
        [math]::Round($_.Size / 1GB, 1)
    }},
    @{Name="Free (GB)"; Expression={
        [math]::Round($_.FreeSpace / 1GB, 1)
    }},
    @{Name="Free (%)"; Expression={
        if ($_.Size -gt 0) {
            [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
        }
    }} |
Format-Table -AutoSize |
Out-Host


# ----------------------------------------------------------
Write-Host "`n[6] MICROSOFT DEFENDER" -ForegroundColor Yellow

try {

    $Defender = Get-MpComputerStatus -ErrorAction Stop

    [PSCustomObject]@{
        "Antivirus"          = $Defender.AntivirusEnabled
        "Real-Time Protect"  = $Defender.RealTimeProtectionEnabled
        "Antispyware"        = $Defender.AntispywareEnabled
        "Signatures Updated" = $Defender.AntivirusSignatureLastUpdated
    } |
    Format-List |
    Out-Host

}
catch {

    Write-Host "Microsoft Defender status could not be retrieved." `
        -ForegroundColor Yellow
}


# ----------------------------------------------------------
Write-Host "`n[7] FIVE MOST RECENT INSTALLED HOTFIXES" `
    -ForegroundColor Yellow

try {

    Get-HotFix -ErrorAction Stop |
    Where-Object { $_.InstalledOn } |
    Sort-Object InstalledOn -Descending |
    Select-Object -First 5 HotFixID, InstalledOn |
    Format-Table -AutoSize |
    Out-Host

}
catch {

    Write-Host "Installed hotfix information could not be retrieved." `
        -ForegroundColor Yellow
}


# ----------------------------------------------------------
Write-Host "`n[8] SYSTEM DRIVE SPACE ASSESSMENT" `
    -ForegroundColor Yellow

$SystemDrive = $OS.SystemDrive

$Disk = Get-CimInstance Win32_LogicalDisk `
    -Filter "DeviceID='$SystemDrive'"

if ($Disk -and $Disk.Size -gt 0) {

    $FreePercent = ($Disk.FreeSpace / $Disk.Size) * 100
    $RoundedFreePercent = [math]::Round($FreePercent, 1)

    if ($FreePercent -lt 20) {

        Write-Host `
            "STATUS: WARNING - $SystemDrive has $RoundedFreePercent% free space (below 20%)" `
            -ForegroundColor Red

    }
    else {

        Write-Host `
            "STATUS: HEALTHY - $SystemDrive has $RoundedFreePercent% free space (20% or greater)" `
            -ForegroundColor Green
    }

}
else {

    Write-Host "STATUS: UNKNOWN - System drive information unavailable" `
        -ForegroundColor Yellow
}


# ----------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "        HEALTH CHECK COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
