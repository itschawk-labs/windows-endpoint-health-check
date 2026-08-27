# Windows Endpoint Health Check

A lightweight PowerShell utility for collecting common Windows endpoint health and security information from a local system.

## Overview

This project demonstrates the use of PowerShell for Windows endpoint administration, system-information collection, and basic automated health assessment.

The script is read-only and does not modify Windows configuration.

## Checks

The script reports:

- Windows operating system, version, and architecture
- System uptime
- Processor model, physical cores, and logical processors
- Total and available physical memory
- Fixed-disk capacity and available disk space
- Microsoft Defender antivirus status
- Microsoft Defender real-time protection status
- Microsoft Defender signature update timestamp
- Five most recently installed Windows hotfixes
- Automated system-drive free-space assessment

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or a compatible PowerShell environment
- Microsoft Defender cmdlets for Defender status reporting

Running PowerShell as Administrator is recommended for consistent access to all system information.

## Usage

Open PowerShell, navigate to the directory containing the script, and run:

```powershell
.\EndpointHealthCheck.ps1
```

If PowerShell execution policy prevents the script from running, review the execution-policy configuration before making any changes.

## Disk-Space Assessment

The script evaluates available space on the Windows system drive.

- **HEALTHY:** 20% or more free space
- **WARNING:** Less than 20% free space

The threshold is intended as a simple administrative health indicator rather than a formal industry security benchmark.

## Example Output

The console output is organized into numbered sections and uses color-coded status messages to make results easier to review.

![Example Output](screenshots/example-output.png)

## Purpose

I created this project as a practical exercise in PowerShell-based Windows endpoint administration. It combines system-information collection with a simple automated assessment rather than relying solely on manually reviewing command output.

## Scope and Limitations

This is a lightweight endpoint health-check utility, not a complete enterprise monitoring, vulnerability-assessment, or security-baseline solution.

The script currently evaluates a single local Windows endpoint and does not make configuration changes.

## Future Improvements

Potential future development includes:

- Additional Microsoft Defender checks
- BitLocker status
- Secure Boot status
- Windows Firewall status
- Event-log health checks
- Configurable health thresholds
- Export to CSV or JSON
- Remote endpoint support

## Safety

The script performs read-only queries and does not modify Windows settings, security controls, registry values, accounts, or system configuration.
