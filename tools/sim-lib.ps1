#requires -Version 7
# Helpers for driving the Connect IQ simulator window from a script.
# Dot-source this file; tools/sim-matrix.ps1 is the main user.
#
# What works and what does not (found the hard way):
# - Menu commands are posted as WM_COMMAND with ids read from the Win32 menu.
# - Screenshots come from PrintWindow on the device panel, at the device image's
#   own pixel size whatever the display scaling.
# - Watch buttons need real mouse input: the pointer has to move onto the button
#   and the press has to be held. Posted mouse and key messages are ignored, so
#   the pointer jumps for a moment on every press.
# - The Language menu only lists languages once a device has been loaded.
# - Loading a different device into a running simulator leaves it unable to
#   start the app; restart the simulator instead (Restart-Sim).

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('SimW' -as [type])) {
Add-Type @'
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public class SimW {
 public delegate bool Cb(IntPtr h, IntPtr l);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr m, int pos);
 [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr m);
 [DllImport("user32.dll")] public static extern uint GetMenuItemID(IntPtr m, int pos);
 [DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr m, uint id, uint flags);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetMenuString(IntPtr m, uint item, StringBuilder s, int max, uint flags);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
 [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
 [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint f, UIntPtr e);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetDpiForSystem();
 [DllImport("user32.dll")] public static extern bool EnumWindows(Cb cb, IntPtr l);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 public struct RECT { public int L, T, R, B; }
 public struct POINT { public int X, Y; }
 // Closes every visible dialog box owned by the process; returns their titles.
 public static List<string> CloseDialogs(uint pid) {
  var o = new List<string>();
  EnumWindows((h, l) => {
   uint p; GetWindowThreadProcessId(h, out p);
   if (p == pid && IsWindowVisible(h)) {
    var c = new StringBuilder(64); GetClassName(h, c, 64);
    if (c.ToString() == "#32770") {
     var t = new StringBuilder(128); GetWindowText(h, t, 128); o.Add(t.ToString());
     PostMessage(h, 0x111, (IntPtr)1, IntPtr.Zero); PostMessage(h, 0x10, IntPtr.Zero, IntPtr.Zero);
    }
   }
   return true;
  }, IntPtr.Zero);
  return o;
 }
}
'@
}
[SimW]::SetProcessDPIAware() | Out-Null

function Get-SimSdk { (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim() }
function Get-SimHwnd { (Get-Process simulator -ErrorAction Stop | Where-Object MainWindowHandle -ne 0 | Select-Object -First 1).MainWindowHandle }
function Get-SimPanel { [SimW]::FindWindowEx((Get-SimHwnd), [IntPtr]::Zero, 'wxWindowNR', [NullString]::Value) }
function Get-SimDevice([string]$Device) { Get-Content "$env:APPDATA\Garmin\ConnectIQ\Devices\$Device\simulator.json" -Raw | ConvertFrom-Json }

# Lists every leaf of the menu bar: Path ("Settings > Language > German (deu)"), Id, Checked, Disabled.
function Get-SimMenu {
    param($Menu = [SimW]::GetMenu((Get-SimHwnd)), $Prefix = '')
    $n = [SimW]::GetMenuItemCount($Menu)
    for ($i = 0; $i -lt $n; $i++) {
        $sb = New-Object System.Text.StringBuilder 256
        [SimW]::GetMenuString($Menu, [uint32]$i, $sb, 256, 0x400) | Out-Null
        $name = ($sb.ToString() -replace '&', '') -replace "`t.*$", ''
        if (-not $name) { continue }
        $sub = [SimW]::GetSubMenu($Menu, $i)
        $state = [SimW]::GetMenuState($Menu, [uint32]$i, 0x400)
        if ($sub -ne [IntPtr]::Zero) { Get-SimMenu -Menu $sub -Prefix "$Prefix$name > " }
        else {
            [pscustomobject]@{ Path = "$Prefix$name"; Id = [SimW]::GetMenuItemID($Menu, $i)
                               Checked = [bool]($state -band 0x8); Disabled = [bool]($state -band 0x3) }
        }
    }
}

function Invoke-SimMenu([string]$Path) {
    $item = Get-SimMenu | Where-Object Path -eq $Path
    if (-not $item) { throw "menu item not found: $Path" }
    [SimW]::PostMessage((Get-SimHwnd), 0x111, [IntPtr][int]$item.Id, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds 500
}

function Stop-SimApp {
    Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object CommandLine -match 'MonkeyDoDeux' |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}

function Restart-Sim {
    Stop-SimApp
    Get-Process simulator -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
    Start-Process (Join-Path (Get-SimSdk) 'bin\simulator.exe')
    foreach ($i in 1..30) {
        Start-Sleep 1
        try { if (@(Get-SimMenu).Count -gt 100) { Start-Sleep 2; return } } catch {}
    }
    throw 'simulator did not come up'
}

# Pushes a .prg to the running simulator and waits for it to start.
function Start-SimApp([string]$Prg, [string]$Device, [int]$Wait = 12) {
    Stop-SimApp
    Start-Process -FilePath (Join-Path (Get-SimSdk) 'bin\monkeydo.bat') -ArgumentList $Prg, $Device -WindowStyle Hidden `
        -RedirectStandardOutput "$env:TEMP\monkeydo.out" -RedirectStandardError "$env:TEMP\monkeydo.err" | Out-Null
    Start-Sleep $Wait
}

# Logging a drink makes the simulator raise a modal "no data connection" box
# that swallows all input until it is closed.
function Close-SimDialogs {
    $t = [SimW]::CloseDialogs([uint32](Get-Process simulator).Id)
    if ($t.Count) { Start-Sleep -Milliseconds 500 }
    $t
}

# Captures the device panel. Image pixels are the device image's own
# coordinates, the same ones simulator.json and Send-SimClick use.
function Save-SimShot([string]$File) {
    $h = Get-SimPanel; $r = New-Object SimW+RECT; [SimW]::GetWindowRect($h, [ref]$r) | Out-Null
    $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
    [SimW]::PrintWindow($h, $dc, 2) | Out-Null; $g.ReleaseHdc($dc); $g.Dispose()
    $bmp.Save($File); $bmp.Dispose()
}

# Coarse fingerprint of the device panel (every 6th pixel), for telling whether a press changed the screen.
function Get-SimSignature {
    $h = Get-SimPanel; $r = New-Object SimW+RECT; [SimW]::GetWindowRect($h, [ref]$r) | Out-Null
    $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
    [SimW]::PrintWindow($h, $dc, 2) | Out-Null; $g.ReleaseHdc($dc); $g.Dispose()
    $sig = [System.Collections.Generic.List[int]]::new()
    for ($y = 0; $y -lt $bmp.Height; $y += 6) { for ($x = 0; $x -lt $bmp.Width; $x += 6) { $sig.Add($bmp.GetPixel($x, $y).ToArgb()) } }
    $bmp.Dispose()
    , $sig
}

# True when fewer than 0.2 % of the sampled pixels differ.
function Test-SimSameScreen($A, $B) {
    if ($A.Count -ne $B.Count) { return $false }
    $diff = 0; for ($i = 0; $i -lt $A.Count; $i++) { if ($A[$i] -ne $B[$i]) { $diff++ } }
    $diff * 500 -lt $A.Count
}

function Set-SimForeground {
    $h = Get-SimHwnd
    if ([SimW]::GetForegroundWindow() -eq $h) { return }
    # An Alt tap lifts the foreground lock for this process.
    [SimW]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [SimW]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [SimW]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 300
}

# Screen position of a device-image point.
function Get-SimScreenPoint([int]$X, [int]$Y) {
    $r = New-Object SimW+RECT; [SimW]::GetWindowRect((Get-SimPanel), [ref]$r) | Out-Null
    $scale = [SimW]::GetDpiForSystem() / [SimW]::GetDpiForWindow((Get-SimHwnd))
    @(($r.L + [int]($X * $scale)), ($r.T + [int]($Y * $scale)))
}

# Real mouse drag between two device-image points; a click when they are equal.
function Send-SimDrag([int]$X0, [int]$Y0, [int]$X1, [int]$Y1) {
    Set-SimForeground
    $a = Get-SimScreenPoint $X0 $Y0; $b = Get-SimScreenPoint $X1 $Y1
    $old = New-Object SimW+POINT; [SimW]::GetCursorPos([ref]$old) | Out-Null
    # The simulator only arms a button after it has seen the pointer move onto it.
    [SimW]::SetCursorPos($a[0] - 3, $a[1]) | Out-Null; Start-Sleep -Milliseconds 150
    1..3 | ForEach-Object { [SimW]::mouse_event(1, 1, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60 }
    Start-Sleep -Milliseconds 200
    [SimW]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
    try {
        if ($a[0] -eq $b[0] -and $a[1] -eq $b[1]) { Start-Sleep -Milliseconds 250 }
        else {
            Start-Sleep -Milliseconds 120
            foreach ($i in 1..8) {
                [SimW]::SetCursorPos($a[0] + [int](($b[0] - $a[0]) * $i / 8), $a[1] + [int](($b[1] - $a[1]) * $i / 8)) | Out-Null
                Start-Sleep -Milliseconds 30
            }
        }
    } finally {
        # Never leave the button held down or the pointer parked on the simulator.
        [SimW]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 80
        [SimW]::SetCursorPos($old.X, $old.Y) | Out-Null
    }
    Start-Sleep -Milliseconds 900
}

function Send-SimClick([int]$X, [int]$Y) { Send-SimDrag $X $Y $X $Y }

# Press a hardware button by its simulator.json id: enter, up, down, esc.
function Send-SimButton([string]$Device, [string]$Id) {
    $k = (Get-SimDevice $Device).keys | Where-Object { $_.id -eq $Id -and -not $_.isHold } | Select-Object -First 1
    if (-not $k) { throw "no button '$Id' on $Device" }
    Send-SimClick ($k.location.x + [int]($k.location.width / 2)) ($k.location.y + [int]($k.location.height / 2))
}

# Tap the screen at a percentage of the display (touch devices).
function Send-SimTap([string]$Device, [int]$PctX, [int]$PctY) {
    $l = (Get-SimDevice $Device).display.location
    Send-SimClick ($l.x + [int]($l.width * $PctX / 100)) ($l.y + [int]($l.height * $PctY / 100))
}

# Vertical swipe along the middle of the display, in percent of its height.
function Send-SimSwipe([string]$Device, [int]$FromPct, [int]$ToPct) {
    $l = (Get-SimDevice $Device).display.location
    $x = $l.x + [int]($l.width / 2)
    Send-SimDrag $x ($l.y + [int]($l.height * $FromPct / 100)) $x ($l.y + [int]($l.height * $ToPct / 100))
}
