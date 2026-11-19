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

## Overview

**Creative North Star: "霓虹机柜"**

VPS Scripts presents itself as a neon operations cabinet inside SSH: calm, high-contrast, and readable under real terminal constraints. Color is semantic signal — cyan for navigation and info, yellow for structure and attention, green for safe completion, red for failure, purple for stepped progress — never decoration for its own sake. Density stays medium: enough structure for a dashboard scan, not a wall of chrome.

The shipped surface is the `neon-shell` ANSI terminal UI in `vps.sh` and `lib/common_functions.sh`. There is no browser chrome, card elevation, or icon system. Hierarchy comes from rules, bold titles, numbered keys, and dim secondary copy. Wide terminals may show a lime-to-yellow ASCII wordmark; narrow ones drop art and stack menu details without losing scan order.

**Key Characteristics:**
- Terminal-first monospace layout capped at 88 columns
- Semantic status colors over ornamental palette sprawl
- Dashboard-crisp menus: key, bold label, dim detail
- Flat depth: rules and contrast instead of shadows
- Chinese UI copy with display-width-aware alignment

## Colors

A bright-on-dark ANSI cabinet: one cyan voice for orientation, yellow metal for frames, and strict status hues for outcomes.

### Primary
- **Cabinet Cyan** (`#00CDCD`, ANSI `0;36` in the launcher): labels, subtitles, progress bars, and info logs. The default “you are here” color.
- **Bright Cabinet Cyan** (`#00D7D7`, ANSI `1;96` in the shared library): brighter twin used when modules source `common_functions.sh`.

### Secondary
- **Frame Amber** (`#CDCD00`, ANSI `0;33`): header top/bottom rules and menu keys. Marks structure and selectable affordances.
- **Step Violet** (`#CD00CD`, ANSI `0;35`): panel underlines and step markers from `print_step` in `lib/common_functions.sh` (bracketed index over total).

### Tertiary
- **Signal Lime → Amber ramp** (`#00FF00` → `#80FF00` → `#FFFF00`): wide-header ASCII wordmark only (`GRADIENT_COLORS`). Do not reuse as body text color.

### Neutral
- **Title White** (`#E5E5E5`, ANSI `0;37` / bold): primary titles and menu labels.
- **Dim Rail** (`#808080`, ANSI dim / approximate): secondary details, hints, author line, URL chrome.
- **Bright Title** (`#FFFFFF`, ANSI `1;97`): library header titles when modules use bright white.

### Status
- **Safe Green** (`#00CD00` / bright `#00D700`): success, safe-path slogans, wait completion.
- **Alert Amber** (same family as Frame Amber): warnings.
- **Fault Red** (`#CD0000` / bright `#D70000`): errors only.

**The One Signal Rule.** Each line carries at most one semantic accent role (info, success, warn, error, step, or frame). Do not rainbow a single message.

**The Gradient Cage Rule.** The lime→yellow gradient exists only for the wide ASCII wordmark. Everywhere else uses flat ANSI roles.

## Typography

**Display Font:** ui-monospace / SFMono / Menlo / Consolas (terminal face)
**Body Font:** same monospace stack
**Label/Mono Font:** same stack (no second family)

**Character:** Instrument panel type — bold for titles and menu names, dim for secondary rails, never decorative display serifs.

### Hierarchy
- **Display** (bold, ~1 terminal row, line-height ~1.2): centered product title in the header (“VPS 脚本集合 …”).
- **Title** (bold white in `[ Panel ]` form): section / panel headings via `print_panel_title` / `print_title`.
- **Body** (regular): menu labels, values, running copy.
- **Label** (regular or dim): cyan keys in kv rows, yellow numeric menu keys, dim detail strings.

**The Display-Width Rule.** Measure Chinese and wide glyphs with `text_display_width` (or equivalent); never pad by raw string length alone.

## Layout

Spatial model is a single centered column of character cells. Default canvas is 80 columns; detect from `COLUMNS` / `tput cols` / `VPS_UI_WIDTH`; clamp to 24–88.

- **Wide (≥82):** optional ASCII wordmark block under the subtitle.
- **Comfortable (≥64):** menu detail stays on the same row after a dim `│` gutter; menu label column targets 20 display columns.
- **Narrow (<64):** menu detail wraps to the next line under a dim `└─` rail.
- **KV rows:** cyan key, pad toward a 12–14 column key gutter; if the row would overflow `UI_WIDTH`, wrap the value indented four spaces.

Rhythm is vertical: blank line, rule, content, rule — not a CSS grid. Clear the screen before major launcher headers when stdout is a real TTY.

**The Clamp Rule.** Never draw UI wider than 88 columns; never assume fewer than 24.

## Elevation & Depth

No shadows, blurs, or layered cards. Depth is contrast and rules only: yellow/cyan/`=` frames around the header, purple/`=` under panel titles, dim text for subordinate rails, bold white for primary scan targets.

### Shadow Vocabulary
None. Do not introduce drop shadows in terminal approximations or future web mirrors of this system unless the product explicitly gains a non-terminal surface with its own world.

**The Flat Cabinet Rule.** Structure with horizontal rules and color roles; never fake Material elevation in the shell UI.

## Shapes

Form language is the character cell. Corners are square (`0` radius). Separators are repeated `=` (headers) or `-` (module titles). Menu secondary cues use `│` (inline) and `└─` (wrapped). No pills, rounded chips, or bordered cards.

**The Cell Geometry Rule.** If a control cannot be expressed with monospace characters and ANSI color, it does not belong in `neon-shell`.

## Components

Dashboard-crisp: high-scan menus and status lines, minimal ornament.

### Menu item (`print_menu_item`)
- **Shape:** flush left, no box
- **Key:** yellow, two-wide numeric / `0`
- **Label:** bold title white
- **Detail:** dim; same-row after `│` when width ≥64, else wrapped `└─`
- **Behavior:** keep label column stable (~20 display cols) so numbers form a vertical dashboard rail

### Header (`print_header` in launcher)
- **Shape:** full-width yellow `=` rules
- **Title:** bold centered white product name + version
- **Subtitle:** centered cyan launcher/style line
- **Optional art:** lime→yellow ASCII only when width ≥82
- **Footer lines:** recommended links as cyan-labeled kv; green safety slogan; dim author

### Panel title (`print_panel_title` / `print_title`)
- **Shape:** `  [ Name ]` plus purple rule (`=` in launcher panels; `-` in module `print_title`)
- **Role:** marks the active cabinet drawer before menu items
- **Hub drawers:** long categories use a hub menu then a nested panel titled `分类 · 子柜` (for example `服务安装 · 控制面板`)

### Menu section (`print_menu_section`)
- **Shape:** dim `── label` on its own line
- **Role:** light grouping inside a single flat menu (proxy tools: 面板 / 一键脚本 / 官方核心)
- **Constraint:** section labels are not selectable and carry no accent color beyond dim

### Menu cabinet (hub + submenu)
- **Shape:** hub lists category drawers with short details; each drawer is a separate loop with `0` returning up one level
- **Behavior:** EOF / failed `read_menu_choice` returns to the parent cabinet; invalid keys call `invalid_choice` and re-render
- **Where:** service install, community scripts, other tools

### Log line (`print_info` / `print_success` / `print_warn` / `print_error`)
- **Shape:** `[信息]|[完成]|[警告]|[错误]` prefix + message
- **Colors:** cyan / green / yellow / red respectively
- **Hover / Focus:** N/A (stdout); keep prefixes stable for grepping

### Progress / wait
- **Progress:** cyan `[====    ] nn%` bar (default fill width 50)
- **Wait spinner:** cyan rotating frames from the spinner characters inside `wait_with_animation` in `lib/common_functions.sh`, then green `OK` completion line

### Key/value (`print_labeled_value` / `print_aligned_value`)
- **Style:** cyan label, padded gutter, plain value
- **Overflow:** stack value on the next indented line rather than truncating silently

## Do's and Don'ts

### Do:
- **Do** keep Chinese menu copy and display-width-aware alignment.
- **Do** use semantic colors for status and cyan/yellow for navigation/structure only.
- **Do** collapse layout at 64 and 82 the way the launcher already does.
- **Do** prefer dim secondary text over extra accent colors for hints.
- **Do** treat `neon-shell` as the theme id when documenting or extending UI helpers.
- **Do** prefer hub + submenu cabinets once a flat menu exceeds roughly a dozen actionable items.

### Don't:
- **Don't** invent CSS cards, shadows, or rounded pills for the terminal product surface.
- **Don't** apply the header gradient to menus, logs, or body copy.
- **Don't** pack emoji walls or multi-hue single lines that break the One Signal Rule.
- **Don't** hard-code padding with `${#string}` when CJK width matters.
- **Don't** present the legacy launcher as the visual source of truth for new chrome — extend the modular `vps.sh` + shared helper patterns.
