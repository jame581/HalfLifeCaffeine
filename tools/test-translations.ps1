#requires -Version 7
$ErrorActionPreference = 'Stop'
$build = Join-Path $PSScriptRoot 'build-translations.ps1'
$script:failed = 0
$head = 'key,where,context,max,english,example,translation,status'
$good = @(
    $head
    'Clear,glance,all clear,10,Clear,,Selvä,'
    'SafeIn,glance,time left,20,Safe in $1$,,$1$ jäljellä,'
    'Tea,watch companion,drink,,Tea & milk,,Tee & maito,'
    'Limit,settings,title,,Daily limit,,Päiväraja,'
    'UnitHour,watch,unit,,h,,t,'
    'UnitMinute,watch,unit,,m,,min,'
) -join "`n"

function New-Fixture([string]$fi) {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('hlc-i18n-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path "$root/translations", "$root/companion/settings", "$root/resources" | Out-Null
    @(
        'key,where,context,max,sample,text'
        'Clear,glance,all clear,10,,Clear'
        'SafeIn,glance,time left,20,{duration},Safe in $1$'
        'Tea,watch companion,drink,,,Tea & milk'
        'Limit,settings,title,,,Daily limit'
        'UnitHour,watch,unit,,,h'
        'UnitMinute,watch,unit,,,m'
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
$r = New-Fixture ($good + "`nGhost,watch,x,,Ghost,,Aave,"); $b = Invoke-Build $r
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
$r = New-Fixture ($good + "`nClear,glance,all clear,10,Clear,,Selvä,"); $b = Invoke-Build $r
Check 'duplicate key fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: Clear: duplicate key')
$r = New-Fixture ($good -replace 'Tee & maito', '</script>'); $b = Invoke-Build $r
Check 'script tag fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: Tea: must not contain a script tag')
Check 'failing run writes no resources' (-not (Test-Path "$r/resources/strings.xml"))

# 11. Duplicated placeholder
$r = New-Fixture ($good.Replace('$1$ jäljellä', '$1$ $1$')); $b = Invoke-Build $r
Check 'duplicated placeholder fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: SafeIn: placeholders differ')

# 12. A shipped language that becomes incomplete keeps building with English text
$r = New-Fixture ($good -replace 'Selvä', '')
New-Item -ItemType Directory -Path "$r/resources-fin" | Out-Null
'<strings></strings>' | Set-Content "$r/resources-fin/strings.xml"
$b = Invoke-Build $r
$xml = Get-Content "$r/resources-fin/strings.xml" -Raw
$html = Get-Content "$r/companion/settings/index.html" -Raw
Check 'shipped incomplete language exits 0 with a warning' ($b.Code -eq 0 -and $b.Out -match 'WARNING fi: 1 untranslated strings, English used')
Check 'shipped incomplete language uses English for the gap' ($xml -match '<string id="Clear" scope="glance">Clear</string>' -and $xml -match '<string id="Tea">Tee &amp; maito</string>')
Check 'shipped incomplete language stays in the companion dictionary' ($html -match '"fi"')
$b = Invoke-Build $r @('-Require', 'fi')
Check 'required shipped incomplete language fails' ($b.Code -eq 1 -and $b.Out -match 'ERROR fi: 1 untranslated strings')

# 13. -Sync validates before rewriting any sheet
foreach ($case in @(
    @{ Name = 'unknown key'; Sheet = $good + "`nGhost,watch,x,,Ghost,,Aave,"; Pattern = 'fi: unknown key Ghost' }
    @{ Name = 'duplicate key'; Sheet = $good + "`nClear,glance,all clear,10,Clear,,Selvä,"; Pattern = 'fi: Clear: duplicate key' }
)) {
    $r = New-Fixture $case.Sheet
    $before = [System.IO.File]::ReadAllBytes("$r/translations/fi.csv")
    $b = Invoke-Build $r @('-Sync')
    $after = [System.IO.File]::ReadAllBytes("$r/translations/fi.csv")
    Check "-Sync with $($case.Name) fails and is named" ($b.Code -eq 1 -and $b.Out -match $case.Pattern)
    Check "-Sync with $($case.Name) leaves the sheet unchanged" ([System.Linq.Enumerable]::SequenceEqual($before, $after))
}

# 14. max is measured on the filled-in text, with the language's own units
$r = New-Fixture ($good -replace '\$1\$ jäljellä', 'Turvallinen $1$'); $b = Invoke-Build $r
Check 'template that is too long once filled in fails and is named' ($b.Code -eq 1 -and $b.Out -match 'fi: SafeIn: 21 chars when filled in \("Turvallinen 23t 59min"\), max 20')
$r = New-Fixture ($good -replace ',,min,', ',,minuuttia,'); $b = Invoke-Build $r
Check '{duration} uses the language units (longer UnitMinute fails)' ($b.Code -eq 1 -and $b.Out -match 'fi: SafeIn: \d+ chars when filled in')
$r = New-Fixture $good
(Get-Content "$r/translations/en.csv" -Raw) -replace 'Safe in', 'Safe and sound in' -replace ',20,', ',15,' | Set-Content "$r/translations/en.csv" -Encoding utf8BOM
$b = Invoke-Build $r
Check 'English text is measured filled in too' ($b.Code -eq 1 -and $b.Out -match 'en: SafeIn: 25 chars when filled in \("Safe and sound in 23h 59m"\), max 15')

# 15. Samples in en.csv
$r = New-Fixture $good
(Get-Content "$r/translations/en.csv" -Raw) -replace '\{duration\}', '' | Set-Content "$r/translations/en.csv" -Encoding utf8BOM
$b = Invoke-Build $r
Check 'placeholders without a sample fail and are named' ($b.Code -eq 1 -and $b.Out -match 'en: SafeIn: has placeholders but no sample')
$r = New-Fixture $good
(Get-Content "$r/translations/en.csv" -Raw) -replace '\{duration\}', '1|2' | Set-Content "$r/translations/en.csv" -Encoding utf8BOM
$b = Invoke-Build $r
Check 'sample with the wrong number of parts fails and is named' ($b.Code -eq 1 -and $b.Out -match 'en: SafeIn: sample has 2 parts')

# 16. -Sync writes the example column
$r = New-Fixture $good; $b = Invoke-Build $r @('-Sync')
$fiRows = Import-Csv "$r/translations/fi.csv" -Encoding utf8
Check '-Sync writes the filled English text into example' ($b.Code -eq 0 -and ($fiRows | Where-Object key -eq 'SafeIn').example -eq 'Safe in 23h 59m' -and ($fiRows | Where-Object key -eq 'Clear').example -eq '')
Check '-Sync keeps the translation next to the example column' (($fiRows | Where-Object key -eq 'SafeIn').translation -eq '$1$ jäljellä')

# 17. Stale translations
$stale = $good -replace 'Tee & maito,', 'Tee & maito,changed'
$r = New-Fixture $stale; $b = Invoke-Build $r
Check 'changed row with a translation warns and exits 0' ($b.Code -eq 0 -and $b.Out -match 'WARNING fi: Tea: English changed since this was translated')
$r = New-Fixture $stale; $b = Invoke-Build $r @('-Require', 'fi')
Check 'changed row under -Require fails and is named' ($b.Code -eq 1 -and $b.Out -match 'ERROR fi: Tea: English changed since this was translated')
Check 'changed row under -Require writes no resources' (-not (Test-Path "$r/resources/strings.xml") -and -not (Test-Path "$r/resources-fin"))
$r = New-Fixture ($good -replace 'Tee & maito,', ',changed'); $b = Invoke-Build $r
Check 'changed row without a translation does not warn as stale' ($b.Out -notmatch 'English changed')

# 18. -Require with an unknown language code
$r = New-Fixture $good
$before = [System.IO.File]::ReadAllBytes("$r/translations/fi.csv")
$b = Invoke-Build $r @('-Sync', '-Require', 'fi,xx')
$after = [System.IO.File]::ReadAllBytes("$r/translations/fi.csv")
Check 'unknown -Require code fails and is named' ($b.Code -eq 1 -and $b.Out -match "ERROR -Require: unknown language 'xx' \(known: fi, cs, de, fr\)")
Check 'unknown -Require code under -Sync rewrites no sheet' ([System.Linq.Enumerable]::SequenceEqual($before, $after) -and -not (Test-Path "$r/translations/de.csv"))
Check 'unknown -Require code generates nothing' (-not (Test-Path "$r/resources/strings.xml"))

# 19. English text with a script tag
$r = New-Fixture $good
(Get-Content "$r/translations/en.csv" -Raw) -replace 'Tea & milk', '</script>' | Set-Content "$r/translations/en.csv" -Encoding utf8BOM
$b = Invoke-Build $r
Check 'English script tag fails and is named' ($b.Code -eq 1 -and $b.Out -match 'en: Tea: must not contain a script tag')

if ($script:failed -gt 0) { "`n$($script:failed) FAILED"; exit 1 } else { "`nALL PASSED" }
