---
name: VPS Scripts
description: Neon-shell terminal UI for modular Linux VPS operations
colors:
  primary: "#00CDCD"
  accent-rule: "#CDCD00"
  success: "#00CD00"
  warning: "#CDCD00"
  danger: "#CD0000"
  step: "#CD00CD"
  title: "#E5E5E5"
  muted: "#808080"
  gradient-start: "#00FF00"
  gradient-mid: "#80FF00"
  gradient-end: "#FFFF00"
  bright-primary: "#00D7D7"
  bright-success: "#00D700"
  bright-warning: "#D7D700"
  bright-danger: "#D70000"
  bright-step: "#D700D7"
  bright-title: "#FFFFFF"
typography:
  display:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: "1rem"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "0em"
  title:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: "1rem"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "0em"
  body:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "0em"
  label:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "0em"
rounded:
  none: "0px"
spacing:
  ui-min: "24ch"
  ui-default: "80ch"
  ui-max: "88ch"
  narrow-break: "64ch"
  wide-art: "82ch"
  menu-label: "20ch"
  key-column: "14ch"
components:
  menu-item:
    backgroundColor: "transparent"
    textColor: "{colors.title}"
    typography: "{typography.body}"
    rounded: "{rounded.none}"
    padding: "0"
  menu-item-key:
    backgroundColor: "transparent"
    textColor: "{colors.warning}"
    typography: "{typography.label}"
    rounded: "{rounded.none}"
  menu-item-detail:
    backgroundColor: "transparent"
    textColor: "{colors.muted}"
    typography: "{typography.label}"
    rounded: "{rounded.none}"
  panel-title:
    backgroundColor: "transparent"
    textColor: "{colors.title}"
    typography: "{typography.title}"
    rounded: "{rounded.none}"
    padding: "0 0 0 2ch"
  header-rule:
    backgroundColor: "transparent"
    textColor: "{colors.accent-rule}"
    rounded: "{rounded.none}"
  log-info:
    backgroundColor: "transparent"
    textColor: "{colors.primary}"
    typography: "{typography.body}"
    rounded: "{rounded.none}"
  log-success:
    backgroundColor: "transparent"
    textColor: "{colors.success}"
    typography: "{typography.body}"
    rounded: "{rounded.none}"
  log-warn:
    backgroundColor: "transparent"
    textColor: "{colors.warning}"
    typography: "{typography.body}"
    rounded: "{rounded.none}"
  log-error:
    backgroundColor: "transparent"
    textColor: "{colors.danger}"
    typography: "{typography.body}"
    rounded: "{rounded.none}"
---

# Design System: VPS Scripts

<!-- impeccable:design-map -->
Name: VPS Scripts
Colors: primary: primary #00CDCD; secondary: accent-rule #CDCD00; tertiary: gradient-start #00FF00; neutral: title #E5E5E5; primary: success #00CD00; primary: danger #CD0000 (+11 more in the sidecar)
Fonts: ui-monospace (display, title, body, label)
Spacing: ui-min 24ch, ui-default 80ch, ui-max 88ch, narrow-break 64ch, wide-art 82ch, menu-label 20ch, key-column 14ch
Radius: none 0px
North Star: "霓虹机柜"
Rules:
- The One Signal Rule. Each line carries at most one semantic accent role (info, success, warn, error, step, or frame).
- The Gradient Cage Rule. The lime→yellow gradient exists only for the wide ASCII wordmark.
- The Display-Width Rule. Measure Chinese and wide glyphs with `text_display_width` (or equivalent); never pad by raw string length alone.
- The Clamp Rule. Never draw UI wider than 88 columns; never assume fewer than 24.
- The Flat Cabinet Rule. Structure with horizontal rules and color roles; never fake Material elevation in the shell UI.
- The Cell Geometry Rule. If a control cannot be expressed with monospace characters and ANSI color, it does not belong in `neon-shell`.
Don't:
- Don't invent CSS cards, shadows, or rounded pills for the terminal product surface.
- Don't apply the header gradient to menus, logs, or body copy.
- Don't pack emoji walls or multi-hue single lines that break the One Signal Rule.
- Don't hard-code padding with `${#string}` when CJK width matters.
- Don't present the legacy launcher as the visual source of truth for new chrome — extend the modular `vps.sh` + shared helper patterns.
Do:
- Do keep Chinese menu copy and display-width-aware alignment.
- Do use semantic colors for status and cyan/yellow for navigation/structure only.
- Do collapse layout at 64 and 82 the way the launcher already does.
- Do prefer dim secondary text over extra accent colors for hints.
- Do treat `neon-shell` as the theme id when documenting or extending UI helpers.
- Do prefer hub + submenu cabinets once a flat menu exceeds roughly a dozen actionable items.
Map: vps.sh
Map: lib/common_functions.sh
Full: .impeccable/design-full.md (read a section when you need its detail)
