# MiniMax Provider Research

## Status and decision

MiniMax has a supported `documented-interface` result for discovery, but it is
not implementation-ready. The provider documents
`GET /v1/token_plan/remains`, and its official `mmx` CLI uses that endpoint for
`mmx quota`. The source is privacy-compatible and distribution-compatible for
a macOS app, but an implementation Project must not be opened until sanitized
credential-backed probes establish the current success response for each
supported region and account shape.

The supported account boundary is one user-declared MiniMax Subscription Key in
one explicit service region and Team. It is not a MiniMax user profile, and it
must not merge several Teams or regions:

```text
Saved MiniMax account
└── one region + one Team + one Subscription Key
    ├── included usage — 5-hour rolling window
    └── included usage — weekly window
```

Several saved accounts can coexist only as independent local contexts with
separate Keychain items, refresh results, snapshots, and diagnostics. The
endpoint does not document an upstream user or Team identifier, so AI Limitbar
cannot verify or infer that two keys belong to the same person, different
people, or different Teams.

No production adapter or credential-backed proof of concept is implemented by
this research.

## Why the decision remains gated

MiniMax changed the Token Plan semantics while this research was active. The
current Global documentation describes:

- a Subscription Key dedicated to each user in each Team;
- one unified included-usage pool across supported models and modalities;
- usage-based deduction rather than fixed request, character, image, video, or
  song counters;
- 5-hour rolling and weekly quota windows;
- purchased Credits as overflow through the same Subscription Key.

Earlier documentation and the Mainland China documentation observed during this
research describe model-specific request and daily creative quotas. The public
official CLI still exposes an array named `model_remains` with per-row interval
and weekly counts. This means the existence of a documented source is clear,
but the precise mapping between the current Global usage bar, region-specific
products, the CLI response rows, purchased Credits, and Team assignment is not
safe to infer without real read-only responses.

The implementation gate therefore requires evidence, not another speculative
parser.

## Documented sources

| Source | Credential | Scope | Useful signals | Confidence |
| --- | --- | --- | --- | --- |
| `GET /v1/token_plan/remains` | Subscription Key | One key in one service region and Team | Provider rows with current-interval and weekly usage, limits, status, and time fields | Live after a successful validated response |
| `mmx quota` | Provider-managed CLI credential | One active CLI identity and region | Presentation of the same remains endpoint | Live, but unsuitable as the app's primary source |
| Billing > Token Plan | Interactive web session | Current console identity and selected Team | Usage bar, plan state, assigned resources, Credits | Manual only |

Official references:

- [Token Plan overview](https://platform.minimax.io/docs/token-plan/intro)
- [Token Plan FAQ](https://platform.minimax.io/docs/token-plan/faq)
- [Token Plan for Teams](https://platform.minimax.io/docs/guides/pricing-token-plan-team)
- [Token Plan migration](https://platform.minimax.io/docs/token-plan/migration)
- [Mainland China Token Plan overview](https://platform.minimaxi.com/docs/token-plan/intro)
- [Mainland China Token Plan FAQ](https://platform.minimaxi.com/docs/token-plan/faq)
- [MiniMax CLI](https://platform.minimax.io/docs/token-plan/minimax-cli)
- [API error codes](https://platform.minimax.io/docs/api-reference/errorcode)
- [API rate limits](https://platform.minimax.io/docs/guides/rate-limits)
- [Official CLI quota endpoint](https://github.com/MiniMax-AI/cli/blob/3615170a2e26ec6003c4550cd1324b55ec8ad677/src/client/endpoints.ts)
- [Official CLI region mapping](https://github.com/MiniMax-AI/cli/blob/3615170a2e26ec6003c4550cd1324b55ec8ad677/src/config/schema.ts)
- [Official CLI quota types](https://github.com/MiniMax-AI/cli/blob/3615170a2e26ec6003c4550cd1324b55ec8ad677/src/types/api.ts)
- [Official CLI sanitized quota fixture](https://github.com/MiniMax-AI/cli/blob/3615170a2e26ec6003c4550cd1324b55ec8ad677/test/fixtures/quota-response.json)

The FAQ examples use `www.minimax.io` and `www.minimaxi.com`. The official CLI
uses `api.minimax.io` and `api.minimaxi.com`. Both host families are
provider-owned and answered the unauthenticated probe, but a credential-backed
probe must confirm equivalent successful response behavior before an adapter
selects canonical hosts.

## Authentication and region boundary

The documented request uses:

```http
Authorization: Bearer <Subscription Key>
Content-Type: application/json
```

The official CLI's normal quota request also uses Bearer authentication. Its
region detector additionally tries `x-api-key`, but that is not the documented
quota contract and must not become an AI Limitbar fallback without separate
evidence.

Global and Mainland China are explicit Product Surface configuration:

| Region | API host used by the official CLI | Console and documentation |
| --- | --- | --- |
| `global` | `https://api.minimax.io` | `platform.minimax.io` |
| `cn` | `https://api.minimaxi.com` | `platform.minimaxi.com` |

Region is selected with the saved account and is never guessed on every
refresh. A one-time connection flow may test both documented regions in memory,
as the official CLI does, but it must discard all response bodies and retain
only the selected region after an unambiguous success. A failure in both
regions is an authentication or connectivity failure, not permission to fall
back permanently to Global.

The Subscription Key is separate from a standard pay-as-you-go API key. It can
exist before the Team assigns a Token Plan seat or Credits, so a syntactically
valid key does not prove that usable capacity exists.

## Account and Team semantics

Every MiniMax user receives a personal Default Team. Regular Teams can assign
Token Plan seats one-to-one to members and can expose a shared Credits pool.
Each member uses their own Subscription Key for the Team. Reassigning a seat
does not reset its current usage state; the new assignee inherits that state.

Consequences for AI Limitbar:

- one saved account represents one declared Team context in one region;
- the root context kind is `team`, including the personal Default Team;
- the display name is user-configured and does not come from an upstream opaque
  Team identifier;
- each Subscription Key occupies a separate Keychain item;
- no response field currently documented for `/remains` proves owner or Team
  identity;
- AI Limitbar never auto-groups keys and never copies capacity between saved
  accounts;
- Team Owner or Admin management, seat assignment, member inventory, and shared
  Credits access management are out of scope.

This design can isolate several configured keys locally, but independent
upstream account and Team isolation remains unverified until a real matrix is
probed.

## Signal semantics

The official CLI version inspected by this research models each
`model_remains` row with:

- `model_name`;
- `start_time`, `end_time`, and `remains_time`;
- `current_interval_total_count` and
  `current_interval_usage_count`;
- optional `current_interval_remaining_percent`;
- `current_weekly_total_count` and `current_weekly_usage_count`;
- optional `current_weekly_remaining_percent`;
- `weekly_start_time`, `weekly_end_time`, and `weekly_remains_time`;
- optional interval and weekly status values;
- optional `weekly_boost_permille`.

The CLI treats timestamps and remaining durations as milliseconds. It defines
status `1` as limited, `2` as exhausted, and `3` as unlimited, and applies the
weekly boost multiplier only to display percentage. These are official CLI
implementation semantics, not a complete API reference. A production parser
must still validate every type and range.

Current Global product documentation no longer establishes that row counts are
requests, characters, images, or generations. AI Limitbar therefore preserves
them as a provider-defined included-usage unit until a sanitized successful
response and current provider documentation establish a narrower native unit.
It must not label them as requests or fabricate modality-specific meters.

Mapping rules:

- the current interval is a rolling window, not a fixed reset period;
- the weekly interval is a separate window and is never merged with the
  5-hour value;
- reported usage and total counts remain native provider-defined values;
- remaining may be derived only as `limit - consumed`, with an explicit
  derivation;
- provider-reported percentages are presentation values and do not replace
  native counts;
- `status == 3` maps to unlimited without fabricating a finite limit;
- exhausted, zero, negative, boosted, missing, and unknown values are preserved
  rather than clamped;
- `model_name` is used only to select a reviewed adapter mapping and is not
  persisted as an opaque account identifier;
- unknown rows are ignored with a diagnostic, not silently relabeled;
- purchased Credits are not emitted as a metric unless a documented response
  field and its unit are verified. The current CLI quota type and public
  fixture do not expose a Credits balance.

## Capability map

| Capability | Result |
| --- | --- |
| Quota windows | Supported by the remains endpoint after success-shape verification |
| Reset schedule | Supported as provider interval/window time fields after unit verification |
| Credits balance | Product capability documented; machine-readable remains field not established |
| Pay-as-you-go balance or spend | Unsupported by this source |
| Requests, characters, images, generations | Legacy/region-specific semantics; not safe as the current universal mapping |
| History | Unsupported |
| Session usage | Unsupported |
| Per-turn usage | Unsupported |
| RPM/TPM limits | Provider documentation exists, but the remains response does not establish account-specific values |

Primary value is a live subscription-capacity view for coding, agent, and
multimodal users. It does not provide billing history or per-session analytics.

## Sanitized probe evidence

On 2026-07-23, read-only probes were sent to the Global and Mainland China
`api` hosts and to the `www` hosts shown in the FAQ. Each request emitted only
the effective URL, HTTP status, content type, top-level field names,
`base_resp` field names, numeric business status, and presence/type flags. No
credential, raw body, status message, profile field, opaque identifier, quota
quantity, or response row was emitted or retained.

Observed without authentication and with a fixed invalid probe token:

- all four host variants returned HTTP 200 JSON;
- Global and China API hosts returned only the `base_resp` top-level field;
- both missing and invalid Bearer authentication produced business status
  `1004`;
- invalid `x-api-key` authentication also produced business status `1004`;
- no `model_remains` field was present in any failure response.

This proves that HTTP success is not provider success. An adapter must validate
`base_resp.status_code == 0` before reading quota rows. It must never interpret
a missing `model_remains` array on a business-error response as empty or
exhausted capacity.

An additional Global probe used a real Subscription Key whose subscription was
explicitly reported by its owner as expired. The key was loaded from a
mode-`0600` Codex environment file, used only in process memory, and never
printed. Both the official CLI `api` host and the FAQ `www` host returned the
same sanitized shape:

- HTTP 200 JSON;
- top-level `base_resp` and `model_remains` fields;
- business status `2062`;
- a present `model_remains` field with a `null` value;
- identical sanitized host shapes.

The current official error-code reference does not document `2062`. Because
the credential owner independently established the expired-subscription state,
AI Limitbar may classify this exact observed combination as an unavailable
subscription resource, but diagnostics must preserve that the provider status
is undocumented. It must not collapse `2062` into invalid authentication:
missing and fixed invalid credentials produced `1004` and omitted
`model_remains`, which is a distinct response shape.

The official CLI repository supplies a public sanitized success fixture and
typed success model, which are sufficient for fixture design but do not replace
credential-backed Global, China, Team, and multi-account probes.

## Refresh, failure, and privacy behavior

The endpoint is a small HTTPS JSON read compatible with a trusted `URLSession`
adapter. No browser session, CLI process, Node runtime, helper executable, or
additional dependency is required.

MiniMax does not document an expiry for quota reads. A future adapter should:

- use the application's bounded polling interval;
- record `observedAt` for every accepted snapshot;
- use source-provided window times only after validating millisecond units;
- preserve the last valid snapshot on transport, authentication, business-code,
  decoding, or partial-row failure;
- record last success and latest failure separately;
- avoid busy retries and honor transport retry guidance when present.

Safe business-error projection:

| Business status | Safe category |
| --- | --- |
| `1004`, `2049` | Authentication, wrong region, inactive key, or unavailable Team resource |
| `1002`, `2045` | Throttled |
| `2056` | Usage limit exhausted |
| `2062` with `model_remains: null` | Subscription resource unavailable; observed with an owner-confirmed expired Global subscription, but undocumented |
| `1008` | Insufficient balance/resource |
| `1000`, `1001`, `1024`, `1033` | Transient provider failure |
| unknown nonzero status | Provider failure |

The provider's `status_msg`, response body, headers that can identify an
account, and unknown payload fields are never logged or persisted. Diagnostics
contain only the region, source ID, fixed local error category, observation
time, and retry metadata selected by trusted code.

## Source selection and fallback

The direct documented API is the only recommended production source.

- `mmx quota` is a useful provider-owned verification oracle, but it owns a
  single active CLI identity, stores credentials outside AI Limitbar, adds a
  Node dependency, and cannot represent several saved accounts safely.
- Authenticated web is manual fallback only. There is no additional value that
  justifies cookies, embedded sign-in, DOM maintenance, or Team-navigation
  ambiguity while a documented endpoint exists.
- A standard pay-as-you-go API key is a different Product Surface and is never
  used as a fallback for a Subscription Key.
- Global and China are explicit account configuration, not silent fallbacks.

## Fixture and test strategy

Production adapter fixtures must be hand-authored from official fields and
sanitized probe shapes. They must never copy a real response. Coverage should
include:

- HTTP 200 with `base_resp.status_code == 0`;
- HTTP 200 with every mapped nonzero business status;
- the observed undocumented expired-subscription variant with status `2062`
  and a present, null `model_remains`;
- missing `base_resp`, missing `model_remains`, empty rows, unknown rows,
  duplicate rows, unknown fields, wrong types, malformed numbers, and
  non-finite values;
- 5-hour rolling and weekly windows with independently changing usage;
- timestamp and duration values in the verified unit, including past, zero, and
  inconsistent bounds;
- limited, exhausted, unlimited, unavailable, and boosted statuses;
- reported percentages that disagree with counts, without silent correction;
- purchased Credits absent from the quota response;
- Global and China endpoint selection with no cross-region fallback after
  account setup;
- Default Team and regular Team contexts;
- two keys for one user in separate Teams and two independently authenticated
  users, with separate Keychain items, refresh results, snapshots, and
  diagnostics;
- cancellation, timeout, offline, 429/5xx transport failures, and a non-JSON
  response;
- absence of credentials, raw messages, upstream user/Team identifiers,
  provider response rows, and unknown fields from storage and logs.

The synthetic Provider Integration Contract fixture demonstrates only that the
shared model can express regional Team contexts, provider-defined quota
windows, unlimited capacity, and boost. It does not prove authentication,
response shape, account ownership, or Team isolation.

## Remaining implementation gate

Before a separate implementation Project can be created, run sanitized probes
that emit schema and relationship facts only:

1. One active Global Subscription Key in a Default Team.
2. One active Global Subscription Key in a regular Team, when available.
3. One active Mainland China Subscription Key, when available.
4. Two Subscription Keys for one user in different Teams.
5. Two independently authenticated users.
6. A key with purchased Credits and, separately, a key with no assigned paid
   resource. The expired Global key already covers the unavailable-subscription
   response variant but not a valid key with active Credits-only access.
7. Natural exhausted, unlimited, boosted, partial, and throttled variants when
   encountered; do not generate paid usage or load to force them.
8. The same successful key against the documented `www` host and official CLI
   `api` host to select one canonical endpoint. Host equivalence is verified
   only for invalid and expired-resource responses so far.

The probe must output only field names, JSON types, null/presence flags,
business status codes, equality booleans, region/host labels, and coarse
relationship results. It must not output credentials, quantities, plan names,
model names, Team names or IDs, timestamps, raw responses, or provider
messages.

## Recommendation

Keep LMB-11 as a completed research decision only after review of this limited
result:

- decision vocabulary: `documented-interface`;
- default confidence after a successful parse: `live`;
- source maturity until credential-backed verification: `experimental`;
- supported boundary: one explicit region + Team + Subscription Key per saved
  account;
- production recommendation: do not implement yet;
- next action: collect the bounded sanitized matrix above, then either approve
  a finite quota-window MVP or record a negative result if the account boundary
  or response contract cannot be established.
