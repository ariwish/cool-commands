Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class LowLevelKeyMapper {
    private static IntPtr hookId = IntPtr.Zero;
    private static LowLevelKeyboardProc proc;
    private static System.Collections.Generic.Dictionary<int, int> keyMap;
    private static System.Collections.Generic.Dictionary<int, bool> needsShift;
    private static uint currentProcessId = 0;
    
    public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    
    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    
    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
    
    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    
    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    
    [DllImport("user32.dll")]
    public static extern short VkKeyScan(char ch);
    
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_KEYUP = 0x0101;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_SYSKEYUP = 0x0105;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    
    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT {
        public int vkCode;
        public int scanCode;
        public int flags;
        public int time;
        public IntPtr dwExtraInfo;
    }
    
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            IntPtr foregroundWindow = GetForegroundWindow();
            uint foregroundPid;
            GetWindowThreadProcessId(foregroundWindow, out foregroundPid);
            
            if (foregroundPid == currentProcessId) {
                return CallNextHookEx(hookId, nCode, wParam, lParam);
            }
            
            int wParamInt = wParam.ToInt32();
            KBDLLHOOKSTRUCT kbd = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            
            if (keyMap.ContainsKey(kbd.vkCode)) {
                int targetKey = keyMap[kbd.vkCode];
                bool shiftNeeded = needsShift.ContainsKey(kbd.vkCode) && needsShift[kbd.vkCode];
                
                if (wParamInt == WM_KEYDOWN || wParamInt == WM_SYSKEYDOWN) {
                    if (shiftNeeded) {
                        keybd_event(0x10, 0, 0, UIntPtr.Zero);
                    }
                    keybd_event((byte)targetKey, 0, 0, UIntPtr.Zero);
                } else if (wParamInt == WM_KEYUP || wParamInt == WM_SYSKEYUP) {
                    keybd_event((byte)targetKey, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                    if (shiftNeeded) {
                        keybd_event(0x10, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
                    }
                }
                
                return (IntPtr)1;
            }
        }
        
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
    
    public static void SetKeyMap(System.Collections.Generic.Dictionary<int, int> map, 
                                  System.Collections.Generic.Dictionary<int, bool> shiftMap) {
        keyMap = map;
        needsShift = shiftMap;
    }
    
    public static void Start() {
        currentProcessId = (uint)Process.GetCurrentProcess().Id;
        proc = HookCallback;
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule) {
            hookId = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }
    
    public static void Stop() {
        if (hookId != IntPtr.Zero) {
            UnhookWindowsHookEx(hookId);
            hookId = IntPtr.Zero;
        }
    }
    
    public static void MessageLoop() {
        System.Windows.Forms.Application.Run();
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

$keyAliases = @{
    'left' = 0x25; 'leftarrow' = 0x25
    'up' = 0x26; 'uparrow' = 0x26
    'right' = 0x27; 'rightarrow' = 0x27
    'down' = 0x28; 'downarrow' = 0x28
    'space' = 0x20; 'spacebar' = 0x20
    'tab' = 0x09; 'enter' = 0x0D; 'return' = 0x0D
    'escape' = 0x1B; 'esc' = 0x1B
    'backspace' = 0x08; 'back' = 0x08
    'delete' = 0x2E; 'del' = 0x2E
    'insert' = 0x2D; 'ins' = 0x2D
    'home' = 0x24; 'end' = 0x23
    'pageup' = 0x21; 'pgup' = 0x21
    'pagedown' = 0x22; 'pgdn' = 0x22
    'lshift' = 0xA0; 'rshift' = 0xA1
    'lctrl' = 0xA2; 'rctrl' = 0xA3
    'lalt' = 0xA4; 'ralt' = 0xA5
    'shift' = 0x10; 'ctrl' = 0x11; 'alt' = 0x12
}

$vkMap = New-Object 'System.Collections.Generic.Dictionary[int,int]'
$shiftMap = New-Object 'System.Collections.Generic.Dictionary[int,bool]'
$keyNames = @{}

function Get-VKCode {
    param([string]$key)
    
    $keyLower = $key.ToLower()
    
    if ($keyAliases.ContainsKey($keyLower)) {
        return @{ VK = $keyAliases[$keyLower]; Shift = $false }
    }
    
    if ($key.Length -eq 1) {
        $char = $key[0]
        $vkScan = [LowLevelKeyMapper]::VkKeyScan($char)
        
        if ($vkScan -ne -1) {
            $vk = $vkScan -band 0xFF
            $shift = ($vkScan -band 0x100) -ne 0
            return @{ VK = $vk; Shift = $shift }
        }
    }
    
    if ($key -match '^f(\d+)$') {
        $num = [int]$matches[1]
        if ($num -ge 1 -and $num -le 24) {
            return @{ VK = (0x70 + $num - 1); Shift = $false }
        }
    }
    
    if ($key -match '^numpad(\d)$') {
        return @{ VK = (0x60 + [int]$matches[1]); Shift = $false }
    }
    
    return $null
}

function Add-KeyRebind {
    param([string]$from, [string]$to)
    
    $fromCode = Get-VKCode $from
    $toCode = Get-VKCode $to
    
    if ($null -eq $fromCode) {
        Write-Host "Error: Invalid source key" -ForegroundColor Red
        return
    }
    if ($null -eq $toCode) {
        Write-Host "Error: Invalid target key" -ForegroundColor Red
        return
    }
    
    $vkMap[$fromCode.VK] = $toCode.VK
    $shiftMap[$fromCode.VK] = $toCode.Shift
    $keyNames[$fromCode.VK] = "$from -> $to"
    Write-Host "Mapped: $from -> $to" -ForegroundColor Green
}

function Show-Rebinds {
    if ($keyNames.Count -eq 0) {
        Write-Host "No active rebinds" -ForegroundColor Yellow
    } else {
        Write-Host "`nActive rebinds:" -ForegroundColor Cyan
        foreach ($vk in $keyNames.Keys) {
            Write-Host "  $($keyNames[$vk])"
        }
    }
}

function Start-Remapper {
    if ($vkMap.Count -eq 0) {
        Write-Host "No rebinds configured" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nLow-level hook active. Press Ctrl+C to stop" -ForegroundColor Green
    Show-Rebinds
    
    [LowLevelKeyMapper]::SetKeyMap($vkMap, $shiftMap)
    [LowLevelKeyMapper]::Start()
    
    try {
        [LowLevelKeyMapper]::MessageLoop()
    } finally {
        [LowLevelKeyMapper]::Stop()
    }
}

Write-Host "Key Remapper" -ForegroundColor Cyan
Write-Host "Commands: rebind <key> to <key>[, ...] | list | start | clear | exit"
Write-Host ""

while ($true) {
    $input = Read-Host ">"
    
    if ($input -match '^rebind\s+(.+)$') {
        $mappings = $matches[1] -split '\s*,\s*'
        foreach ($mapping in $mappings) {
            if ($mapping -match '^(\S+)\s+to\s+(\S+)$') {
                Add-KeyRebind $matches[1].Trim() $matches[2].Trim()
            } else {
                Write-Host "Invalid format" -ForegroundColor Red
            }
        }
    }
    elseif ($input -eq 'list') { Show-Rebinds }
    elseif ($input -eq 'start') { Start-Remapper }
    elseif ($input -eq 'clear') {
        $vkMap.Clear()
        $shiftMap.Clear()
        $keyNames.Clear()
        Write-Host "Cleared" -ForegroundColor Yellow
    }
    elseif ($input -eq 'exit' -or $input -eq 'quit') { break }
    else { Write-Host "Unknown command" -ForegroundColor Red }
}