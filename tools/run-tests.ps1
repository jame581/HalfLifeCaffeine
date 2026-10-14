#requires -Version 7
<#
.SYNOPSIS
Builds the unit tests and runs them in the Connect IQ simulator.

.DESCRIPTION
Uses test.jungle, which adds test/ to the source path; monkey.jungle does not,
so "Run Tests" in VS Code builds a binary with no tests in it.

The simulator is restarted first. No mouse or keyboard input is used.
Exit code 0 when every test passes, 1 otherwise.

The tests are built with type checking off (-l 0): two older tests do not pass
the type checker.

.EXAMPLE
pwsh tools/run-tests.ps1
pwsh tools/run-tests.ps1 -Device fr255s
#>
param(
    [string]$Device = 'vivoactive5',
    [string]$Key = 'D:/Garmin/Key/developer_key',
    [int]$TimeoutSeconds = 180
)

. "$PSScriptRoot\sim-lib.ps1"
$root = (Resolve-Path "$PSScriptRoot\..").Path
$sdk = Get-SimSdk
$outDir = Join-Path $root 'bin\test'
New-Item -ItemType Directory -Force $outDir | Out-Null
$prg = Join-Path $outDir "$Device.prg"

$build = & (Join-Path $sdk 'bin\monkeyc.bat') -f (Join-Path $root 'test.jungle') -d $Device -y $Key -o $prg -t -l 0 2>&1
if ($LASTEXITCODE -ne 0 -or -not ($build -match 'BUILD SUCCESSFUL')) {
    $build | Where-Object { $_ -match 'ERROR' } | Write-Host
    Write-Host 'test build failed'; exit 1
}

Restart-Sim
# monkeydo.bat only accepts the test flag as "/t"; call the runner directly.
$job = Start-Job {
    param($sdk, $prg, $device)
    & java -classpath "$sdk\bin\monkeybrains.jar" com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux `
        -f $prg -d $device -s "$sdk\bin\shell.exe" -t 2>&1
} -ArgumentList $sdk, $prg, $Device
$null = Wait-Job $job -Timeout $TimeoutSeconds
$timedOut = $job.State -eq 'Running'
if ($timedOut) { Stop-Job $job; Stop-SimApp }
$out = @(Receive-Job $job | ForEach-Object { "$_" })
Remove-Job $job -Force

$results = $out | Where-Object { $_ -match '^\w+\s+(PASS|FAIL|ERROR)$' }
# Each test prints "Executing test <name>...", what went wrong, then PASS/FAIL/ERROR.
for ($i = 0; $i -lt $out.Count; $i++) {
    if ($out[$i] -match '^(FAIL|ERROR)$') {
        $from = $i
        while ($from -gt 0 -and $out[$from] -notmatch '^Executing test') { $from-- }
        $out[$from..($i - 1)] | Where-Object { $_.Trim() } | Write-Host
    }
}
$summary = $out | Where-Object { $_ -match '^(PASSED|FAILED) \(' } | Select-Object -Last 1
if ($timedOut) { Write-Host "timed out after $TimeoutSeconds s"; $out | Select-Object -Last 20 | Write-Host; exit 1 }
if (-not $summary) { Write-Host 'no test results; runner output:'; $out | Select-Object -Last 20 | Write-Host; exit 1 }
Write-Host "$(@($results).Count) tests: $summary"
if ($summary -match '^PASSED') { exit 0 } else { exit 1 }
