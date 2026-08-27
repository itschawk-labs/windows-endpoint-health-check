<#
.SYNOPSIS
    Performs a read-only Windows endpoint health check.

.DESCRIPTION
    Collects operating system, uptime, processor, memory,
    disk-space, PowerShell execution policy, user account
    control settings, and installed hotfix information.

    Concludes with a scored baseline-security assessment
    covering Windows Firewall, Microsoft Defender,
    SMBv1 state, the built-in Guest account, and UAC.

.NOTES
    This script is read-only and does not modify system
    configuration.

    Running PowerShell as Administrator is recommended for
    consistent access to all checks.
#>

Clear-Host

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "      WINDOWS ENDPOINT HEALTH CHECK" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan


# ==========================================================
# [1] OPERATING SYSTEM
# ==========================================================
Write-Host "`n[1] OPERATING SYSTEM" -ForegroundColor Yellow

$OS = Get-CimInstance Win32_OperatingSystem

$OS |
Select-Object Caption, Version, OSArchitecture |
Format-Table -AutoSize |
Out-Host


# ==========================================================
# [2] SYSTEM UPTIME
# ==========================================================
Write-Host "`n[2] SYSTEM UPTIME" -ForegroundColor Yellow

$Uptime = (Get-Date) - $OS.LastBootUpTime

Write-Host "Uptime: $($Uptime.Days) days, $($Uptime.Hours) hours"


# ==========================================================
# [3] PROCESSOR
# ==========================================================
Write-Host "`n[3] PROCESSOR" -ForegroundColor Yellow

Get-CimInstance Win32_Processor |
Select-Object Name, NumberOfCores, NumberOfLogicalProcessors |
Format-Table -AutoSize |
Out-Host


# ==========================================================
# [4] MEMORY
# ==========================================================
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


# ==========================================================
# [5] DISK SPACE
# ==========================================================
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


# ==========================================================
# [6] POWERSHELL EXECUTION POLICY
# ==========================================================
Write-Host "`n[6] POWERSHELL EXECUTION POLICY" -ForegroundColor Yellow

Get-ExecutionPolicy -List |
    Format-Table -AutoSize |
    Out-Host

Write-Host `
    "INFO: Execution policy is reported for visibility and is not treated as a security boundary." `
    -ForegroundColor Cyan


# ==========================================================
# [7] USER ACCOUNT CONTROL
# ==========================================================
Write-Host "`n[7] USER ACCOUNT CONTROL" -ForegroundColor Yellow

$UAC = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

$ConsentDescriptions = @{
    0 = "Elevate without prompting"
    1 = "Prompt for credentials on secure desktop"
    2 = "Prompt for consent on secure desktop"
    3 = "Prompt for credentials"
    4 = "Prompt for consent"
    5 = "Prompt for consent for non-Windows binaries"
}

$ConsentValue = $UAC.ConsentPromptBehaviorAdmin

if ($ConsentDescriptions.ContainsKey($ConsentValue)) {
    $ConsentDescription = $ConsentDescriptions[$ConsentValue]
}
else {
    $ConsentDescription = "Unknown policy value"
}

[PSCustomObject]@{
    "UAC Enabled"          = [bool]$UAC.EnableLUA
    "Admin Consent Policy" = $ConsentDescription
    "Policy Value"         = $ConsentValue
} |
    Format-List |
    Out-Host


# ==========================================================
# [8] RECENT INSTALLED HOTFIXES
# ==========================================================
Write-Host "`n[8] FIVE MOST RECENT INSTALLED HOTFIXES" `
    -ForegroundColor Yellow

Get-HotFix |
    Where-Object { $null -ne $_.InstalledOn } |
    Sort-Object InstalledOn -Descending |
    Select-Object -First 5 HotFixID, InstalledOn |
    Format-Table -AutoSize |
    Out-Host


# ==========================================================
# Collect data for baseline assessment
# ==========================================================
$Defender         = Get-MpComputerStatus          -ErrorAction SilentlyContinue
$FirewallProfiles = Get-NetFirewallProfile         -ErrorAction SilentlyContinue
$SMB1             = Get-WindowsOptionalFeature `
                        -Online `
                        -FeatureName SMB1Protocol  -ErrorAction SilentlyContinue
$Guest            = Get-LocalUser -Name "Guest"    -ErrorAction SilentlyContinue


# ==========================================================
# [9] BASELINE ASSESSMENT
# ==========================================================
Write-Host "`n[9] BASELINE ASSESSMENT" -ForegroundColor Yellow

$PassCount = 0
$WarnCount = 0

# ----------------------------------------------------------
# FIREWALL
# ----------------------------------------------------------
$DisabledFirewallProfiles = @(
    $FirewallProfiles |
        Where-Object { $_.Enabled -eq $false }
)
if ($DisabledFirewallProfiles.Count -eq 0) {
    Write-Host "[PASS] Windows Firewall enabled on all profiles" `
        -ForegroundColor Green
    $PassCount++
}
else {
    Write-Host "[WARN] One or more Windows Firewall profiles disabled" `
        -ForegroundColor Red
    $WarnCount++
}

# ----------------------------------------------------------
# DEFENDER ANTIVIRUS
# ----------------------------------------------------------
if ($Defender.AntivirusEnabled -eq $true) {
    Write-Host "[PASS] Microsoft Defender Antivirus enabled" `
        -ForegroundColor Green
    $PassCount++
}
else {
    Write-Host "[WARN] Microsoft Defender Antivirus disabled" `
        -ForegroundColor Red
    $WarnCount++
}

# ----------------------------------------------------------
# DEFENDER REAL-TIME PROTECTION
# ----------------------------------------------------------
if ($Defender.RealTimeProtectionEnabled -eq $true) {
    Write-Host "[PASS] Defender real-time protection enabled" `
        -ForegroundColor Green
    $PassCount++
}
else {
    Write-Host "[WARN] Defender real-time protection disabled" `
        -ForegroundColor Red
    $WarnCount++
}

# ----------------------------------------------------------
# DEFENDER BEHAVIOR MONITORING
# ----------------------------------------------------------
if ($Defender.BehaviorMonitorEnabled -eq $true) {
    Write-Host "[PASS] Defender behavior monitoring enabled" `
        -ForegroundColor Green
    $PassCount++
}
else {
    Write-Host "[WARN] Defender behavior monitoring disabled" `
        -ForegroundColor Red
    $WarnCount++
}

# ----------------------------------------------------------
# DEFENDER NETWORK INSPECTION
# ----------------------------------------------------------
if ($Defender.NISEnabled -eq $true) {
    Write-Host "[PASS] Defender network inspection enabled" `
        -ForegroundColor Green
    $PassCount++
}
else {
    Write-Host "[WARN] Defender network inspection disabled" `
        -ForegroundColor Red
    $WarnCount++
}

# ----------------------------------------------------------
# SMBv1
# ----------------------------------------------------------
if ($SMB1.State -eq "Disabled") {
    Write-Host "[PASS] SMBv1 disabled" `
        -ForegroundColor Green
    $PassCount++
}
else {
    Write-Host "[WARN] SMBv1 enabled or available" `
        -ForegroundColor Red
    $WarnCount++
}

# ----------------------------------------------------------
# BUILT-IN GUEST ACCOUNT
# ----------------------------------------------------------
if ($null -eq $Guest) {
    Write-Host "[PASS] Built-in Guest account unavailable" `
        -ForegroundColor Green
    $PassCount++
}
elseif ($Guest.Enabled -eq $false) {
    Write-Host "[PASS] Built-in Guest account disabled" `
        -ForegroundColor Green
    $PassCount++
}
else {
    Write-Host "[WARN] Built-in Guest account enabled" `
        -ForegroundColor Red
    $WarnCount++
}

# ----------------------------------------------------------
# USER ACCOUNT CONTROL
# ----------------------------------------------------------
if ([bool]$UAC.EnableLUA) {
    Write-Host "[PASS] User Account Control enabled" `
        -ForegroundColor Green
    $PassCount++
}
else {
    Write-Host "[WARN] User Account Control disabled" `
        -ForegroundColor Red
    $WarnCount++
}


# ==========================================================
# [10] ASSESSMENT SUMMARY
# ==========================================================
Write-Host "`n[10] ASSESSMENT SUMMARY" -ForegroundColor Yellow

Write-Host "Passed   : $PassCount" -ForegroundColor Green

if ($WarnCount -eq 0) {
    Write-Host "Warnings : $WarnCount" -ForegroundColor Green
}
else {
    Write-Host "Warnings : $WarnCount" -ForegroundColor Red
}

# ==========================================================
# AUDIT COMPLETE
# ==========================================================
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "             BASELINE AUDIT COMPLETE" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Scope: Selected Windows endpoint configuration controls." `
    -ForegroundColor DarkGray
Write-Host "Result: PASS indicates the defined condition was satisfied;" `
    -ForegroundColor DarkGray
Write-Host "it does not indicate comprehensive endpoint security." `
    -ForegroundColor DarkGray
Write-Host ""
