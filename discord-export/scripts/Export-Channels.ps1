<#
.SYNOPSIS
  Export one or more channels to JSON.
.PARAMETER ChannelId
  One or more channel IDs to export.
.PARAMETER After
  From date (REQUIRED), e.g. 2026-01-31 or an ISO date-time. Maps to --after.
.PARAMETER Before
  To date (optional). Omit for "up to now". Maps to --before.
.PARAMETER OutDir
  Output directory. Defaults to %TEMP%\discord-export\<timestamp>\.
  A trailing slash is enforced (the exporter requires it for directory outputs).
.DESCRIPTION
  Exports each channel with its own call, format Json. A single channel failure is
  reported and the batch continues. Never prints the token.
  Prints a JSON summary [{channelId,status,file|error}, ...] at the end.
#>
param(
    [Parameter(Mandatory)][string[]]$ChannelId,
    [Parameter(Mandatory)][string]$After,
    [string]$Before,
    [string]$OutDir
)
. "$PSScriptRoot\_common.ps1"

try {
    $exe = Get-Exporter
    $token = Get-Token
} catch {
    [Console]::Error.WriteLine($_.Exception.Message); exit 1
}

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutDir = Join-Path $env:TEMP "discord-export\$stamp"
}
New-Item -ItemType Directory -Force $OutDir | Out-Null
# Exporter requires directory output paths to end with a slash.
$outArg = $OutDir.TrimEnd('\', '/') + '\'

$results = @()
foreach ($cid in $ChannelId) {
    $existingFiles = (Get-ChildItem -LiteralPath $OutDir -ea 0 | Where-Object { $_.Name -like '*.json' }).Name
    $args = @('export', '-t', $token, '-c', $cid, '-f', 'Json', '--include-threads', 'All', '--after', $After, '-o', $outArg, '--fuck-russia')
    if (-not [string]::IsNullOrWhiteSpace($Before)) { $args += @('--before', $Before) }
    & $exe @args
    if ($LASTEXITCODE -eq 0) {
        $new = (Get-ChildItem -LiteralPath $OutDir -ea 0 | Where-Object { $_.Name -like '*.json' -and $existingFiles -notcontains $_.Name })
        $file = if ($new) { $new[0].FullName } else { $OutDir }
        $results += [pscustomobject]@{ channelId = $cid; status = 'ok'; file = $file }
    } else {
        $results += [pscustomobject]@{ channelId = $cid; status = 'failed'; error = "exit $LASTEXITCODE" }
    }
}
# --- Result reporting: print every full path, plainly and completely ---
# `--include-threads All` means each thread lands in its own file, so list them all.
$allFiles = Get-ChildItem -LiteralPath $OutDir -ea 0 | Where-Object { $_.Name -like '*.json' } | Sort-Object Name
"OUTPUT_DIR: $OutDir"
"OUTPUT_DIR_URL: file:///$($OutDir -replace '\\','/')"
"FILE_COUNT: $($allFiles.Count)"
"RESULT_PATHS:"
foreach ($f in $allFiles) { "  $($f.FullName)" }
"RESULT_PATHS_URL:"
foreach ($f in $allFiles) { "  file:///$($f.FullName -replace '\\','/')" }
"SUMMARY_JSON: " + ($results | ConvertTo-Json -AsArray -Compress)
