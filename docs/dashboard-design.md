# Menu Bar Dashboard Design

## Status And Scope

This is the approved design brief for the menu bar dashboard and the
account-details popover. It is the implementation contract for Milestone 17.

The scope is limited to `MenuBarPanelView`, dashboard account presentation, and
`AccountDetailsView`. It deliberately excludes Settings redesign, provider
adapters, refresh semantics, persistence, and the `UsageSnapshot` contract,
except for a device-local dashboard-height preference.

## Outcome

The menu bar panel is a fast, all-account status dashboard. A person should be
able to answer these questions without opening a detail view:

- Which account is this?
- How much of each known limit has been used?
- When does that limit reset?
- Is an account refreshing, stale, failed, manual-only, or unavailable?

Technical provenance and timestamps belong in the on-demand details popover.

## Visual System

The dashboard uses a compact terminal-fieldset composition rather than Liquid
Glass cards. The visual references are Codex CLI `/status` for the inspector
typography and outlined usage meter, and lazygit for the dense nested-panel
grid. They guide the visual grammar; the app does not imitate ANSI escape codes
or become a text-mode interface.

- Each account is enclosed by a thin muted-gold bordered panel with a small
  corner radius.
- The account name interrupts the upper border, like a `fieldset` legend. Its
  vertical placement is independent from the right-aligned controls, so a
  refresh spinner cannot move the legend or overlap the border.
- Legend and control masks cover only their intrinsic content, never a reserved
  maximum title width. Account panels leave enough vertical spacing for those
  masks without breaking a neighbouring panel's lower border.
- There are no glass effects, translucent surfaces, gradients, shadows, large
  corner radii, or card hover scaling on these two surfaces.
- Use an adaptive warm paper/charcoal surface, muted-gold structural borders,
  and restrained green, amber, and red semantic status colors. The dark
  screenshots are style references, not a fixed color-mode requirement.
- Use monospaced labels and values, tight vertical rhythm, aligned label/value
  rows, and one-pixel separators associated with a developer status tool.
- Usage meters are thin rectangular outlined meters with a muted-gold fill that
  matches the structural border; do not use the default `ProgressView` track on
  these surfaces. Green is reserved for successful status copy, amber for
  warning/stale copy, and red for failure copy.
- Actions remain SwiftUI controls but use flat text or glyph presentation rather
  than prominent system pill buttons. They have a subtle neutral hover fill and
  a pressed state, without card scaling or a pill-shaped hover treatment.

This is an intentional product-specific composition. Standard SwiftUI controls
must still provide pointer, keyboard, focus, accessibility, disabled, and
pressed behavior for all interactive elements.

## Dashboard Layout

### Header

- The panel title is `AI Limitbar`.
- A glyph-only Refresh All control sits in the upper-right corner and invokes
  the existing global refresh path.
- While the global refresh runs, that control presents progress and cannot be
  invoked again.

### Account Panels

- Render enabled accounts in the user-defined order.
- Use the globally unique account display name as the fieldset legend. Do not
  repeat the provider name in the normal dashboard body.
- Account display names are globally unique. When a legend does not fit beside
  its controls, truncate it with a tail ellipsis and expose the complete name in
  a tooltip and accessibility label.
- Place a glyph-only individual Refresh control and an explicit Info control in
  the upper-right portion of each account border. Center both on the border,
  reserve a visible gap between their hit targets, and preserve the same
  dimensions while Refresh swaps its glyph for progress. Inset the group enough
  to leave the fieldset's top-right corner visible.
- Leave a small top clearance before the first account so its legend cannot
  overlap the dashboard header. Cap the account-list viewport at a compact
  height and use a visible vertical scroll indicator for additional accounts.
  Settings offers `Compact` (320 pt), `Standard` (440 pt), and `Tall` (640 pt)
  viewport presets. The value is a local `UserDefaults` preference, not
  provider or account data. Each preset sets the visible viewport height and
  account lists scroll within it.
- Individual Refresh invokes the existing per-account refresh path. It shows
  progress and is disabled while that account or a global refresh is running.
- Info opens the account-details popover. It must have an accessible label and
  must remain available without relying on hover.

### Usage Windows

For each known limit window, render only:

1. The provider-defined window label, such as `5-hour` or `7-day`.
2. One right-aligned `NN% used` value.
3. One compact rectangular outlined usage meter.
4. A relative reset label when a reset date is available, such as
   `resets in 2 hours`.

Do not show a second remaining percentage or a normal-state `Updated` timestamp
in an account panel. Use restrained accent colors for progress and reserve
warning/error colors for meaningful thresholds or exceptions. Color must not be
the only indication of state.

### State Visibility

- Normal or successfully refreshed accounts show no extra status copy.
- A refreshing account communicates progress through its individual Refresh
  control, not a permanent status row.
- Stale data has a compact visible `Stale` label.
- Failed refreshes have a compact warning indication; the detailed cause is in
  the Info popover.
- Manual-only, unavailable, and no-data accounts state that condition in the
  account body instead of inventing a progress bar.
- A successful experimental source remains `OK`; its `Experimental` source
  label is informational. Amber warning state is reserved for real usage
  thresholds, stale data, or failed refreshes.

The dashboard should not scroll for common setups of three to five accounts.

## Account Details Popover

The Info control opens a compact technical inspector in the same terminal-
fieldset visual system. It is not a second dashboard and does not repeat the
usage bars. The popover uses one outer inspector fieldset with aligned
monospaced label/value rows, separated by thin rules. Diagnostics are the only
inner bordered block and use a `NOTE`-style label.

It contains:

- Account identity and current refresh state.
- The precise last-updated date and time.
- Source and confidence.
- Exact reset dates when available.
- Warning, stale, and failed-refresh context in a clearly labeled bordered
  message block.
- Secondary account actions such as Test Connection and Open Usage. Do not
  duplicate the normal individual Refresh action here.

The popover may scroll only when diagnostic content genuinely exceeds the
compact inspector height.

## Accessibility And Interaction

- Glyph-only Refresh and Info controls require visible keyboard focus, tooltips,
  and descriptive accessibility labels.
- Progress bars expose the window name and used percentage to accessibility
  clients.
- Disabled refresh controls explain why they are unavailable through their
  accessibility state and tooltip where appropriate.
- The details popover remains reachable by pointer and keyboard; hover is only
  an optional convenience.

## Non-Goals

- Redesigning Settings.
- Changing refresh coordination or provider behavior.
- Changing storage or the normalized snapshot model.
- Adding history, charts, notifications, or a WidgetKit surface.
- Recreating terminal escape codes, text-mode controls, or literal ASCII art.

## Validation

- Build and run the staged menu-bar app.
- Verify global refresh, individual refresh, Info popover, and disabled states.
- Manually check normal, refreshing, stale, failed, manual-only, and no-data
  accounts in both Light and Dark appearance.
- Confirm that account ordering, progress accessibility values, and all existing
  details actions remain functional.
