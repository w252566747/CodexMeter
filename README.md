# CodexMeter

[English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

CodexMeter is an unofficial macOS menu bar app for checking Codex usage at a glance. The 5h and 7d ring arcs show time remaining until each window resets: they begin nearly full after a reset and shrink toward empty as reset approaches. The short label inside each ring is the reset countdown; the percentage beside it is the remaining quota. Click the rings for full countdowns, available reset cards, and card expiration dates. The details panel supports Simplified Chinese, Japanese, and English; the selected language is saved on this Mac.

CodexMeter is an independent community project and is not affiliated with OpenAI.

## Requirements

- macOS 14 or later
- Swift 6.1 toolchain (Xcode Command Line Tools or Xcode)
- Codex signed in on this Mac, with credentials in `~/.codex/auth.json`

## Build and run

```zsh
./build-app.sh
open CodexMeter.app
```

The app refreshes usage every 10 seconds and reset-card details every 5 minutes. It reads the existing local Codex access token and makes read-only requests to the endpoints listed below. It does not send credentials to a third-party service.

## Create a downloadable ZIP

Run `./package-app.sh`. It builds and ad-hoc signs `CodexMeter.app`, then creates `dist/CodexMeter-macos.zip` and the matching `dist/CodexMeter-macos.zip.sha256`. The ZIP contains the app bundle; it is not a `.dmg` installer and is not notarized. Do not commit the generated `dist/` directory.

## Distribution and first launch

- The repository currently has source code, but no published GitHub Release or ready-to-install download. A ZIP created locally by the packaging script is not an official release. Until a release is published, users need the Swift toolchain to build the app themselves.
- Release builds are ad-hoc signed, without Developer ID signing or Apple notarization. Gatekeeper may block the first launch.
- Download the app and its `.sha256` file only from this project's official GitHub Releases page. Do not use third-party mirrors.
- Before opening the app, verify the downloaded ZIP in Terminal with `shasum -a 256 -c CodexMeter-macos.zip.sha256`. Continue only if it reports `OK`.
- Even after the checksum passes, use **System Settings → Privacy & Security → Open Anyway** only if you trust the source and have inspected the project. Read the system warning before confirming.
- A company- or school-managed Mac may block unsigned or unnotarized apps entirely. Follow the organization's policy and contact its administrator; do not try to bypass managed restrictions.
- Developer ID signing and notarization are not used for this project. Building from source does not require a paid Apple developer membership.
- No software license has been selected. The source is publicly viewable, but the repository does not grant permission to copy, modify, or redistribute it. Ask the author for permission until a license is added.

## Run only while ChatGPT is open

The included LaunchAgent watcher starts CodexMeter while the ChatGPT desktop process is running and stops it after ChatGPT exits. The watcher expects the app at `/Applications/CodexMeter.app`:

```zsh
ditto CodexMeter.app /Applications/CodexMeter.app
mkdir -p ~/Library/LaunchAgents
cp com.codexmeter.watcher.plist ~/Library/LaunchAgents/com.codexmeter.watcher.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.codexmeter.watcher.plist
```

To disable the watcher:

```zsh
launchctl bootout gui/$(id -u)/com.codexmeter.watcher
rm ~/Library/LaunchAgents/com.codexmeter.watcher.plist
```

## Data and limitations

- Usage: `https://chatgpt.com/backend-api/wham/usage`
- Reset cards: `https://chatgpt.com/backend-api/wham/rate-limit-reset-credits`

These are service endpoints rather than a documented stable public API. They may change without notice. The app reads the token from `~/.codex/auth.json`; never commit that file, access tokens, or account data.

CodexMeter is an independent community project. OpenAI, ChatGPT, and Codex are trademarks of their respective owners.
