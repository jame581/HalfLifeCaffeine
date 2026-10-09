#requires -Version 7
$ErrorActionPreference = 'Stop'
$build = Join-Path $PSScriptRoot 'build-translations.ps1'
$script:failed = 0
$head = 'key,where,context,max,english,translation,status'
$good = @(
    $head
    'Clear,glance,all clear,10,Clear,Selvä,'
    'SafeIn,glance,time left,14,Safe in $1$,$1$ jäljellä,'
    'Tea,watch companion,drink,,Tea & milk,Tee & maito,'
    'Limit,settings,title,,Daily limit,Päiväraja,'
) -join "`n"

function New-Fixture([string]$fi) {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('hlc-i18n-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path "$root/translations", "$root/companion/settings", "$root/resources" | Out-Null
    @(
        'key,where,context,max,text'
        'Clear,glance,all clear,10,Clear'
        'SafeIn,glance,time left,14,Safe in $1$'
        'Tea,watch companion,drink,,Tea & milk'
        'Limit,settings,title,,Daily limit'
    ) -join "`n" | Set-Content "$root/translations/en.csv" -Encoding utf8BOM
    if ($fi) { $fi | Set-Content "$root/translations/fi.csv" -Encoding utf8BOM }
    "<script>`n/* i18n:begin */`nvar I18N = {};`n/* i18n:end */`n</script>" |
        Set-Content "$root/companion/settings/index.html" -Encoding utf8NoBOM
    $root
}
function Invoke-Build([string]$root, [string[]]$extra = @()) {
    $out = & pwsh -NoProfile -File $build -Root $root @extra 2>&1 | Out-String
    [pscustomobject]@{ Code = $LASTEXITCODE; Out = $out }
}
function Check([string]$name, $ok) {
    # $ok is untyped on purpose: "$null -match x" yields an empty array, not a bool.
    if ($ok) { "PASS $name" } else { "FAIL $name"; $script:failed++ }
}

# 1. Complete language generates resources and the companion dictionary
$r = New-Fixture $good; $b = Invoke-Build $r
$xml = Get-Content "$r/resources-fin/strings.xml" -Raw -ErrorAction SilentlyContinue
$html = Get-Content "$r/companion/settings/index.html" -Raw
Check 'complete language exits 0' ($b.Code -eq 0)
Check 'glance strings are scoped' ($xml -match '<string id="Clear" scope="glance">Selvä</string>')
Check 'watch strings are unscoped' ($xml -match '<string id="Tea">')
Check 'settings-only strings are settings-scoped' ($xml -match '<string id="Limit" scope="settings">Päiväraja</string>')
Check 'ampersand is escaped in XML' ($xml -match 'Tee &amp; maito')
Check 'generated XML is well-formed' ($null -ne ([xml]$xml).strings)
Check 'english strings.xml is written' ((Get-Content "$r/resources/strings.xml" -Raw) -match '<string id="SafeIn" scope="glance">Safe in \$1\$</string>')
Check 'companion dictionary has only companion keys' ($html -match '"fi"' -and $html -match '"Tea"' -and $html -notmatch '"Clear"')
Check 'companion markers survive' ($html -match 'i18n:begin' -and $html -match '/\* i18n:end \*/')

# 2. Semicolon-delimited sheet (Excel in fi/cs locale)
$r = New-Fixture ($good -replace ',', ';'); $b = Invoke-Build $r
Check 'semicolon sheet is accepted' ($b.Code -eq 0 -and (Test-Path "$r/resources-fin/strings.xml"))

# 3. Missing key
$r = New-Fixture (($good -split "`n" | Where-Object { $_ -notmatch '^Tea,' }) -join "`n"); $b = Invoke-Build $r
Check 'missing key fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: missing key Tea')

# 4. Unknown key
$r = New-Fixture ($good + "`nGhost,watch,x,,Ghost,Aave,"); $b = Invoke-Build $r
Check 'unknown key fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: unknown key Ghost')

# 5. Dropped placeholder
$r = New-Fixture ($good -replace '\$1\$ jäljellä', 'jäljellä'); $b = Invoke-Build $r
Check 'dropped placeholder fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: SafeIn: placeholders differ')

# 6. Over-length
$r = New-Fixture ($good -replace 'Selvä', 'Aivan liian pitkä'); $b = Invoke-Build $r
Check 'over-length fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: Clear: 17 chars, max 10')

# 7. Incomplete language is skipped, unless required
$r = New-Fixture ($good -replace 'Selvä', ''); $b = Invoke-Build $r
Check 'incomplete language is skipped' ($b.Code -eq 0 -and $b.Out -match 'SKIPPED fi: 1 untranslated' -and -not (Test-Path "$r/resources-fin"))
$b = Invoke-Build $r @('-Require', 'fi')
Check 'required incomplete language fails' ($b.Code -eq 1 -and $b.Out -match 'fi: 1 untranslated')

# 8. -Sync creates sheets and flags changed English
$r = New-Fixture $good
(Get-Content "$r/translations/en.csv" -Raw) -replace 'Tea & milk', 'Tea with milk' | Set-Content "$r/translations/en.csv" -Encoding utf8BOM
$b = Invoke-Build $r @('-Sync')
$fiRows = Import-Csv "$r/translations/fi.csv" -Encoding utf8
Check 'sync keeps translation and flags changed English' (($fiRows | Where-Object key -eq 'Tea').status -eq 'changed' -and ($fiRows | Where-Object key -eq 'Tea').translation -eq 'Tee & maito')
Check 'sync creates missing sheets' (Test-Path "$r/translations/de.csv")

# 9. A sheet that is not UTF-8 (Excel's plain "CSV") is rejected and left untouched
$r = New-Fixture $good
$ansi = [System.Text.Encoding]::Latin1.GetBytes($good)
[System.IO.File]::WriteAllBytes("$r/translations/fi.csv", $ansi)
$b = Invoke-Build $r @('-Sync')
$after = [System.IO.File]::ReadAllBytes("$r/translations/fi.csv")
Check 'non-UTF-8 sheet fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: not UTF-8')
Check 'non-UTF-8 sheet is not overwritten by -Sync' ([System.Linq.Enumerable]::SequenceEqual($ansi, $after))
Check 'non-UTF-8 sheet generates nothing' (-not (Test-Path "$r/resources-fin"))

# 10. Duplicate key, script tag, and a failing run writes nothing
$r = New-Fixture ($good + "`nClear,glance,all clear,10,Clear,Selvä,"); $b = Invoke-Build $r
Check 'duplicate key fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: Clear: duplicate key')
$r = New-Fixture ($good -replace 'Tee & maito', '</script>'); $b = Invoke-Build $r
Check 'script tag fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: Tea: must not contain a script tag')
Check 'failing run writes no resources' (-not (Test-Path "$r/resources/strings.xml"))

if ($script:failed -gt 0) { "`n$($script:failed) FAILED"; exit 1 } else { "`nALL PASSED" }
