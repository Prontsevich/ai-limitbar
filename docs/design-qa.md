# Design QA

## Source Visual Truth

- Codex CLI `/status` reference screenshot (temporary clipboard capture, no longer available).
- lazygit reference screenshot (temporary clipboard capture, no longer available).

## Implementation Screenshots

All screenshots below were temporary clipboard captures that are no longer
available. The findings and fixes remain valid.

- Dashboard before the current fix.
- Details popover before the current fix.
- Dashboard before the current controls and status-policy fix.

## Comparison State

- Menu-bar popover at its 390-point width in Dark appearance.
- Source screenshots: six enabled accounts, two accounts with limit windows,
  and visible warning copy.
- Source details screenshot: Ollama account with a successful refresh and a
  compatibility diagnostic; the current policy no longer promotes that
  diagnostic to a visible warning state.

## Findings

- [P1] Fieldset legends sit in the main panel area rather than centered in the
  top-border gap, and they move when Refresh changes to a spinner.
  Fix applied: legend and controls are independent overlays; the spinner now
  occupies the same fixed 14-point frame as the refresh glyph.
- [P1] Account controls are too low and too close together.
  Fix applied: controls are independently centered on the border, use 22-point
  hit targets, and have a seven-point gap.
- [P2] The meter fill reads as an amber warning even for normal usage.
  Fix applied: every normal usage meter now uses the same muted-gold color as
  its structural border. Green is used for successful refresh status, amber for
  warning or stale copy, and red for failures.
- [P2] Flat controls have no hover affordance.
  Fix applied: terminal text and glyph controls now show a subtle neutral hover
  fill and a stronger pressed fill without becoming pill buttons.
- [P1] The account-list viewport grows instead of scrolling, and the first
  account legend is clipped beneath the dashboard header.
  Fix applied: the list has a visible vertical scroll indicator and a 10-point
  legend clearance above its first panel. Its device-local viewport preset is
  Compact (320 pt), Standard (460 pt), or Tall (640 pt), so long account lists
  can show more rows without growing the popover indefinitely.
- [P1] The fieldset breaks are much wider than their legends, and close panels
  let a following legend mask the previous panel's lower border.
  Fix applied: the legend background now wraps its intrinsic text width rather
  than the title's maximum layout width, and inter-panel spacing is 14 points.
- [P2] The controls mask the top-right fieldset corner.
  Fix applied: the controls are shifted 12 points left while preserving their
  hit targets and the visible gap between Refresh and Info.
- [P1] A successful experimental source is elevated to a visible warning solely
  because of its compatibility note.
  Fix applied: a successful `.appServer` or `.ollamaWebPage` snapshot remains
  `OK`; only real usage thresholds, stale data, or failures produce warning
  state. The experimental label remains visible as source context.

## Full-View Comparison Evidence

The two implementation screenshots made the P1 and P2 findings above visible.
The revised build has not yet been captured in the same state, so the post-fix
full-view comparison cannot be completed.

## Focused Region Comparison Evidence

The account legend and control strip, the outlined meter, and the details
refresh row were inspected in the supplied screenshots. The code now directly
addresses their geometry and semantic color mapping, but no post-fix native
capture is available for visual confirmation.

## Comparison History

1. The first rounded-card dashboard was rejected as visually unlike the target.
2. The terminal-fieldset redesign established the status-inspector direction.
3. The supplied native screenshots revealed legend/control geometry, meter-color,
   success-color, and hover-state mismatches; the fixes above were implemented.
4. A second supplied dashboard screenshot revealed a growing viewport, clipped
   first legend, oversized fieldset breaks, and damaged adjacent borders; the
   corresponding layout fixes were implemented.
5. A later supplied dashboard screenshot confirmed the structural fixes and
   revealed the obscured fieldset corner and experimental-source warning state;
   the corresponding layout and status-policy fixes were implemented.
6. A later product decision added persisted Compact, Standard, and Tall
   dashboard viewport presets; code, Settings copy, and the design contract were
   updated, but no native post-fix capture is available yet.
7. Computer Use still cannot inspect `AILimitBar`, its bundle identifier, or
   `SystemUIServer`; every attempt ends with
   `Computer Use server error -10005: timeoutReached`.

## Final Result

blocked
