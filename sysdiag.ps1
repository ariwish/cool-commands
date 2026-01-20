# Requires PowerShell 5.1 or later for some cmdlets
Clear-Host

# --- Host Function & Math for Formatting ---
Function GB ($bytes) { Return [Math]::Round($bytes / 1GB, 2) }
Function Round ($value, $decimals) { Return [Math]::Round($value, $decimals) }

# --- Collect System Information ---
$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
$board = Get-CimInstance Win32_BaseBoard
$bios = Get-CimInstance Win32_BIOS
$batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue

# --- Disk Information (Logical Disks, Type 3 for fixed drives) ---
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, Size, FreeSpace, VolumeName

# --- Uptime Calculation ---
$uptime = New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)

# --- Performance Metrics ---
$cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
$ramTotal = Round ($os.TotalVisibleMemorySize / 1MB) 2
$ramFree = Round ($os.FreePhysicalMemory / 1MB) 2
$ramUsed = Round ($ramTotal - $ramFree) 2
$ramPct = Round ($ramUsed / $ramTotal * 100) 1

# --- Display/Time Info ---
$res = "$($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution)"
$tz = Get-TimeZone | Select-Object -ExpandProperty Id
$loc = Get-Culture | Select-Object -ExpandProperty Name
$width = $Host.UI.RawUI.WindowSize.Width

# --- Output Formatting ---
Write-Host "SYSTEM OVERVIEW" -ForegroundColor Cyan
Write-Host ("-" * $width) -ForegroundColor DarkGray

# SYSTEM
Write-Host "SYSTEM" -ForegroundColor Cyan
Write-Host "OS: " -NoNewline -ForegroundColor DarkCyan; Write-Host "$($os.Caption) Build $($os.BuildNumber)"
Write-Host "Hostname: " -NoNewline -ForegroundColor DarkCyan; Write-Host $env:COMPUTERNAME
Write-Host "User: " -NoNewline -ForegroundColor DarkCyan; Write-Host $env:USERNAME
$domainLabel = if ($cs.PartOfDomain) { "Domain: " } else { "Workgroup: " }
Write-Host $domainLabel -NoNewline -ForegroundColor DarkCyan; Write-Host $cs.Domain
Write-Host "Uptime: " -NoNewline -ForegroundColor DarkCyan; Write-Host "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
Write-Host "Boot Time: " -NoNewline -ForegroundColor DarkCyan; Write-Host $os.LastBootUpTime
Write-Host "Time Zone: " -NoNewline -ForegroundColor DarkCyan; Write-Host $tz
Write-Host "Locale: " -NoNewline -ForegroundColor DarkCyan; Write-Host $loc

Write-Host ""
Write-Host "PERFORMANCE" -ForegroundColor Cyan
Write-Host ("-" * $width) -ForegroundColor DarkGray
Write-Host "CPU: " -NoNewline -ForegroundColor DarkCyan; Write-Host $cpu.Name
Write-Host "CPU Load: " -NoNewline -ForegroundColor DarkCyan; Write-Host "$cpuLoad%"
Write-Host "Cores: " -NoNewline -ForegroundColor DarkCyan; Write-Host "$($cpu.NumberOfCores) Threads: $($cpu.NumberOfLogicalProcessors)"
Write-Host "RAM: " -NoNewline -ForegroundColor DarkCyan; Write-Host "$ramUsed / $ramTotal GB ($ramPct%)" -ForegroundColor Yellow
Write-Host "GPU: " -NoNewline -ForegroundColor DarkCyan; Write-Host $gpu.Name
Write-Host "Resolution: " -NoNewline -ForegroundColor DarkCyan; Write-Host $res

Write-Host ""
Write-Host "HARDWARE" -ForegroundColor Cyan
Write-Host ("-" * $width) -ForegroundColor DarkGray
Write-Host "Manufacturer: " -NoNewline -ForegroundColor DarkCyan; Write-Host $board.Manufacturer
Write-Host "Model: " -NoNewline -ForegroundColor DarkCyan; Write-Host $board.Product
Write-Host "BIOS: " -NoNewline -ForegroundColor DarkCyan; Write-Host $bios.SMBIOSBIOSVersion
Write-Host "Serial Number: " -NoNewline -ForegroundColor DarkCyan; Write-Host $bios.SerialNumber

Write-Host ""
Write-Host "STORAGE" -ForegroundColor Cyan
Write-Host ("-" * $width) -ForegroundColor DarkGray
foreach ($d in $disks) {
    $used = GB ($d.Size - $d.FreeSpace)
    $pct = Round ($used / (GB $d.Size) * 100) 1
    Write-Host "$($d.DeviceID) $($d.VolumeName): " -NoNewline -ForegroundColor DarkCyan; Write-Host "$used / $($used + (GB $d.FreeSpace)) GB ($pct% used)" -ForegroundColor Yellow
}

if ($batt) {
    Write-Host ""
    Write-Host "BATTERY" -ForegroundColor Cyan
    Write-Host ("-" * $width) -ForegroundColor DarkGray
    Write-Host "Charge: " -NoNewline -ForegroundColor DarkCyan; Write-Host "$($batt.EstimatedChargeRemaining)%" -ForegroundColor Green
    # Add estimated runtime if available and not 'Unknown'
    if ($batt.EstimatedRunTime -ne 0 -and $batt.EstimatedRunTime -ne 2147483647) { # WMI code for 'Unknown'
         Write-Host "Estimated Runtime: " -NoNewline -ForegroundColor DarkCyan; Write-Host "$($batt.EstimatedRunTime) minutes"
    }
}

Write-Host ""
Write-Host "NETWORK" -ForegroundColor Cyan
Write-Host ("-" * $width) -ForegroundColor DarkGray

# Get active network interfaces with IP, MAC, Gateway, and DNS
$netAdapters = Get-NetIPConfiguration | Where-Object {$_.IPv4Address -and $_.NetAdapter.Status -eq 'Up'}

foreach ($adapter in $netAdapters) {
    Write-Host "* Interface:" -NoNewline -ForegroundColor DarkCyan; Write-Host $adapter.InterfaceAlias
    Write-Host "  Description: " -NoNewline -ForegroundColor Gray; Write-Host $adapter.NetAdapter.Description
    Write-Host "  MAC Address: " -NoNewline -ForegroundColor Gray; Write-Host $adapter.NetAdapter.MacAddress
    
    # Check for WiFi SSID and Signal Strength using netsh
    if ($adapter.InterfaceAlias -like '*Wi-Fi*') {
        $ssid = (netsh wlan show interfaces) -Match '^\s+SSID' -Replace '^\s+SSID\s+:\s+',''
        $signal = (netsh wlan show interfaces) -Match '^\s+Signal' -Replace '^\s+Signal\s+:\s+',''
        Write-Host "  SSID: " -NoNewline -ForegroundColor Gray; Write-Host $ssid
        Write-Host "  Signal: " -NoNewline -ForegroundColor Gray; Write-Host $signal -ForegroundColor Yellow
    }

    # Output IP Addresses
    foreach ($ip in $adapter.IPv4Address.IPAddress) {
        Write-Host "  IPv4 Address: " -NoNewline -ForegroundColor Gray; Write-Host $ip
    }
    
    # Output Default Gateways
    foreach ($gw in $adapter.IPv4DefaultGateway.NextHop) {
        Write-Host "  Default Gateway: " -NoNewline -ForegroundColor Gray; Write-Host $gw
    }

    # Output DNS Servers
    foreach ($dns in $adapter.DnsServer.ServerAddresses) {
        Write-Host "  DNS Server: " -NoNewline -ForegroundColor Gray; Write-Host $dns
    }
}

Write-Host ""
Write-Host "Shell: " -NoNewline -ForegroundColor Green; Write-Host "PowerShell $($PSVersionTable.PSVersion)"
Write-Host "Status: " -NoNewline -ForegroundColor Green; Write-Host "READY"
Write-Host ""
