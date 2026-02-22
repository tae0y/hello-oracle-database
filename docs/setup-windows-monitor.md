# Set Up Windows Host Monitoring

This page describes how to configure the PowerShell monitoring script to send Discord alerts for CPU, memory, disk, and Docker vhdx usage.

## Prerequisites

- Windows 10/11 with PowerShell 5.1+
- A Discord webhook URL (see [Discord docs](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks))
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (for vhdx size monitoring)

## Configure the Discord Webhook

1. Set the webhook URL as a system environment variable.

    ```powershell
    # PowerShell (Admin)
    [Environment]::SetEnvironmentVariable('DISCORD_WEBHOOK_URL', 'https://discord.com/api/webhooks/...', 'Machine')
    ```

1. Restart the terminal to pick up the new variable.

## Script Parameters

The script at `scripts/windows-monitor.ps1` accepts these parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-CpuThreshold` | `100` | CPU usage % to trigger alert |
| `-MemThreshold` | `90` | Memory usage % to trigger alert |
| `-DiskThreshold` | `80` | Disk usage % to trigger alert |
| `-DockerVhdxThreshold` | `40` | Docker `ext4.vhdx` size in GB to trigger alert |
| `-SnoozeHours` | `1` | Minimum hours between repeated alerts for the same metric |
| `-MonitorDrives` | `C, D, E` | Drive letters to monitor |

## Schedule with Task Scheduler

1. Open Task Scheduler (`taskschd.msc`).

1. Create a new task with **Run whether user is logged on or not**.

    | Tab | Field | Value |
    |-----|-------|-------|
    | General | Name | Windows Monitor |
    | General | Run with highest privileges | Checked |
    | Triggers | Begin the task | On a schedule |
    | Triggers | Repeat task every | 5 minutes |
    | Actions | Program | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` |
    | Actions | Arguments | `-ExecutionPolicy Unrestricted -File "C:\path\to\scripts\windows-monitor.ps1"` |

> **Important:** Replace `C:\path\to\scripts\windows-monitor.ps1` with the absolute path to the script on your machine.

## Alert Behavior

The script uses a state file (`%TEMP%\windows-monitor-state.json`) to track alert history.

- **New alert** fires immediately when a threshold is first exceeded.
- **Ongoing alert** re-fires after the snooze period (default: 1 hour) if the metric remains above the threshold.
- **Resolved alert** fires once when a previously alerted metric returns below the threshold.

All runs are logged to `%TEMP%\windows-monitor.log`.

## Remove

1. Delete the task from Task Scheduler.

1. Remove the environment variable.

    ```powershell
    # PowerShell (Admin)
    [Environment]::SetEnvironmentVariable('DISCORD_WEBHOOK_URL', $null, 'Machine')
    ```

1. Clean up state and log files.

    ```powershell
    # PowerShell
    Remove-Item "$env:TEMP\windows-monitor-state.json", "$env:TEMP\windows-monitor.log" -ErrorAction SilentlyContinue
    ```
