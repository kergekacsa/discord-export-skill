# discord-export

A Claude Code skill that exports Discord chat history to lossless JSON, using Tyrrrz's
[DiscordChatExporter](https://github.com/Tyrrrz/DiscordChatExporter) CLI. It runs the exporter
on your own Windows machine, validates a token you supply, resolves which server a channel
belongs to, and writes JSON — including every thread and all reactions.

## Purpose

The point of the export is to turn a channel into something you can **feed to an LLM for
summarizing and catching up**, instead of scrolling by hand. It's built for cases like:

- **Summarizing a channel** — condense a busy channel into the key points and decisions.
- **Long discussions** — threads or debates too long to read end to end.
- **Unfocused chatter** — channels that wander, where you want the signal without the noise.
- **Catching up after time away** — you've been off for a while and need a recap of what happened.
- **Following along** — a running channel you can't watch live but want digested periodically.

The lossless JSON (every message, thread, and reaction) is the input; the summary or recap is
what you do with it afterward.

## What it does

- Exports one or more Discord channels to JSON.
- Always includes **threads** (`--include-threads All`) and **reactions** (native to the JSON
  format), so nothing is lost.
- Resolves a channel name to its ID for you, and guesses the server from the channel when you
  don't name one.
- Warns once on heavy requests (range over ~3 months, or more than 2 channels) without ever
  blocking or shrinking them.
- Writes to a timestamped folder under `%TEMP%` by default, and reports every full output path.

## Requirements

- **Windows** + **Claude Code**. The skill shells out to a Windows `.exe` and reads/writes
  `%APPDATA%` / `%TEMP%`. It does not work in the claude.ai sandbox or Cowork.
- **DiscordChatExporter.Cli.exe** on `PATH`, in `%PROGRAMFILES%\DiscordChatExporter.Cli.win-x64\`,
  or in `%LOCALAPPDATA%\DiscordChatExporter\`. If absent, the skill offers to download and unzip
  the latest release.
- **.NET runtime** (DiscordChatExporter needs it). If the exe won't launch, the skill tells you
  which runtime to install.
- A **Discord user token**, which you supply yourself (see below).

## Token setup

The skill never harvests your token — reading it from the Discord app's encrypted store or
scraping it from browser traffic is credential extraction, so the skill does not do it. You paste
your own token into a plaintext config file:

```
%APPDATA%\discord-export\config.json
```

```json
{ "token": "..." }
```

To get the token, run the exporter's built-in guide and follow the steps (they carry Discord's
own Terms-of-Service warning):

```powershell
DiscordChatExporter.Cli.exe guide
```

In short: open Discord in a browser, `Ctrl+Shift+I` -> Network tab -> reload -> click a `messages`
request -> copy the value of the `authorization` request header -> paste it into `config.json`.

The file is plaintext. Treat the token like a password; never paste it into chat.

## Usage

Ask Claude Code in natural language, for example:

- "Export the last 7 days of #general to JSON."
- "Grab everything since 2026-01-01 from the skills channel in Matt's AI Heroes."

A **start date is required**; the end date is optional and defaults to now.

## Output

- JSON, written to `%TEMP%\discord-export\<timestamp>\` unless you specify a location.
- Because threads export one file per thread, a run produces one file for the channel plus one
  per thread. Reactions (emoji, counts, and the reacting users) are embedded in each message.
- The skill prints the full output directory path and every file's full path, as copyable text
  and clickable links.

## Files

```
discord-export/
  SKILL.md                          Skill definition and the phase-by-phase flow  
  references/
    token-acquisition.md            Why the skill does not auto-harvest tokens, plus manual steps
  scripts/
    _common.ps1                     Locate the exe; read the token without echoing it
    Test-Token.ps1                  Validate the token and list accessible servers
    Get-Channels.ps1                List a server's channels for name -> ID resolution
    Export-Channels.ps1             Export channels to JSON (threads + reactions), report paths
```

## License

This skill is released under the **MIT License** — open source, free to use, modify, and
distribute. See [LICENSE](LICENSE).

DiscordChatExporter, the underlying CLI, is a separate project by Oleksii Holub (Tyrrrz), also
released under the **MIT License**:
https://github.com/Tyrrrz/DiscordChatExporter/blob/master/License.txt

## Disclaimer

Automating a Discord **user** account is against Discord's Terms of Service and carries some risk
to the account. This skill uses user tokens by design (to export your own readable history); you
use it at your own risk.
