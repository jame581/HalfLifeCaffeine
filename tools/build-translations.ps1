#requires -Version 7
<#
.SYNOPSIS
  Validates translations/*.csv and generates the watch string resources and
  the companion page dictionary.
.EXAMPLE
  pwsh tools/build-translations.ps1                 # validate + generate
  pwsh tools/build-translations.ps1 -Sync           # refresh language sheets from en.csv first
  pwsh tools/build-translations.ps1 -Require fi,cs  # fail if these languages are incomplete
#>
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [switch]$Sync,
    [string[]]$Require = @()
)
$ErrorActionPreference = 'Stop'

$LangMap = [ordered]@{ fi = 'fin'; cs = 'ces'; de = 'deu'; fr = 'fre' }
$Wheres  = 'watch', 'glance', 'settings', 'companion'
$Require = @($Require | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$tDir    = Join-Path $Root 'translations'
$errors  = [System.Collections.Generic.List[string]]::new()
$utf8    = [System.Text.UTF8Encoding]::new($false)
# A language is "shipped" when its watch resources already exist at the start of the run.
$shipped = @($LangMap.Keys | Where-Object { Test-Path (Join-Path $Root "resources-$($LangMap[$_])/strings.xml") })

function Read-Sheet([string]$path) {
    # Strict UTF-8. Excel's plain "CSV" in a fi/cs locale is Windows-125x; decoded
    # leniently it turns into U+FFFD, which -Sync would then write back for good.
    try {
        $text = [System.Text.UTF8Encoding]::new($false, $true).GetString([System.IO.File]::ReadAllBytes($path))
    } catch {
        Write-Host "ERROR $([System.IO.Path]::GetFileNameWithoutExtension($path)): not UTF-8. Save the sheet as 'CSV UTF-8'."
        exit 1
    }
    $text = $text.TrimStart([char]0xFEFF)
    $first = ($text -split "`r?`n", 2)[0]
    $delim = if ($first.Split(';').Count -gt $first.Split(',').Count) { ';' } else { ',' }
    @($text | ConvertFrom-Csv -Delimiter $delim)
}
function Get-Placeholders([string]$s) {
    ([regex]::Matches($s, '\$\d\$') | ForEach-Object Value | Sort-Object) -join ' '
}
function Get-Where($row) { @("$($row.where)" -split '\s+' | Where-Object { $_ }) }
function Escape-Xml([string]$s) { $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;') }
function Write-Text([string]$path, [string]$text) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($path, $text, $utf8)
}

# --- English master -------------------------------------------------------
$en = Read-Sheet (Join-Path $tDir 'en.csv')
$known = @{}
foreach ($r in $en) {
    if ($r.key -notmatch '^[A-Z][A-Za-z0-9]*$') { $errors.Add("en: bad key '$($r.key)'"); continue }
    if ($known.ContainsKey($r.key)) { $errors.Add("en: $($r.key): duplicate key") }
    $known[$r.key] = $true
    $w = Get-Where $r
    if ($w.Count -eq 0 -or @($w | Where-Object { $_ -notin $Wheres }).Count -gt 0) {
        $errors.Add("en: $($r.key): bad where '$($r.where)'")
    }
    if ($r.max -and $r.max -notmatch '^\d+$') { $errors.Add("en: $($r.key): max '$($r.max)' is not a number"); $r.max = '' }
    if ([string]::IsNullOrEmpty($r.text)) { $errors.Add("en: $($r.key): empty text") }
    elseif ($r.max -and $r.text.Length -gt [int]$r.max) {
        $errors.Add("en: $($r.key): $($r.text.Length) chars, max $($r.max)")
    }
}

# --- Optional: refresh language sheets from the master ----------------------
if ($Sync) {
    # Check the existing sheets first: the rebuild below drops unknown keys and
    # collapses duplicates, so those errors would never be seen afterwards.
    foreach ($lang in $LangMap.Keys) {
        $path = Join-Path $tDir "$lang.csv"
        if (-not (Test-Path $path)) { continue }
        $seen = @{}
        foreach ($r in Read-Sheet $path) {
            if ($seen.ContainsKey($r.key)) { $errors.Add("${lang}: $($r.key): duplicate key") }
            $seen[$r.key] = $true
            if (-not $known.ContainsKey($r.key)) { $errors.Add("${lang}: unknown key $($r.key)") }
        }
    }
    if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Host "ERROR $_" }
        exit 1
    }
    foreach ($lang in $LangMap.Keys) {
        $path = Join-Path $tDir "$lang.csv"
        $old = @{}
        if (Test-Path $path) { foreach ($r in Read-Sheet $path) { $old[$r.key] = $r } }
        $rows = foreach ($r in $en) {
            $o = $old[$r.key]
            $translation = if ($o) { "$($o.translation)" } else { '' }
            $status = if ($o) { "$($o.status)" } else { '' }
            if ($o -and $translation -and "$($o.english)" -ne $r.text) { $status = 'changed' }
            [pscustomobject][ordered]@{
                key = $r.key; where = $r.where; context = $r.context; max = $r.max
                english = $r.text; translation = $translation; status = $status
            }
        }
        $rows | Export-Csv -LiteralPath $path -Encoding utf8BOM -UseQuotes Always
    }
}

# --- Language sheets -------------------------------------------------------
$complete = [ordered]@{}
foreach ($lang in $LangMap.Keys) {
    $path = Join-Path $tDir "$lang.csv"
    if (-not (Test-Path $path)) {
        if ($lang -in $Require) { $errors.Add("${lang}: sheet missing") }
        continue
    }
    $map = @{}
    foreach ($r in Read-Sheet $path) {
        if ($map.ContainsKey($r.key)) { $errors.Add("${lang}: $($r.key): duplicate key") }
        $map[$r.key] = $r
    }
    foreach ($k in $map.Keys) { if (-not $known.ContainsKey($k)) { $errors.Add("${lang}: unknown key $k") } }
    $missing = 0
    $texts = @{}
    foreach ($r in $en) {
        $row = $map[$r.key]
        if (-not $row) { $errors.Add("${lang}: missing key $($r.key)"); continue }
        $tr = "$($row.translation)".Trim()
        if ($tr -eq '') { $missing++; $texts[$r.key] = $r.text; continue }
        # Translations are written into a <script> block of the companion page.
        if ($tr -match '<\s*/?\s*script') { $errors.Add("${lang}: $($r.key): must not contain a script tag") }
        if ((Get-Placeholders $tr) -ne (Get-Placeholders $r.text)) {
            $errors.Add("${lang}: $($r.key): placeholders differ from English")
        }
        if ($r.max -and $tr.Length -gt [int]$r.max) {
            $errors.Add("${lang}: $($r.key): $($tr.Length) chars, max $($r.max)")
        }
        $texts[$r.key] = $tr
    }
    if ($missing -gt 0) {
        if ($lang -in $Require) { $errors.Add("${lang}: $missing untranslated strings"); continue }
        elseif ($lang -in $shipped) { Write-Host "WARNING ${lang}: $missing untranslated strings, English used" }
        else { Write-Host "SKIPPED ${lang}: $missing untranslated strings"; continue }
    }
    $complete[$lang] = $texts
}

$htmlPath = Join-Path $Root 'companion/settings/index.html'
$html = [System.IO.File]::ReadAllText($htmlPath)
$pattern = '(?s)/\* i18n:begin.*?/\* i18n:end \*/'
if ($html -notmatch $pattern) { $errors.Add('companion: page has no i18n markers') }

# No resource or page is written unless every check above passed. Under -Sync the
# sheets are rewritten earlier, but only after the key checks passed.
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "ERROR $_" }
    exit 1
}

# --- Generate watch resources ---------------------------------------------
function Build-StringsXml($texts) {
    $lines = @(
        '<!-- Generated by tools/build-translations.ps1 from translations/*.csv. Do not edit. -->'
        '<strings>'
    )
    foreach ($r in $en) {
        $w = Get-Where $r
        if (@($w | Where-Object { $_ -in 'watch', 'glance', 'settings' }).Count -eq 0) { continue }
        # glance: needed by the glance process. settings: phone-only, kept out of
        # the watch runtime to save memory on 64 KB devices.
        $scope = if ($w -contains 'glance') { ' scope="glance"' }
                 elseif (($w -join ' ') -eq 'settings') { ' scope="settings"' }
                 else { '' }
        $lines += "  <string id=`"$($r.key)`"$scope>$(Escape-Xml $texts[$r.key])</string>"
    }
    $lines += '</strings>'
    ($lines -join "`n") + "`n"
}
$enTexts = @{}
foreach ($r in $en) { $enTexts[$r.key] = $r.text }
Write-Text (Join-Path $Root 'resources/strings.xml') (Build-StringsXml $enTexts)
foreach ($lang in $complete.Keys) {
    Write-Text (Join-Path $Root "resources-$($LangMap[$lang])/strings.xml") (Build-StringsXml $complete[$lang])
}

# --- Generate the companion dictionary ---------------------------------------
$all = [ordered]@{ en = $enTexts }
foreach ($lang in $complete.Keys) { $all[$lang] = $complete[$lang] }
$dict = [ordered]@{}
foreach ($lang in $all.Keys) {
    $d = [ordered]@{}
    foreach ($r in $en) { if ((Get-Where $r) -contains 'companion') { $d[$r.key] = $all[$lang][$r.key] } }
    $dict[$lang] = $d
}
$nl = if ($html.Contains("`r`n")) { "`r`n" } else { "`n" }
$json = ($dict | ConvertTo-Json -Depth 3) -replace "`r?`n", $nl
$block = "/* i18n:begin - generated by tools/build-translations.ps1, do not edit */${nl}var I18N = $json;${nl}/* i18n:end */"
$html = [regex]::Replace($html, $pattern, [System.Text.RegularExpressions.MatchEvaluator] { param($m) $block })
Write-Text $htmlPath $html

Write-Host ('Generated: ' + (@($all.Keys) -join ', '))
