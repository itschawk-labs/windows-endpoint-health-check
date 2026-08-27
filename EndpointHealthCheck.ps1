<#
.SYNOPSIS
    Performs a read-only Windows endpoint health check.

.DESCRIPTION
    Collects operating system, uptime, processor, memory,
    disk-space, Microsoft Defender, and installed hotfix
    information from a local Windows endpoint.

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


# ==========================================================
# [1] OPERATING SYSTEM
# ==========================================================
Write-Host "`n[1] OPERATING SYSTEM" -ForegroundColor Yellow

$OS = $null

try {
    $OS = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop

    $OS |
        Select-Object Caption, Version, OSArchitecture |
        Format-Table -AutoSize |
        Out-Host
}
catch {
    Write-Host "Operating-system information could not be retrieved." `
        -ForegroundColor Red
}


# ==========================================================
# [2] SYSTEM UPTIME
# ==========================================================
Write-Host "`n[2] SYSTEM UPTIME" -ForegroundColor Yellow

if ($null -ne $OS) {
    $Uptime = (Get-Date) - $OS.LastBootUpTime
    Write-Host "Uptime: $($Uptime.Days) days, $($Uptime.Hours) hours"
}
else {
    Write-Host "Uptime could not be determined." -ForegroundColor Red
}


# ==========================================================
# [3] PROCESSOR
# ==========================================================
Write-Host "`n[3] PROCESSOR" -ForegroundColor Yellow

try {
    Get-CimInstance Win32_Processor -ErrorAction Stop |
        Select-Object Name, NumberOfCores, NumberOfLogicalProcessors |
        Format-Table -AutoSize |
        Out-Host
}
catch {
    Write-Host "Processor information could not be retrieved." `
        -ForegroundColor Red
}


# ==========================================================
# [4] MEMORY
# ==========================================================
Write-Host "`n[4] MEMORY" -ForegroundColor Yellow

if ($null -ne $OS) {
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
}
else {
    Write-Host "Memory information could not be determined." `
        -ForegroundColor Red
}


# ==========================================================
# [5] DISK SPACE
# ==========================================================
Write-Host "`n[5] DISK SPACE" -ForegroundColor Yellow

$FixedDisks = $null

try {
    $FixedDisks = Get-CimInstance Win32_LogicalDisk `
        -Filter "DriveType=3" -ErrorAction Stop

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
}
catch {
    Write-Host "Disk-space information could not be retrieved." `
        -ForegroundColor Red
}


# ==========================================================
# [6] MICROSOFT DEFENDER
# ==========================================================
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
        -ForegroundColor Red
}


# ==========================================================
# [7] FIVE MOST RECENT INSTALLED HOTFIXES
# ==========================================================
Write-Host "`n[7] FIVE MOST RECENT INSTALLED HOTFIXES" `
    -ForegroundColor Yellow

try {
    Get-HotFix -ErrorAction Stop |
        Where-Object { $null -ne $_.InstalledOn } |
        Sort-Object InstalledOn -Descending |
        Select-Object -First 5 HotFixID, InstalledOn |
        Format-Table -AutoSize |
        Out-Host
}
catch {
    Write-Host "Installed hotfix information could not be retrieved." `
        -ForegroundColor Red
}


# ==========================================================
# [8] SYSTEM DRIVE SPACE ASSESSMENT
# ==========================================================
Write-Host "`n[8] SYSTEM DRIVE SPACE ASSESSMENT" -ForegroundColor Yellow

if ($null -ne $OS -and $null -ne $FixedDisks) {
    $SystemDrive = $OS.SystemDrive
    $SystemDisk  = $FixedDisks | Where-Object { $_.DeviceID -eq $SystemDrive }

    if ($null -ne $SystemDisk -and $SystemDisk.Size -gt 0) {
        $FreePercent = [math]::Round(
            ($SystemDisk.FreeSpace / $SystemDisk.Size) * 100, 1
        )

        if ($FreePercent -lt 20) {
            Write-Host "STATUS: WARNING - $SystemDrive has $FreePercent% free space (below 20%)" `
                -ForegroundColor Red
        }
        else {
            Write-Host "STATUS: HEALTHY - $SystemDrive has $FreePercent% free space (20% or greater)" `
                -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "NOTE: This threshold is a simple administrative health indicator." `
            -ForegroundColor DarkGray
        Write-Host "It is not a formal security or compliance benchmark." `
            -ForegroundColor DarkGray
    }
    else {
        Write-Host "STATUS: UNKNOWN - System drive information unavailable" `
            -ForegroundColor Yellow
    }
}
else {
    Write-Host "STATUS: UNKNOWN - System drive information unavailable" `
        -ForegroundColor Yellow
}


# ==========================================================
# HEALTH CHECK COMPLETE
# ==========================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "        HEALTH CHECK COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
