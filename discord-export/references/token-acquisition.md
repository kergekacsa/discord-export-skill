# Token acquisition

The skill needs a Discord **user token** to call the exporter. There is exactly one supported way to supply it: **the user pastes their own token into the config file.** This document explains why the skill does not automate that step, and gives the manual steps.

## Why the skill does not auto-harvest the token

Two "automatic" routes exist in theory. The skill uses neither, because both are credential extraction — taking an authentication secret out of where the OS or app protects it. That is off-limits regardless of whose account or machine it is.

- **Discord desktop app (LevelDB).** Modern Discord stores the token in `%APPDATA%\discord\Local Storage\leveldb\` encrypted with an AES key that is itself DPAPI-protected under the user's account (the same `v10` scheme Chromium uses; blobs carry a `dQw4w9WgXcQ:` marker). "Reading" it means DPAPI-decrypting the key and AES-GCM-decrypting the blob — i.e. unwrapping a stored credential. The skill does not do this.
- **Browser network interception.** The token is the `Authorization` header on requests to `discord.com/api/`. Scraping that header out of live network traffic is likewise capturing a credential in transit. The skill does not do this.

Both are also fragile (DPAPI internals, tool-specific header exposure, Discord actively hardening against extraction), so avoiding them costs nothing in reliability. The user copying their own token is a few seconds of work, keeps the secret in the user's hands, and always works.

## The manual path (what to tell the user)

The exporter ships these exact steps — print them with `DiscordChatExporter.Cli.exe guide`. They carry Discord's own "automating user accounts is against ToS — use at your own risk" warning, which the user should see.

1. Open Discord in a web browser and log in.
2. Open any server or DM channel.
3. Press `Ctrl+Shift+I` to open developer tools.
4. Go to the **Network** tab.
5. Press `Ctrl+R` to reload.
6. Switch between a couple of channels to trigger requests.
7. Find a request that starts with `messages`.
8. Open its **Headers** tab.
9. Under **Request Headers**, find `authorization`.
10. Copy the value of the `authorization` header.

Then paste that value as the `token` field in:

```
%APPDATA%\discord-export\config.json
```

Shape:
```json
{ "token": "..." }
```

The file is plaintext — say so once, so the user isn't surprised. Never ask the user to paste the token into chat; the config file is the only place it should go. After the user confirms, re-run `scripts/Test-Token.ps1` to validate.

## Getting server / channel IDs manually (if ever needed)

Exports run by channel ID; the skill resolves IDs for the user via `guilds` / `channels`. If a user ever needs an ID by hand: Discord → Settings → Advanced → enable **Developer Mode**, then right-click a server or channel → **Copy Server ID** / **Copy Channel ID**.
