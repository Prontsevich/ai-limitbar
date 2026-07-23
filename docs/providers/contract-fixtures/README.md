# Provider Contract Fixtures

These files are sanitized internal validation examples for the version 1
Provider Integration Contract. They are non-normative and create no public wire
format or compatibility promise.

Each file uses the same fixture-only bundle shape:

```text
fixtureVersion: 1
contractVersion: { major, minor }
surfaces: [ProviderSurface]
sources: [SourceDescriptor]
snapshots: [CapacitySnapshot]
```

The bundle is a review convenience, not a runtime contract type. Runtime
snapshots reference trusted surface and source descriptors registered by the
application.

Fixture values are synthetic and intentionally generic. Saved account IDs,
context IDs, labels, timestamps, and quantities do not identify real users,
accounts, workspaces, keys, or provider responses. The files must never contain
credentials, tokens, cookies, browser storage, raw HTML, raw provider payloads,
opaque upstream identifiers, or unredacted captures.

The four examples exercise different contract boundaries:

- `codex.json`: structured-local percentage windows, credits, and token usage
  for one local identity;
- `claude.json`: separate subscription, API, and organization surfaces plus
  provider-reported versus local-estimate observations;
- `minimax.json`: explicit regions, independent account contexts, multimodal
  native units, unlimited/unavailable, boost, and overage;
- `openrouter.json`: one billing account with child API-key credential contexts,
  an optional elevated account-credits source, per-key and account-wide currency
  observations, a workspace budget without fabricated spend, BYOK usage, and a
  missing key limit without fabricated unlimited capacity or utilization.

Passing these fixtures demonstrates that the shared model can express the
evidence. It does not approve a source, prove authentication feasibility, or
replace provider-specific adapter fixtures.

Evidence references:

- [Codex app-server](https://developers.openai.com/codex/app-server/)
- [Claude paid-plan usage credits](https://support.claude.com/en/articles/12429409-manage-usage-credits-for-paid-claude-plans)
- [MiniMax Token Plan](https://platform.minimaxi.com/docs/token-plan/intro)
- [OpenRouter current API key](https://openrouter.ai/docs/api/api-reference/api-keys/get-current-key)
- [OpenRouter management API keys](https://openrouter.ai/docs/guides/overview/auth/management-api-keys)
