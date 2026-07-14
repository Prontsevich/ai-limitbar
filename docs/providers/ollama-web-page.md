# Ollama Cloud Experimental Web Page Source

Ollama Cloud does not currently document an account-usage API. AI Limitbar uses
the `Experimental web page` source for each Ollama account.

In Settings or the dashboard account details, save the account, then choose
`Connect Ollama…` or `Reconnect`. AI Limitbar opens a dedicated connection
window so the transient menu-bar panel cannot dismiss the sign-in flow. Sign in
only in the AI Limitbar-owned WebKit view. Each
account receives its own persistent WebKit data store identified by an opaque
UUID; AI Limitbar never reads, imports, exports, logs, or stores cookies,
passwords, tokens, browser profile data, raw HTML, or raw bridge payloads.

The source loads `https://ollama.com/settings` and extracts only the semantic
`Session usage` and `Weekly usage` sections, resolving each value from its own
usage card even when Ollama wraps both cards in a shared section. The source
also reports the reset time for each window when Ollama exposes it. During
interactive sign-in, WebKit may follow Ollama's documented authentication
redirect through `api.workos.com`, `signin.ollama.com`, Google, or GitHub;
regional Google Account endpoints such as `accounts.google.by` are allowed for
interactive sign-in. Scheduled refreshes never follow third-party redirects.
Interactive sign-in remains open until it completes or the user cancels it; scheduled refreshes
retain a 20-second load timeout. WebKit cancellation events from an OAuth
redirect or an obsolete navigation after the settings page becomes visible are
ignored; actual failures before the settings page remain actionable. The bridge
is run again after the settings navigation and waits for the usage cards to
render. After login, extraction remains restricted to the settings page.

The values are labeled `Ollama settings web page (Experimental)` with `live`
confidence. The page structure is undocumented and may change, but a successful
read is presented as `OK`; model request counts, extra-usage balance, and
billing values are intentionally excluded.

`Reconnect` is available when the session expires or the page structure
changes. Scheduled refreshes never foreground the login view or attempt
unattended reauthentication. A failed refresh keeps the last valid snapshot and
shows a visible recovery warning.
