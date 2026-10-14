#requires -Version 7
<#
.SYNOPSIS
Walks every screen of the widget in the Connect IQ simulator and writes one
contact sheet (PNG) per device and language.

.DESCRIPTION
For each device: builds a simulator binary, restarts the simulator, optionally
logs worst-case drinks, then for each language opens the glance, the four
screens and the menus and screenshots each one.

The script takes over the mouse while it runs (the simulator ignores synthetic
input), so leave the machine alone until it finishes. About 90 seconds per
device and language.

Test builds use a 1000 mg default daily limit so that the intake line shows its
widest value; resources/properties.xml is restored afterwards.

Known limits: watches without glances (vivoactive4) show the widget as a page of
the widget loop, where paging leaves it, so only the summary and the add menu
are captured there. A press that changes nothing on screen is repeated once; if
a sheet still ends up out of step, rerun that device.

.EXAMPLE
pwsh tools/sim-matrix.ps1 -Devices fr255s,fenix9pro51mm -Langs en,de,fr,fi -Seed
#>
param(
    # Keep vivoactive4 last: the next device loaded after it throws the app and its data away.
    [string[]]$Devices = @('fr255s', 'fenix9pro51mm', 'fenix6', 'vivoactive5', 'vivoactive4'),
    [string[]]$Langs = @('en', 'de', 'fr', 'fi'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\bin\sim-matrix'),
    [string]$Key = 'D:/Garmin/Key/developer_key',
    # Delete the simulator's app data and log four of the last preset (Pre-Workout, 800 mg)
    # on the first device. The simulator keeps one data file for the app, so the
    # other devices see the same drinks; put a watch with an UP button first.
    [switch]$Seed,
    # Reuse the binaries from a previous run.
    [switch]$NoBuild
)

# "pwsh -File ... -Langs en,fi" delivers one string; accept that form too.
$Devices = @($Devices | ForEach-Object { $_ -split ',' })
$Langs = @($Langs | ForEach-Object { $_ -split ',' })

. "$PSScriptRoot\sim-lib.ps1"
# monkeydo keeps this script's output pipe open; never leave it behind.
trap { Stop-SimApp; break }
$root = (Resolve-Path "$PSScriptRoot\..").Path
$binDir = Join-Path $root 'bin\sim'
New-Item -ItemType Directory -Force $OutDir, $binDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$langMenu = @{ en = 'English (eng)'; de = 'German (deu)'; fr = 'French (fre)'; fi = 'Finnish (fin)'; cs = 'Czech (ces)' }
$unknown = $Langs | Where-Object { -not $langMenu.ContainsKey($_) }
if ($unknown) { throw "unknown language code: $($unknown -join ', ')" }

if (-not $NoBuild) {
    $props = Join-Path $root 'resources\properties.xml'
    # A run that was killed mid-build leaves the 1000 mg default behind; never build on top of that.
    git -C $root diff --quiet -- resources/properties.xml
    if ($LASTEXITCODE -ne 0) { throw 'resources/properties.xml has uncommitted changes; restore it first (git checkout -- resources/properties.xml)' }
    $orig = Get-Content $props -Raw
    $limit = '<property id="dailyLimit" type="number">400</property>'
    if (-not $orig.Contains($limit)) { throw 'dailyLimit default not found in resources/properties.xml' }
    try {
        Set-Content $props $orig.Replace($limit, $limit.Replace('400', '1000')) -NoNewline
        foreach ($d in $Devices) {
            $o = & (Join-Path (Get-SimSdk) 'bin\monkeyc.bat') -f (Join-Path $root 'monkey.jungle') -d $d -y $Key -o (Join-Path $binDir "$d.prg") 2>&1
            if ($LASTEXITCODE -ne 0 -or -not ($o -match 'BUILD SUCCESSFUL')) { throw "build failed for ${d}: $($o | Select-Object -Last 3)" }
        }
    } finally { Set-Content $props $orig -NoNewline }
}

function Save-Sheet([string]$File, [string]$Dir, [string[]]$Names, $Disp) {
    $cell = [Math]::Min(300, $Disp.width); $pad = 8; $label = 22; $cols = 5
    $rows = [Math]::Ceiling($Names.Count / $cols)
    $sheet = New-Object System.Drawing.Bitmap ($cols * ($cell + $pad) + $pad), ($rows * ($cell + $label + $pad) + $pad)
    $g = [System.Drawing.Graphics]::FromImage($sheet); $g.Clear([System.Drawing.Color]::FromArgb(40, 40, 40))
    $g.InterpolationMode = 'HighQualityBicubic'
    $font = New-Object System.Drawing.Font 'Segoe UI', 10
    for ($i = 0; $i -lt $Names.Count; $i++) {
        $src = [System.Drawing.Image]::FromFile("$Dir\$($Names[$i]).png")
        $x = $pad + ($i % $cols) * ($cell + $pad); $y = $pad + [Math]::Floor($i / $cols) * ($cell + $label + $pad)
        $g.DrawString($Names[$i], $font, [System.Drawing.Brushes]::White, $x, $y)
        $g.DrawImage($src, (New-Object System.Drawing.Rectangle $x, ($y + $label), $cell, $cell),
                     (New-Object System.Drawing.Rectangle $Disp.x, $Disp.y, $Disp.width, $Disp.height), 'Pixel')
        $src.Dispose()
    }
    $g.Dispose(); $sheet.Save($File); $sheet.Dispose()
}

# Every device's binary is pushed under one name, so they all use one data file.
$runPrg = Join-Path $binDir 'run\HLMATRIX.prg'
$simFs = "$env:TEMP\com.garmin.connectiq\GARMIN"
New-Item -ItemType Directory -Force (Split-Path $runPrg) | Out-Null

function StopSim { Stop-SimApp; Get-Process simulator -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 1 }
# File > Reset All App Data leaves the logged drinks in place, so delete the
# simulator's storage and settings files instead (all sideloaded apps share
# them). A settings file left by an older build would keep its property defaults.
function ClearAppData {
    Remove-Item "$simFs\APPS\DATA\*.DAT", "$simFs\APPS\DATA\*.IDX", "$simFs\APPS\DATA\*.IMT", "$simFs\APPS\SETTINGS\*.SET", "$simFs\Settings\*-settings.*" `
        -ErrorAction SilentlyContinue -Confirm:$false
}
$seedNow = [bool]$Seed
foreach ($Device in $Devices) {
    Copy-Item (Join-Path $binDir "$Device.prg") $runPrg -Force
    $prg = $runPrg
    $dev = Get-SimDevice $Device
    $disp = $dev.display.location
    $hasKey = @{}; foreach ($k in $dev.keys) { if ($k.behavior -and -not $k.isHold) { $hasKey[$k.id] = $true } }
    $compiler = Get-Content "$env:APPDATA\Garmin\ConnectIQ\Devices\$Device\compiler.json" -Raw | ConvertFrom-Json
    $hasGlance = [bool]($compiler.appTypes | Where-Object type -eq 'glance')

    # The simulator now and then ignores a press. Every press in the walk changes
    # the screen, so press once more when nothing moved.
    function Press([scriptblock]$Action) {
        $null = Close-SimDialogs
        $before = Get-SimSignature
        & $Action
        # Menus on the larger AMOLED watches take longer than 300 ms to start moving;
        # repeating too early sends the press twice.
        foreach ($i in 1..6) {
            Start-Sleep -Milliseconds 250
            if (-not (Test-SimSameScreen $before (Get-SimSignature))) { return }
        }
        & $Action
    }
    # "Select" and "Next" are PowerShell aliases; keep the Press prefix.
    function PressNext     { Press { if ($hasKey['down'])  { Send-SimButton $Device down }  else { Send-SimSwipe $Device 72 25 } } }
    function PressSelect   { Press { if ($hasKey['enter']) { Send-SimButton $Device enter } else { Send-SimTap $Device 50 50 } } }
    # In a menu, touch-only watches need a tap on the first row.
    function PressMenuItem { Press { if ($hasKey['down'])  { Send-SimButton $Device enter } else { Send-SimTap $Device 50 42 } } }
    function PressBack     { Press { Send-SimButton $Device esc } }
    # History's chart bars are the only ACCENT green in the upper half of the
    # screen; the log draws none. Loose bounds, since MIP watches show fewer colors.
    function Test-HistoryShown {
        $file = Join-Path $env:TEMP 'sim-matrix-probe.png'
        Save-SimShot $file
        $bmp = [System.Drawing.Bitmap]::FromFile($file); $n = 0
        try {
            for ($y = $disp.y + $disp.height * 15 / 100; $y -lt $disp.y + $disp.height * 55 / 100; $y += 2) {
                for ($x = $disp.x + $disp.width * 10 / 100; $x -lt $disp.x + $disp.width * 90 / 100; $x += 2) {
                    $c = $bmp.GetPixel([int]$x, [int]$y)
                    if ($c.G -gt 150 -and $c.G - $c.R -gt 80 -and $c.B -lt $c.G) { $n++ }
                }
            }
        } finally { $bmp.Dispose() }
        $n -ge 15
    }
    # On a button watch DOWN moves the log cursor and pages to History only past
    # the last row, so press until the chart shows.
    function PressToHistory {
        if (-not $hasKey['down']) { PressNext; return }
        foreach ($i in 1..30) {
            Send-SimButton $Device down; Start-Sleep -Milliseconds 400; $null = Close-SimDialogs
            if (Test-HistoryShown) { return }
        }
        throw "History did not appear after 30 presses of DOWN"
    }
    function Shot([string]$Name) {
        Start-Sleep -Milliseconds 500; $null = Close-SimDialogs
        Save-SimShot "$script:dir\$Name.png"; $script:shots += $Name
    }
    # Loads the device too, which the language list needs.
    function Launch([string]$Mode) {
        if ($hasGlance) {
            # A restarted simulator lists Glance Launch Mode only once a glance device is
            # loaded, and does not always come back with this one; starting the app loads it.
            $item = "Settings > Glance Launch Mode > Launch in $Mode Mode"
            if (-not (Get-SimMenu | Where-Object Path -eq $item)) { Start-SimApp $prg $Device; $null = Close-SimDialogs }
            Invoke-SimMenu $item
        }
        Start-SimApp $prg $Device; $null = Close-SimDialogs
    }

    if ($seedNow) {
        $seedNow = $false
        StopSim; ClearAppData
        Restart-Sim; Launch 'Normal'
        # Default drink names are seeded in the current language; start over in English.
        Invoke-SimMenu 'Settings > Language > English (eng)'
        Invoke-SimMenu 'File > Kill App'; Start-Sleep 1; ClearAppData
        Launch 'Normal'
        foreach ($n in 1..4) {
            PressSelect
            Press { if ($hasKey['up']) { Send-SimButton $Device up } else { Send-SimSwipe $Device 30 75 } }
            # The "no data connection" box can take a moment to appear and would swallow the next press.
            PressMenuItem; Start-Sleep 2; $null = Close-SimDialogs; Start-Sleep 1; $null = Close-SimDialogs
        }
    }

    foreach ($lang in $Langs) {
        $script:dir = "$OutDir\$Device-$lang"; New-Item -ItemType Directory -Force $dir | Out-Null; $script:shots = @()
        Restart-Sim; Launch 'Normal'
        Invoke-SimMenu "Settings > Language > $($langMenu[$lang])"
        if ($hasGlance -and $hasKey['down']) {
            # Started directly, the simulator treats a button watch's widget as a page of
            # the old widget loop and DOWN leaves it. Open it from the glance list instead,
            # as on the watch: DOWN brings the glance into focus, START opens it.
            Launch 'Glance'; Shot '0-glance'
            PressNext; PressSelect; Start-Sleep 2; Shot '1-summary'
        } elseif ($hasGlance) {
            Launch 'Glance'; Shot '0-glance'
            Launch 'Normal'; Shot '1-summary'
        } else {
            Launch 'Normal'; Shot '1-summary'
        }
        PressSelect; Shot '2-add-menu'
        PressBack
        # Without glances the widget is a page of the widget loop and paging leaves it.
        if ($hasGlance) {
            PressNext; Shot '3-timeline'
            PressNext; Shot '4-log'
            PressSelect; Shot '5-edit-menu'
            PressMenuItem; Shot '6-edit-time'
            PressBack; PressBack
            PressToHistory; Shot '7-history'
            PressSelect; Shot '8-day-detail'
            PressBack
        }
        Save-Sheet "$OutDir\$Device-$lang.png" $dir $shots $disp
        "$Device $lang : $OutDir\$Device-$lang.png"
    }
}
Stop-SimApp
