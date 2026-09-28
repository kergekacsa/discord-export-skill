---
name: discord-export
description: Export Discord chat history to JSON using the DiscordChatExporter CLI (DiscordChatExporter.Cli.exe). Use this whenever the user wants to pull, grab, download, back up, or export messages/history/logs from a Discord server or channel for further use — including phrasings like "export the #general channel", "get the last month from Discord", "grab the chat log from my server", or "back up that Discord channel". Windows + Claude Code only. Handles token validation/storage, server-from-channel guessing, date ranges, and JSON output to the OS temp dir.
---

# Discord Export

Export message history from Discord channels to JSON, using Tyrrrz's DiscordChatExporter CLI. This skill runs the exporter on the user's own Windows machine via Claude Code, validates a user-supplied token, resolves which server a channel belongs to, and writes JSON exports.

Helper scripts in `scripts/` do the mechanical work. Prefer them over hand-writing the exporter invocations — they locate the exe, read the token from config without echoing it, enforce the exporter's quirks (like the trailing-slash output path), and return parseable JSON.

## Scope and environment

This skill targets **Claude Code on Windows** only. It shells out to a Windows `.exe` and writes to `%TEMP%` / `%APPDATA%`. It does not work in the claude.ai sandbox or in Cowork (no local shell, no reach to discord.com). If you are not on a local Windows shell, say so plainly and stop rather than pretending to export.

**User tokens only.** The exporter also accepts bot tokens, but this skill targets the user's own readable history. (The `--bot` flag is a no-op in current versions — "kept for backwards compatibility" — so there is nothing to pass or avoid; just use a user token.)

**The skill never harvests the token.** Reading it out of the Discord desktop app's encrypted store or scraping it from browser network traffic is credential extraction, so the skill does not do it — the user pastes their own token into the config file. See `references/token-acquisition.md` for the rationale and the manual steps.

## Output conventions

Every path or URL you surface to the user must be a **clickable link**, not bare text — the user should be able to act on it with one click, and still copy it if needed.

- **Discord:** when pointing the user at Discord, render an actionable Markdown link, not a plain URL — `[discord.com/channels/@me](https://discord.com/channels/@me)`.
- **Config file:** when telling the user to edit the token config, give a clickable link that opens the file — `[config.json](file:///C:/Users/Kacsa/AppData/Roaming/discord-export/config.json)` (use the real `%APPDATA%` path, forward slashes, `file:///` scheme).
- **Results — this is mandatory, do not skip it:** on every run, print the **full absolute output directory path as plain copyable text** AND as a clickable `file:///` link. A folder link alone is not enough — the user must be able to *copy the whole path*. Because `--include-threads All` produces one file per thread (often dozens), also list every file's full path. `Export-Channels.ps1` prints all of this (`OUTPUT_DIR`, `OUTPUT_DIR_URL`, `RESULT_PATHS`, `RESULT_PATHS_URL`); relay it faithfully — surface at minimum the full directory path as text + clickable link, and the per-file full paths (a `file:///` link list, or a plain-text block if there are too many to link individually). Never reduce the report to just a folder link.

## The overall flow

Run these phases in order. Stop and throw a clear error the moment a required input is missing or a step genuinely can't proceed — do not silently guess past a gap.

1. **Locate the exe** (offer to install if absent).
2. **Get a valid token** (stored config → validate → guide the user to paste one).
3. **Collect and validate parameters** (dates, server, channels).
4. **Warn on heavy requests** (but never block).
5. **Export to JSON.**
6. **Report the output paths.**

---

## Phase 1 — Locate DiscordChatExporter.Cli.exe

Use `scripts/_common.ps1` → `Get-Exporter`, which searches in this order:

1. On `PATH` (`DiscordChatExporter.Cli.exe`).
2. `%PROGRAMFILES%\DiscordChatExporter.Cli.win-x64\DiscordChatExporter.Cli.exe`.
3. `%LOCALAPPDATA%\DiscordChatExporter\DiscordChatExporter.Cli.exe`.

If found, remember the full path and use it for every later call.

If found in none, **do not fail outright — offer to install it**:
- Download the latest `DiscordChatExporter.Cli.win-x64.zip` from the GitHub releases API (`https://api.github.com/repos/Tyrrrz/DiscordChatExporter/releases/latest`), pick the `win-x64` CLI asset, and unzip it into `%LOCALAPPDATA%\DiscordChatExporter\`.
- The tool needs the .NET runtime. If the exe won't start because .NET is missing, tell the user which runtime to install rather than installing a system runtime yourself.
- After install, re-verify with `--version` before continuing.

---

## Phase 2 — Get a valid token

The token lives in a plaintext config file so the user can open and edit it fast:

```
%APPDATA%\discord-export\config.json
```

Shape:
```json
{ "token": "..." }
```

**Validate before trusting a token.** Validation doubles as the server-list fetch you need later. Use `scripts/Test-Token.ps1`, which runs `guilds` with the stored token and prints the accessible servers as JSON (`[{id,name}, ...]`). It never prints the token.

The token comes from exactly one source: **the config file, which the user fills in themselves.** The skill does not read it from the Discord app or the browser (that is credential extraction — see `references/token-acquisition.md`).

Sequence:

1. **Stored config.** Run `Test-Token.ps1`. If it exits 0 and returns servers, the token is good — capture that server list and continue.
2. **Missing or invalid.** If it exits non-zero (empty token, or `guilds` returned an auth failure), guide the user to supply one, then stop until they have:
   - Print the exporter's own instructions: `DiscordChatExporter.Cli.exe guide`. These are the sanctioned steps and carry Discord's ToS warning.
   - In short: open Discord in a browser, `Ctrl+Shift+I` → Network tab → reload → click a `messages` request → copy the value of the `authorization` request header. Give the user a clickable link to Discord: `[discord.com/channels/@me](https://discord.com/channels/@me)`.
   - Tell the user to paste that value as `token` in the config file. Give a clickable `file:///` link to `config.json` so they can open it directly (per Output conventions).
   - Re-run `Test-Token.ps1` once they confirm.

Treat the token like a password: never echo it into chat, logs, or printed command output. The config file is plaintext — say so once when you first create it, so the user isn't surprised. Never ask the user to paste the token into chat; the config file is the only place it belongs.

---

## Phase 3 — Collect and validate parameters

Required and optional inputs:

- **from date — REQUIRED.** If the user did not give a start date, stop and throw an error asking for it. Do not default it.
- **to date — optional.** If omitted, it defaults to now (omit `--before`; the exporter treats "no upper bound" as up to the present).
- **channel(s) — REQUIRED.** At least one channel must be identifiable. If none can be resolved, throw an error.
- **server — optional, can be guessed.** See below.

### Resolving server from channel name

The user may name a channel without its server. Resolve it:

1. You already have the server list from the Phase 2 validation. If the user named a server, match it (case-insensitive, partial ok) and confirm which one.
2. For the target server(s), list channels with `scripts/Get-Channels.ps1 -GuildId <id>`. It returns `[{id,name}, ...]` as JSON.
3. Match the requested channel name to a channel and capture its **channel ID** (exports run by ID, not name).
4. If a channel name is ambiguous (matches more than one server or channel), don't guess — list the candidates and ask which they mean.
5. If a named channel can't be found anywhere, throw an error naming what was searched.

### Dates

The from date maps to `--after`, the to date (if given) to `--before`. The exporter accepts ISO-style dates like `2026-01-31` and date-times. Preserve whatever precision the user gave. The helper `Export-Channels.ps1` takes `-After` and `-Before` and wires these up.

---

## Phase 4 — Warn on heavy requests (never block)

Exporting large amounts of history with a user token is what Discord's ToS frowns on and what raises account-flagging risk. If the request looks heavy, warn once, clearly, then proceed if the user still wants to.

Trigger the warning if **either**:
- the date range spans **more than ~3 months**, or
- the request covers **more than 2 channels**.

Keep the warning factual: large user-token exports can violate Discord's Terms of Service and carry some risk to the account. Do **not** refuse or silently shrink the request — the user decides.

---

## Phase 5 — Export to JSON

Use `scripts/Export-Channels.ps1`:

```
Export-Channels.ps1 -ChannelId <id[,id...]> -After <from> [-Before <to>] [-OutDir <dir>]
```

It handles the details that are easy to get wrong:
- Format is `Json`.
- **Threads and reactions are always included.** The script always passes `--include-threads All`, so active and archived threads are exported alongside the channel. Reactions need no flag — the JSON format includes each message's `reactions` (emoji, count, and reacting users) by default.
- Output defaults to a per-run subfolder `%TEMP%\discord-export\<timestamp>\` unless the user specified a location.
- **Directory output paths must end with a slash** — the exporter requires it to disambiguate file-vs-directory. The script enforces this; if you ever call the exe directly, append the slash yourself.
- Each channel is exported with its own call. A single channel failure is reported and the batch continues rather than aborting.

The script prints `OUTPUT_DIR: <dir>` and a JSON summary `[{channelId,status,file|error}, ...]`.

If you invoke the exporter directly instead of via the script, the per-channel form is:
```
DiscordChatExporter.Cli.exe export -t <token> -c <channelId> -f Json --include-threads All --after <from> [--before <to>] -o <outputDir>\
```

---

## Phase 6 — Report

When done, print for the user:
- The **full output directory path as plain copyable text** and as a clickable `file:///` link — never a folder link alone (per Output conventions).
- Each JSON file's **full path** — as `file:///` links, or a plain-text path block when there are too many to link (threads produce one file each).
- A one-line summary: which channels, which date range, message counts if the exporter reported them.
- If any channel was skipped or failed, list it with the reason.

Note: exported filenames contain `[channelId]`. In PowerShell, `[` is a wildcard — use `-LiteralPath` when reading these files back, or lookups fail.

---

## Error-handling summary

Throw a clear, specific error (and stop) when:
- Not running on a local Windows shell.
- The exe is absent and the user declines installation.
- No valid token is available (config missing/empty, or `guilds` reports an auth failure) — hand the user the manual paste steps and the `config.json` path.
- The **from** date is missing.
- No channel can be resolved.

Warn but continue when:
- The request is heavy (>3 months or >2 channels).
- An individual channel fails mid-batch.
