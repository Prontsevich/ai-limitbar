# Settings Window Design

## Status And Scope

This is the approved design and window-lifecycle contract for Milestone 18. It
covers the Settings scene, the Settings entry action, window activation and
placement, and the terminal-adjacent presentation of the existing Settings
workspace.

The milestone preserves the current Accounts, Refresh, and Provider Setup
information architecture. It does not introduce General, localization, usage
thresholds, notifications, theme editing, provider credentials, or persistence
changes that belong to later milestones.

The current Refresh pane includes the refresh schedule and a device-local
Dashboard height picker with `Compact` (320 pt), `Standard` (440 pt), and `Tall`
(640 pt) maximum viewport presets. Milestone 22 moves both controls into
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

## Placement And Lifecycle

- Give a newly created Settings window a deterministic default size based on the
  current master-detail layout and center it within the default visible display.
- Clamp placement and size to the display's visible bounds so the menu bar and
  Dock do not cover required content.
- Preserve the user's position and size while the same window remains open.
  Reopening an already open window must not recenter it.
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
  clear fieldset labels for product-specific read-only groups.
- Use monospaced typography for file paths, provider/source identifiers,
  timestamps, percentages, and diagnostic values. Use the normal system font for
  navigation, field labels, descriptions, and editable prose.
- Keep native `List`, `Form`, `TextField`, `Picker`, `Toggle`, `Button`, `Menu`,
  alert, sheet, focus-ring, and keyboard behavior.
- Let the active window and native controls render the user's macOS accent color.
  Do not hardcode blue to imitate an active selection.
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

The read-only account detail may use bordered Status and Configuration groups.
Create and Edit modes remain form-oriented so fields, validation, Save, Cancel,
Return, and Escape behavior stay predictable.

## Interaction And Accessibility

- Opening Settings from behind another application activates AI Limitbar and
  makes the Settings window key.
- Native selection and segmented controls show the correct active/inactive macOS
  appearance instead of a custom selection fill.
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
- Recreating standard controls, focus rings, or selection behavior.
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
