<#
.SYNOPSIS
  List channels in a server, for channel-name -> channel-ID resolution.
.PARAMETER GuildId
  The server ID (from Test-Token.ps1 output).
.DESCRIPTION
  Prints channels as JSON [{id,name}, ...]. Never prints the token.
  Exit 1 with a diagnostic on stderr on failure.
#>
param([Parameter(Mandatory)][string]$GuildId)
. "$PSScriptRoot\_common.ps1"

try {
    $exe = Get-Exporter
    $token = Get-Token
} catch {
    [Console]::Error.WriteLine($_.Exception.Message); exit 1
}

# `channels` prints lines like:  <channelId> | <Category> / <channel-name>
$raw = & $exe channels -g $GuildId -t $token 2>&1
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("Listing channels for guild $GuildId failed:")
    [Console]::Error.WriteLine(($raw | Out-String))
    exit 1
}

$channels = foreach ($line in $raw) {
    $s = "$line".Trim()
    if ($s -match '^(?<id>\d{5,})\s*\|\s*(?<name>.+)$') {
        [pscustomobject]@{ id = $Matches.id; name = $Matches.name.Trim() }
    }
}
$channels | ConvertTo-Json -AsArray -Compress
exit 0
