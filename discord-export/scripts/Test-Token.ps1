<#
.SYNOPSIS
  Validate the stored token and list accessible servers (guilds).
.DESCRIPTION
  Runs `guilds` with the token from config.json. This both validates the token and
  supplies the server list used later for channel->server resolution.
  Prints the guild list as JSON [{id,name}, ...] on success. Never prints the token.
  Exit 0 on success; exit 1 with a diagnostic on stderr if the token is missing/invalid.
#>
. "$PSScriptRoot\_common.ps1"

try {
    $exe = Get-Exporter
    $token = Get-Token
} catch {
    [Console]::Error.WriteLine($_.Exception.Message); exit 1
}

# `guilds` prints lines like:  <guildId> | <Guild Name>
$raw = & $exe guilds -t $token 2>&1
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("Token validation failed (invalid or expired token). Exporter said:")
    [Console]::Error.WriteLine(($raw | Out-String))
    exit 1
}

$guilds = foreach ($line in $raw) {
    $s = "$line".Trim()
    if ($s -match '^(?<id>\d{5,})\s*\|\s*(?<name>.+)$') {
        [pscustomobject]@{ id = $Matches.id; name = $Matches.name.Trim() }
    }
}
$guilds | ConvertTo-Json -AsArray -Compress
exit 0
