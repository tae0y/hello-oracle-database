# C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
# -ExecutionPolicy Unrestricted -File {FILEPATH}

param(
    [string]$WebhookUrl = "$env:DISCORD_WEBHOOK_URL",
    [int]$CpuThreshold = 100,
    [int]$MemThreshold = 90,
    [int]$DiskThreshold = 80,
    [int]$DockerVhdxThreshold = 40,
    [int]$SnoozeHours = 1,
    [string]$StateFile = "$env:TEMP\windows-monitor-state.json",
    [string[]]$MonitorDrives = @('C', 'D', 'E')
)

function Get-SystemMetrics {
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 3 |
        Select-Object -ExpandProperty CounterSamples |
        Measure-Object -Property CookedValue -Average).Average

    $os = Get-CimInstance Win32_OperatingSystem
    $memUsedGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
    $memTotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $memPercent = [math]::Round(($memUsedGB / $memTotalGB) * 100, 1)

    $disks = @{}
    foreach ($driveLetter in $MonitorDrives) {
        try {
            $disk = Get-PSDrive $driveLetter -ErrorAction Stop
            $diskUsedGB = [math]::Round($disk.Used / 1GB, 2)
            $diskTotalGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
            $diskPercent = [math]::Round(($diskUsedGB / $diskTotalGB) * 100, 1)
            
            $disks[$driveLetter] = @{
                Percent = $diskPercent
                UsedGB = $diskUsedGB
                TotalGB = $diskTotalGB
            }
        } catch {
            continue
        }
    }

    $vhdxPath = "$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx"
    $vhdxSizeGB = if (Test-Path $vhdxPath) {
        [math]::Round((Get-Item $vhdxPath).Length / 1GB, 2)
    } else { 0 }

    return @{
        CPU = [math]::Round($cpu, 1)
        MemPercent = $memPercent
        MemUsed = $memUsedGB
        MemTotal = $memTotalGB
        Disks = $disks
        DockerVhdxGB = $vhdxSizeGB
    }
}

function Get-PreviousState {
    if (Test-Path $StateFile) {
        try {
            $json = Get-Content $StateFile -Raw | ConvertFrom-Json
            $hashtable = @{}
            $json.PSObject.Properties | ForEach-Object {
                $hashtable[$_.Name] = $_.Value
            }
            return $hashtable
        } catch {
            return @{}
        }
    }
    return @{}
}

function Save-State {
    param($State)
    $State | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
}

function Send-DiscordAlert {
    param(
        [string]$Message,
        [string]$Type
    )
    
    $emoji = if ($Type -eq "resolved") { "🟢" } else { "🔴" }
    $username = "Windows Monitor"
    
    $content = "$emoji $Message`n`nTimestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    $jsonPayload = @"
{
    "username": "$username",
    "content": $(ConvertTo-Json $content -Compress)
}
"@
    
    try {
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)
        
        Invoke-RestMethod -Uri $WebhookUrl `
                          -Method Post `
                          -Body $bodyBytes `
                          -ContentType 'application/json; charset=utf-8'
    } catch {
        Write-Error "Failed to send Discord notification: $_"
        Add-Content -Path "$env:TEMP\windows-monitor-failed.log" -Value "[$(Get-Date)] $content" -Encoding UTF8
    }
}

$metrics = Get-SystemMetrics
$previousState = Get-PreviousState
$now = Get-Date

$checks = @{
    Cpu = @{
        IsHigh = ($metrics.CPU -gt $CpuThreshold)
        Message = "CPU: $($metrics.CPU)% (threshold: ${CpuThreshold}%)"
        ResolvedMessage = "CPU recovered: $($metrics.CPU)%"
    }
    Mem = @{
        IsHigh = ($metrics.MemPercent -gt $MemThreshold)
        Message = "Memory: $($metrics.MemPercent)% - $($metrics.MemUsed)GB/$($metrics.MemTotal)GB (threshold: ${MemThreshold}%)"
        ResolvedMessage = "Memory recovered: $($metrics.MemPercent)%"
    }
    Vhdx = @{
        IsHigh = ($metrics.DockerVhdxGB -gt $DockerVhdxThreshold)
        Message = "Docker vhdx: $($metrics.DockerVhdxGB)GB (threshold: ${DockerVhdxThreshold}GB)"
        ResolvedMessage = "Docker vhdx recovered: $($metrics.DockerVhdxGB)GB"
    }
}

foreach ($driveLetter in $metrics.Disks.Keys) {
    $diskInfo = $metrics.Disks[$driveLetter]
    $checks["Disk$driveLetter"] = @{
        IsHigh = ($diskInfo.Percent -gt $DiskThreshold)
        Message = "Disk ${driveLetter}: $($diskInfo.Percent)% - $($diskInfo.UsedGB)GB/$($diskInfo.TotalGB)GB (threshold: ${DiskThreshold}%)"
        ResolvedMessage = "Disk ${driveLetter} recovered: $($diskInfo.Percent)%"
    }
}

$alertsToSend = @()
$resolvedAlerts = @()

foreach ($key in $checks.Keys) {
    $check = $checks[$key]
    $isHigh = $check.IsHigh
    
    $lastAlertKey = "Last${key}Alert"
    $lastAlertTime = if ($previousState.ContainsKey($lastAlertKey) -and $previousState[$lastAlertKey]) {
        [DateTime]::Parse($previousState[$lastAlertKey])
    } else {
        $null
    }
    
    if ($isHigh) {
        $shouldAlert = $false
        
        if (-not $lastAlertTime) {
            $shouldAlert = $true
            $alertType = "New"
        } elseif (($now - $lastAlertTime).TotalHours -ge $SnoozeHours) {
            $shouldAlert = $true
            $hoursSince = [math]::Round(($now - $lastAlertTime).TotalHours, 1)
            $alertType = "Ongoing (${hoursSince}h elapsed)"
        }
        
        if ($shouldAlert) {
            $previousState[$lastAlertKey] = $now.ToString("o")
            $alertsToSend += "⚠️ [$alertType] $($check.Message)"
        }
    } else {
        if ($lastAlertTime) {
            $previousState[$lastAlertKey] = $null
            $resolvedAlerts += "✅ $($check.ResolvedMessage)"
        }
    }
}

if ($alertsToSend.Count -gt 0) {
    $message = "**Alert Triggered**`n" + ($alertsToSend -join "`n") + "`n`nNext notification: after ${SnoozeHours}h or when resolved"
    Send-DiscordAlert -Message $message -Type "alert"
}

if ($resolvedAlerts.Count -gt 0) {
    $message = "**Alert Resolved**`n" + ($resolvedAlerts -join "`n")
    Send-DiscordAlert -Message $message -Type "resolved"
}

Save-State -State $previousState

$diskLog = ($metrics.Disks.Keys | ForEach-Object { "${_}:$($metrics.Disks[$_].Percent)%" }) -join " "
$logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] CPU:$($metrics.CPU)% MEM:$($metrics.MemPercent)% $diskLog VHDX:$($metrics.DockerVhdxGB)GB"
if ($alertsToSend.Count -gt 0) { $logMessage += " [ALERTS: $($alertsToSend.Count)]" }
if ($resolvedAlerts.Count -gt 0) { $logMessage += " [RESOLVED: $($resolvedAlerts.Count)]" }
Add-Content -Path "$env:TEMP\windows-monitor.log" -Value $logMessage -Encoding UTF8