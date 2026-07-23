# OpenRouter Provider Research

## Status and decision

OpenRouter has a supported `documented-interface` result for the first MVP. One
saved AI Limitbar account represents one user-declared OpenRouter billing
account. It contains one or more ordinary API-key credential contexts, each
using `GET /api/v1/key` for its own limits and usage. An optional management key
adds the single account-wide credits metric through `GET /api/v1/credits`.

The management credential is explicitly elevated and opt-in. It is never
selected as a fallback for an ordinary key. The first MVP may use `GET
/api/v1/keys` only to verify in memory that a configured ordinary key belongs
to the management inventory; it does not auto-import keys or persist provider
labels, hashes, owner IDs, or workspace IDs.

No production HTTP adapter is implemented by this research. The shared storage
foundation for this account shape is implemented: validated account-context
trees, ordinary and management credential roles, independent Keychain items,
and per-slot refresh and sanitized diagnostic boundaries are available for the
future adapter and Settings flow.

## Selected MVP account shape

The dashboard and persistence model use this hierarchy:

```text
OpenRouter billing account
├── shared account credits (optional management source)
├── ordinary API key credential
│   └── per-key usage, BYOK usage, limit and reset metrics
└── ordinary API key credential
    └── per-key usage, BYOK usage, limit and reset metrics
```

An API key is a `credential` account context, not a capacity window. One key can
produce several metrics with different windows. Account credits attach only to
the root context and render once; they are never copied into child-key rows.

Without a management key, ordinary-key metrics continue to work and the shared
balance is unavailable rather than duplicated or inferred. With a management
key, credits are fetched once per account. A failure in one credential context
preserves the other keys and the last valid account metric, with separate
refresh results and diagnostics.

Keys from a genuinely different billing owner belong to another saved AI
Limitbar account. Without management inventory evidence, grouping is an
explicit user choice rather than a provider-verified ownership claim.

## Documented sources

| Source | Credential | Scope | Useful signals | Confidence |
| --- | --- | --- | --- | --- |
| `GET /api/v1/key` | Ordinary API key | Authenticating key only | Key limit, remaining limit, reset policy, total/daily/weekly/monthly usage, separate BYOK usage, expiry and tier flags | Live |
| `GET /api/v1/credits` | Management key according to the API reference | Current personal or organization billing account | Total credits purchased and total usage | Live |
| `GET /api/v1/keys` | Management key | Administrative key inventory; default workspace or explicit workspace filter | Per-key limits and usage, disabled state and expiry | Live |
| `GET /api/v1/activity` | Management key | Current account; optional key-hash or organization-member filter | Last 30 completed UTC days, grouped by endpoint | Delayed |
| `GET /api/v1/workspaces` | Management key | All workspaces visible to the account-level key | Workspace inventory only | Live |
| `GET /api/v1/workspaces/{id}/budgets` | Organization management key; Enterprise | One selected workspace | Daily, weekly, monthly or lifetime USD limits and reset policy | Live for the configured limit |

The documented workspace-budget response contains the limit and interval but
does not contain current spend. It cannot by itself produce a remaining-budget
value. The activity endpoint is documented as a 30-completed-day account feed
and does not document a workspace field, so it is not a defensible substitute
for exact workspace-period spend. The sanitized management probe returned 31
completed UTC dates and encoded each `date` as `YYYY-MM-DD 00:00:00`, rather
than the documented `YYYY-MM-DD`. A future parser must accept both verified
shapes, normalize them to a completed UTC day, and must not assume exactly 30
rows or dates.

The current-key response also contains a deprecated `rate_limit` object. It is
not a supported capacity signal and must be ignored. Free-model request limits
are plan- and credit-dependent rather than a general account quota exposed by
this endpoint.

Official references:

- [Current API key](https://openrouter.ai/docs/api/api-reference/api-keys/get-current-key)
- [Credits](https://openrouter.ai/docs/api/api-reference/credits/get-credits)
- [Management API keys](https://openrouter.ai/docs/guides/overview/auth/management-api-keys)
- [API-key inventory](https://openrouter.ai/docs/api/api-reference/api-keys/list)
- [Activity](https://openrouter.ai/docs/api/api-reference/analytics/get-user-activity)
- [Workspaces](https://openrouter.ai/docs/guides/features/workspaces/overview)
- [Workspace budgets](https://openrouter.ai/docs/guides/features/workspaces/workspace-budgets)
- [Errors and retry behavior](https://openrouter.ai/docs/api/reference/errors-and-debugging)

## Signal semantics

All documented monetary values are represented as native USD currency values;
they are not converted to a percentage or mixed with token, request or BYOK
quantities.

For an ordinary key:

- `usage`, `usage_daily`, `usage_weekly` and `usage_monthly` are distinct spend
  observations and remain separate metrics.
- `byok_usage` and its daily/weekly/monthly variants remain separate from
  OpenRouter-billed usage. `include_byok_in_limit` controls only whether those
  values participate in the key limit.
- A finite `limit` with `daily`, `weekly` or `monthly` `limit_reset` maps to the
  matching fixed UTC window. Daily resets are at midnight UTC, weekly resets
  are Monday at midnight UTC, and monthly resets are on the first day at
  midnight UTC.
- A finite limit with no reset is a lifetime key limit.
- `limit_remaining` is provider-reported. It is not recomputed unless a future
  adapter records an explicit derivation, and negative or over-limit values
  must not be clamped.
- `limit == null`, `limit_remaining == null` and `limit_reset == null` mean that
  this key has no configured key-level limit. They do not prove unlimited
  account credits, model availability or provider capacity. The adapter omits
  the limit metric and still reports the available usage metrics.
- Missing is not zero. Unknown fields are ignored, while a missing required
  observation fails only the affected metric.

For a management key, `total_credits` and `total_usage` describe the current
billing account, not a workspace. Remaining credits may be derived explicitly
as total credits minus total usage. Activity is historical and delayed because
the endpoint contains only completed UTC days. Workspace budgets are distinct
workspace metrics and must not be combined with account-wide credits.

## Credential and account boundaries

Ordinary and management keys are separate Keychain credential slots. The raw
key is used only in the HTTPS Authorization header and is never written to
SQLite, `UserDefaults`, logs, fixtures or diagnostics.

Each slot is a device-local, non-synchronizing generic password in the macOS
Data Protection Keychain. All CRUD queries explicitly target that Keychain;
creation uses after-first-unlock, this-device-only accessibility. Access stays
inside the app's provisioned default Keychain group, so local staged
verification requires Apple Development signing and an embedded authorized
profile. The local developer supplies its Team ID explicitly through
`AILIMITBAR_DEVELOPMENT_TEAM`; the repository stores no team-specific value.
The ad-hoc release bundle remains non-credential-capable until the separate
production signing and notarization gate is complete.

Each ordinary slot attaches to one app-owned `credential` child context. The
optional management slot attaches to the saved billing-account root, so its
future credits metric remains root-scoped rather than becoming a child-key
metric. SQLite enforces one slot per context and at most one management slot per
saved account; all reads and writes include the provider, saved-account, and
slot IDs so identical local child names in two accounts cannot cross their
credential boundary.

Credential creation, replacement, disabling, and deletion are lifecycle-aware.
A disabled or incomplete slot cannot be read. Create and delete partial failures
retain an opaque Keychain reference in an inaccessible retryable SQLite row;
account removal cannot bypass credential cleanup. Per-account serialization
keeps create and recovery from racing delete across separate store instances,
while the persisted lifecycle row remains the crash-recovery boundary. No
recovery path returns an existing raw key to Settings or diagnostics.

An ordinary key is the narrowest reliable credential boundary:

- every OpenRouter API key belongs to a workspace, but `/api/v1/key` does not
  return a workspace identifier;
- organization keys draw from the organization's shared credit pool, but the
  current-key response does not identify the organization;
- therefore AI Limitbar can truthfully label the source as one configured API
  key, but cannot infer an upstream personal account, organization or workspace
  from it;
- keys grouped by the user under one billing account retain separate local
  credential-context IDs, Keychain items, refresh results and diagnostics,
  while account-wide credits remain a single root metric.

Management keys are account-level administrative credentials. OpenRouter
documents that they operate across workspaces and cannot call completion
endpoints. In the MVP they provide shared credits and optional in-memory key
membership verification only. Key inventory may contain key hashes, user IDs,
names, and workspace IDs; those fields and raw rows are discarded before a
normalized snapshot is created. A management source represents one explicitly
selected billing account and does not create multiple saved accounts from the
keys it can enumerate.

OpenRouter organizations are separate from personal accounts, can share one
credit pool, and can contain members in several workspaces. A user may belong
to multiple organizations. The completed live matrix covers two ordinary keys,
one management key, a populated default workspace and a second empty workspace
in one personal billing context. It verifies management visibility and empty
workspace key filtering, but does not establish organization behavior or a
workspace containing an independently scoped key.

## Sanitized probe evidence

An ordinary-key probe on 2026-07-23 decoded the response only in memory and
emitted field names, JSON types, null flags, credential-class booleans and HTTP
status codes. It did not emit or retain the key, label, creator ID, monetary
values, raw response or error messages.

Observed results:

- `/api/v1/key` returned the documented `data` envelope and ordinary,
  non-provisioning credential classification.
- Usage and BYOK total/daily/weekly/monthly fields were numeric.
- `limit`, `limit_remaining`, `limit_reset` and `expires_at` were present and
  null, proving the no-key-limit variant without treating it as unlimited.
- Missing and deliberately invalid authentication both returned HTTP 401.
- The ordinary key returned HTTP 403 for `/activity` and HTTP 401 for `/keys`
  and `/workspaces`, confirming that those administrative paths cannot be an
  ordinary-key fallback.
- The same ordinary key unexpectedly returned HTTP 200 and the documented
  numeric schema from `/credits`, despite the current API reference requiring a
  management key. This is an undocumented authorization mismatch. AI Limitbar
  must not rely on it; `/credits` remains management-only in the source
  contract until OpenRouter changes its documentation.
- The management credential identified itself as both management and
  provisioning, and returned the documented numeric credits schema, key
  inventory, activity feed and workspace inventory.
- Two distinct ordinary keys had the same creator context. One exercised the
  all-null key-limit variant; the other exercised a finite monthly key limit.
  Both were visible in the management inventory and all enumerated keys shared
  the same workspace.
- `/credits` returned equal account totals for both ordinary keys and the
  management key. This confirms that per-key usage and limits remain separate
  while the probed keys share one account-wide credit pool. The ordinary-key
  access remains undocumented and unsupported despite this observed equality.
- Management activity was non-empty and contained endpoint, model and provider
  metadata that must be discarded. Filtering by the primary key hash returned
  only that key's rows; filtering by a second key with no matching activity
  returned an empty successful result.
- The organization-only `user_id` activity filter returned HTTP 400 in the
  probed personal context.
- Workspace-scoped key filtering returned the full populated inventory for the
  original workspace and every returned item matched that filter.
- Workspace-budget reads returned HTTP 404 by both workspace ID and slug. This
  is a missing personal/default-workspace capability, not an empty known
  budget.
- After a second empty workspace was added, management workspace inventory
  returned both contexts and workspace-filtered key inventory returned an empty
  successful result for the new workspace. Account credits remained identical
  through the ordinary and management credentials, confirming that credits are
  account-wide rather than workspace-scoped. The new workspace budget endpoint
  also returned HTTP 404.

Deferred expansion scope:

- organization identities, member-created keys, and workspaces containing
  independently scoped keys;
- automatic management-key discovery and synchronization of key inventory;
- management activity/history and workspace-aware analytics;
- daily, weekly and lifetime finite key-limit variants, including zero and
  over-limit observations where they can be created without paid inference;
- an available Enterprise workspace-budget variant if workspace budgets are to
  become supported;
- HTTP 429 evidence when naturally encountered. Research must not manufacture
  load to force rate limiting.

## Refresh, failure and privacy behavior

The endpoints are ordinary HTTPS JSON reads and are compatible with the current
macOS architecture through a trusted `URLSession` adapter. No browser session,
CLI, helper process or additional dependency is needed.

The provider does not document an observation expiry for these reads. A future
adapter should use the app's bounded polling policy, mark each successful value
with its fetch time, and treat management activity as delayed. It should honor
`Retry-After` on HTTP 429 and 503 without busy retrying.

Errors map to fixed diagnostics by HTTP class: authentication for 401,
insufficient privilege for 403, insufficient credits for 402, throttled for
429, and transient service failure for 5xx. Provider messages, metadata and
response bodies are never logged or persisted. A failed refresh preserves the
last valid snapshot and records failure separately from last success.

## Fixture and test strategy

Production adapter fixtures must be hand-authored from the documented schema
and sanitized probe shapes, never copied from real responses. Coverage should
include:

- bounded ordinary keys with daily, weekly, monthly and lifetime resets;
- the observed all-null key-limit variant;
- zero, decimal, negative remaining and over-limit values without clamping;
- BYOK included in and excluded from a key limit;
- missing optional fields, unknown fields, malformed numbers and wrong JSON
  types;
- 401, 402, 403, 429 with `Retry-After`, 5xx, cancellation and timeout;
- empty and populated management activity with completed-day freshness;
- both documented date-only and observed UTC-midnight timestamp activity dates,
  including a variable number of returned completed days;
- account-wide credits separated from workspace budgets and per-key usage;
- one billing account with several credential contexts proving independent
  Keychain items, metrics, refresh results and diagnostics, plus two genuinely
  separate billing accounts when that expansion is researched;
- absence of credentials, labels, hashes, upstream user/workspace IDs, model
  names and raw errors from persistence, logs and diagnostics.

The existing synthetic contract fixture demonstrates native currency,
privilege-separated sources, null limits and account/workspace separation. It
does not count as authentication or provider verification.
