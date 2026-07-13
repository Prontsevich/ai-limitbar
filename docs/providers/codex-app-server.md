# OpenAI Codex Experimental App-Server Source

OpenAI Codex accounts use the `Experimental app-server` source. Only one
account can be configured because it reflects the current local Codex CLI
identity. On refresh, AI Limitbar starts a short-lived local process:

```text
codex app-server --listen stdio://
```

It completes the documented app-server initialization handshake and requests
`account/rateLimits/read` over JSONL. The app normalizes only the explicitly
identified `codex` rate-limit bucket, its `primary` window, and its optional
`secondary` window. The resulting snapshot is marked `live` and visibly labeled
as experimental because the local CLI protocol may change; a successful read is
still presented as `OK`.

Leave `Codex executable` blank to use automatic discovery from the shell PATH
and standard local install locations, or select a specific executable for that
account. AI Limitbar does not open a terminal, drive `/status` through a PTY,
read browser content, session files, cookies, tokens, or credentials. It
discards raw JSON-RPC messages and deliberately excludes credits, opaque reset
identifiers, and other unneeded account fields before a snapshot is created.

Only one OpenAI Codex account can use this source at a time, since it reflects
the currently authenticated local Codex CLI identity. If the CLI is missing,
not authenticated, unsupported, malformed, or times out, the account shows a
recoverable diagnostic with steps to update or authenticate Codex CLI and retry.

Reference: <https://developers.openai.com/codex/app-server/>.
