# Contributing

Thanks for your interest in CodexMeter.

## Build

Requirements: macOS 14+ and Swift 6.1 or newer.

```zsh
./build-app.sh
```

There is currently no automated test suite. Please describe the macOS version and manual checks performed in a pull request.

## Pull requests

- Keep changes focused and explain user-visible behavior.
- Do not include `~/.codex/auth.json`, access tokens, account identifiers, or real usage/reset-card data.
- Do not add dependencies without explaining why they are needed.
- The usage endpoints are undocumented service endpoints and may change.
