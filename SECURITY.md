# Security policy

CodexMeter reads the existing Codex access token from `~/.codex/auth.json` and sends authenticated, read-only requests directly to `chatgpt.com` usage endpoints. It does not intentionally transmit credentials to another service.

Never publish authentication files, access tokens, account identifiers, or real account responses in issues, pull requests, screenshots, or logs.

For a suspected security issue, do not open a public issue containing sensitive details. Use GitHub's private vulnerability reporting for this repository when available.
