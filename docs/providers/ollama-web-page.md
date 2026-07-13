# Ollama Cloud Experimental Web Page Source

Ollama Cloud does not currently document an account-usage API. AI Limitbar keeps
`Manual` as the default source and offers an opt-in `Experimental web page`
source for an Ollama account.

In Settings, save the account with `Experimental web page`, then choose
`Connect Ollama…`. Sign in only in the AI Limitbar-owned WebKit view. Each
account receives its own persistent WebKit data store identified by an opaque
UUID; AI Limitbar never reads, imports, exports, logs, or stores cookies,
passwords, tokens, browser profile data, raw HTML, or raw bridge payloads.

The source loads `https://ollama.com/settings` and extracts only the semantic
`Session usage` and `Weekly usage` sections, resolving each value from its own
usage card even when Ollama wraps both cards in a shared section. The source
also reports the reset time for each window when Ollama exposes it. During
interactive sign-in, WebKit may follow Ollama's documented authentication
redirect through `api.workos.com`, `signin.ollama.com`, Google, or GitHub;
scheduled refreshes do not follow those auth redirects. Interactive sign-in
remains open until it completes or the user cancels it; scheduled refreshes
retain a 20-second load timeout. After login, extraction remains restricted to
the settings page.

The values are labeled `Ollama settings web page (Experimental)` with `live`
confidence. The page structure is undocumented and may change, but a successful
read is presented as `OK`; model request counts, extra-usage balance, and
billing values are intentionally excluded.

`Reconnect` is available when the session expires or the page structure
changes. Scheduled refreshes never foreground the login view or attempt
unattended reauthentication. A failed refresh keeps the last valid snapshot and
falls back to a visible recovery warning; switching back to `Manual` remains
supported.