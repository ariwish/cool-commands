Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Mouse {
    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
}
"@

$GET_SPEED = 0x0070
$SET_SPEED = 0x0071
$newSpeed = 9
$defaultSpeed = 16

# 1. Get current speed safely
$ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)
[Mouse]::SystemParametersInfo($GET_SPEED, 0, $ptr, 0)
$originalSpeed = [System.Runtime.InteropServices.Marshal]::ReadInt32($ptr)
[System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)

try {
    # 2. Set to 12
    [Mouse]::SystemParametersInfo($SET_SPEED, 0, [IntPtr]$newSpeed, 0)
    Write-Host "Speed set to $newSpeed. Press Ctrl+C to restore to $defaultSpeed." -ForegroundColor Cyan
    
    while($true) { Start-Sleep -Seconds 1 }
}
finally {
    # 3. Always restore to 16
    [Mouse]::SystemParametersInfo($SET_SPEED, 0, [IntPtr]$defaultSpeed, 0)
    Write-Host "`nRestored speed to $defaultSpeed." -ForegroundColor Yellow
}