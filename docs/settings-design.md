# Settings Window Design

## Status And Scope

This is the approved design and window-lifecycle contract for Milestone 18. It
covers the Settings scene, the Settings entry action, window activation and
placement, and the terminal-adjacent presentation of the existing Settings
workspace.

Implementation status (2026-07-13): the singleton scene, activation boundary,
placement, restoration policy, transient-state reset, visual redesign, and
manual Settings QA are complete. `swift build`, `swift test`, and staged-bundle
`--verify` passed.

Visual correction (2026-07-13): Settings uses one terminal interaction layer
for navigation, choices, selection, and actions. The earlier hybrid of native
blue segmented controls, grouped Form cards, and terminal fieldsets is not an
accepted presentation.

The milestone preserves the current Accounts, Refresh, and Provider Setup
information architecture. It does not introduce General, localization, usage
thresholds, notifications, theme editing, provider credentials, or persistence
changes that belong to later milestones.

The current Refresh pane includes the refresh schedule and a device-local
Dashboard height picker with `Compact` (320 pt), `Standard` (440 pt), and `Tall`
(640 pt) viewport presets. Milestone 22 moves both controls into
General; Milestone 18 preserves their behavior and stored values.

## Outcome

An explicit Settings action should always produce one active, key Settings
window in a predictable location. The window should feel related to the compact
terminal-fieldset dashboard while retaining native macOS editing, focus,
selection, accessibility, and Light/Dark behavior.

## Window Architecture

- Declare Settings as a singleton SwiftUI
  `Window("AI Limitbar Settings", id: "settings")` scene.
- Open it with `openWindow(id: "settings")`. Calling the action while the window
  is already open brings that window forward instead of creating another one.
- Immediately before opening, call the current `NSApplication.activate()` API
  from one narrow platform helper because the staged app is an `LSUIElement`.
- Keep all Settings content and transient state in SwiftUI. Do not create an
  AppKit-owned `NSWindow`, `NSPanel`, or `NSWindowController`.
- Do not change the app to a regular Dock application and do not keep Settings
  above other apps with a floating window level. The explicit opening action
  brings it forward; normal macOS activation rules apply afterward.
- Keep only the native close control active. Disable minimize, resize, and full
  screen: Settings is a menu-bar utility surface and should be closed, not sent
  to the Dock or expanded into a primary app window.

## Placement And Lifecycle

- Give a newly created Settings window a deterministic default size based on the
  current master-detail layout and center it in the visible area of the display
  that hosts the menu-bar panel. Capture that display before activating the
  `LSUIElement` process; only if no host window is available, use the pointer
  display and then the system default display as fallbacks. After SwiftUI creates
  the window, center its real `NSWindow.frame` in that display's visible area.
- Clamp placement and size to the display's visible bounds so the menu bar and
  Dock do not cover required content.
- Preserve the user's position and size while the same window remains open.
  Reopening an already visible window must not recenter it. A closed or hidden
  SwiftUI window is repositioned using the display that hosts the new Settings
  action.
- Disable unwanted scene restoration. A window that the user closes must not
  return during launch, app activation, or a Spaces change.
- Closing and reopening resets the selected section to Accounts and clears
  editor mode, dirty state, pending navigation, and open confirmations.
- Keep resize constraints large enough for the account list and detail pane but
  do not assume a single display size or arrangement.

## Visual Relationship To The Dashboard

Settings is terminal-adjacent, not a literal terminal and not a clone of the
dashboard cards.

- Reuse compact spacing, thin borders, restrained semantic status colors, and
  clear fieldset labels for product-specific read-only and editor groups.
- Use the monospaced typography hierarchy consistently for Settings navigation,
  account lists, headings, field labels, descriptions, actions, and technical
  values. Native system dialogs may retain their platform typography.
- Use terminal segmented selectors, sidebar selection, toggles, and action
  buttons throughout Settings. They share the same border, selection, hover,
  and pressed states; active controls use the terminal palette, never the system
  blue accent.
- Use a terminal provider selector with a scrollable list, full keyboard focus,
  and arrow-key navigation, plus terminal text-field focus borders in the
  account editor. Keep the file importer, `Menu`, alert, sheet, and keyboard
  behavior native where macOS platform integration is the user-facing benefit.
- Use system-adaptive foregrounds and backgrounds in Light and Dark appearance.
  Do not make the dark dashboard reference a fixed Settings color scheme.
- Remove opaque list/sidebar backgrounds and decorative Liquid Glass treatments
  that compete with the thin fieldset composition.
- Do not introduce configurable dashboard theme tokens in this milestone.
  Milestone 25 owns custom palettes and app appearance preferences.

## Layout

The existing segmented top-level navigation remains for this milestone. Accounts
continues to use a local master-detail workspace.

```text
┌─ AI Limitbar Settings ─────────────────────────────────────┐
│        [ Accounts ]  [ Refresh ]  [ Provider Setup ]       │
├──────────────────┬─────────────────────────────────────────┤
│ ACCOUNTS         │ claude-main                    [Enabled]│
│                  │                                         │
│ > claude-main    │ ┌─ STATUS ────────────────────────────┐ │
│   ollama-work    │ │ Source       Managed statusLine     │ │
│   codex-main     │ │ Last update  08:14                  │ │
│                  │ │ State        Ready                  │ │
│                  │ └─────────────────────────────────────┘ │
│                  │                                         │
│                  │ ┌─ CONFIGURATION ─────────────────────┐ │
│                  │ │ Provider     Claude Code            │ │
│                  │ │ Snapshot     ~/.local/...           │ │
│                  │ └─────────────────────────────────────┘ │
│ [+] [−]      [↻] │             [Edit] [Test] [Open Usage] │
└──────────────────┴─────────────────────────────────────────┘
```

The read-only account detail uses bordered Status and Configuration groups.
Create and Edit use top-aligned `ACCOUNT` and `SOURCE` fieldsets instead of a
column `Form`, so custom source selectors cannot distort native form alignment.
Provider selection uses one compact terminal selector with a scrollable,
square-cornered terminal overlay with no decorative title. Space and Return open
the list; arrows move its focus, Tab enters the list and then moves through its
items, Space/Return select, and Escape closes it. The selector lists only
providers that can accept another account, so an already-configured
single-account Codex source is not selectable. Text fields have terminal focus
borders rather than system-blue rings. File importer, validation, Save, Cancel,
Return, and Escape behavior remain intact inside those groups.

Provider Setup lists only current provider sources and their usage actions. It
does not show a disabled Credentials placeholder; credential UI appears only
when a verified provider integration has an actionable requirement.

Accounts without a configurable source, such as the built-in Mock provider, do
not show a redundant source fieldset. Ollama Cloud and OpenAI Codex keep their
single current sources. Claude Code exposes a compact terminal selector for
Manual, managed `statusLine`, and experimental `/usage` CLI; source-specific
controls appear below it without changing the surrounding fieldset layout.

## Interaction And Accessibility

- Opening Settings from behind another application activates AI Limitbar and
  makes the Settings window key.
- Terminal selection and segmented controls use the same active/inactive palette
  as the dashboard fieldsets, with visible hover and pressed feedback. Each
  segment's full bordered cell is its pointer target; the control keeps a compact,
  fixed intrinsic height instead of stretching into unused window space.
- Every compact icon and text action has a visible hover target and preserves its
  descriptive accessibility label and help text.
- Add, delete, reorder, enable/disable, refresh, test connection, open usage,
  source selection, helper installation, Edit, Save, and Cancel remain reachable
  by their existing pointer and keyboard paths.
- Glyph-only actions retain descriptive accessibility labels and help text.
- Dirty drafts continue to use one discard confirmation when changing account or
  section. Closing and reopening must not resurrect the draft or dialog.
- Color supplements text and control state; it is never the only status signal.

## Non-Goals

- Changing provider, refresh, snapshot, or persistence contracts.
- Adding a Dock icon or converting AI Limitbar into a conventional main-window
  app.
- Using an always-on-top Settings panel.
- Recreating general text-editing controls, file panels, or dialogs. Terminal
  selectors and action buttons are intentional product-specific controls.
- Implementing a literal terminal, ASCII controls, or terminal escape colors.
- Moving Refresh into General before the localization milestone.
- Adding custom theme import, export, editing, or palette persistence.

## Validation

- Build and run the staged `LSUIElement` `.app` bundle.
- Open Settings while Finder and another regular application are active.
- Verify first open, repeated open, close/reopen, and no duplicate windows.
- Verify the initial position and resizing on the primary and a secondary display.
- Move between Spaces and confirm a closed Settings window does not reappear.
- Confirm active selection accent, keyboard focus, Return/Escape, and dirty-draft
  confirmation behavior.
- Exercise every existing account and provider action in Light and Dark
  appearance.
