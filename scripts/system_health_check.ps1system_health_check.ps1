# PowerShell script to check system health and generate report
param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\SystemHealthReports\"
)

# Create output directory if it doesn't exist
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

$report = @()
$date = Get-Date -Format "yyyy-MM-dd_HH-mm"
$outputFile = "$OutputPath\$ComputerName`_$date.html"

# Get system information
$systemInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName
$report += "System: $($systemInfo.Caption) ($($systemInfo.Version))"
$report += "Last Boot: $($systemInfo.LastBootUpTime)"
$report += "Uptime: $([math]::Round(($systemInfo.LocalDateTime - $systemInfo.LastBootUpTime).TotalHours, 2)) hours"

# Get disk space information
$disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ComputerName $ComputerName
foreach ($disk in $disks) {
    $freeSpacePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
    $report += "Drive $($disk.DeviceID): $freeSpacePercent% free ($([math]::Round($disk.FreeSpace / 1GB, 2)) GB of $([math]::Round($disk.Size / 1GB, 2)) GB)"
}

# Get top 5 processes by memory usage
$processes = Get-Process -ComputerName $ComputerName | Sort-Object -Property WS -Descending | Select-Object -First 5
$report += "Top 5 memory-consuming processes:"
foreach ($process in $processes) {
    $report += "- $($process.ProcessName): $([math]::Round($process.WS / 1MB, 2)) MB"
}

# Check for pending updates
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $pendingUpdates = $updateSearcher.Search("IsInstalled=0 and IsHidden=0").Updates.Count
    $report += "Pending updates: $pendingUpdates"
} catch {
    $report += "Could not check for pending updates: $($_.Exception.Message)"
}

# Generate HTML report
$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>System Health Report: $ComputerName</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #0066cc; }
        .section { margin-bottom: 20px; }
        .warning { color: orange; }
        .critical { color: red; }
        .good { color: green; }
    </style>
</head>
<body>
    <h1>System Health Report: $ComputerName</h1>
    <div class="section">
        <h2>Generated: $date</h2>
        <pre>$($report -join "`n")</pre>
    </div>
</body>
</html>
"@

# Save the report
$htmlReport | Out-File -FilePath $outputFile -Encoding utf8

Write-Output "Report generated at $outputFile"
