# Shared helpers for the discord-export skill scripts.
# Dot-source this:  . "$PSScriptRoot\_common.ps1"
# Never prints the token. Exposes:  Get-Exporter, Get-Token, Get-ConfigPath

$ErrorActionPreference = 'Stop'

function Get-ConfigPath {
    Join-Path $env:APPDATA 'discord-export\config.json'
}

# Locate DiscordChatExporter.Cli.exe. Search order: PATH, %PROGRAMFILES%, %LOCALAPPDATA%.
# Returns the full path, or throws with an install hint.
function Get-Exporter {
    $onPath = (Get-Command 'DiscordChatExporter.Cli.exe' -ErrorAction SilentlyContinue).Source
    if ($onPath) { return $onPath }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'DiscordChatExporter.Cli.win-x64\DiscordChatExporter.Cli.exe'),
        (Join-Path $env:LOCALAPPDATA 'DiscordChatExporter\DiscordChatExporter.Cli.exe')
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    throw "DiscordChatExporter.Cli.exe not found on PATH, in %PROGRAMFILES%, or %LOCALAPPDATA%. Offer to install it (see SKILL.md Phase 1)."
}

# Read the user-supplied token from config.json. The user pastes it there themselves.
# Throws a clear, actionable error if the file or token is missing.
function Get-Token {
    $cfg = Get-ConfigPath
    if (-not (Test-Path $cfg)) {
        throw "Config not found: $cfg  -- create it as { `"token`": `"...`" } and paste your token."
    }
    $tok = (Get-Content $cfg -Raw | ConvertFrom-Json).token
    if ([string]::IsNullOrWhiteSpace($tok)) {
        throw "No token in $cfg  -- paste your Discord token into the `"token`" field (run the exporter's ``guide`` command for the steps)."
    }
    return $tok
}
