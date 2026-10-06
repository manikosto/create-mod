# Terminal UI/UX for mods

A mod lives next to the conversation the person came for. It earns its pixels by being glanceable,
calm, and a little delightful. These are the rules the good mods here follow (deck, aside, dock, files),
and the mistakes the first drafts made.

## The design pass (before any code)

1. **Name the one question the mod answers at a glance.** deck: "what is Claude doing and how much room is
   left?" aside: "what happened, without disturbing it?" If you cannot say it in one line, the UI will
   sprawl.
2. **Draw an ASCII mockup at the real width** (a docked pane is ~40–80 columns; under the prompt is one
   row) with real content, not lorem ipsum, and show it to the user before writing code. Show 2–3 states:
   empty, busy, full/error.
3. **Rank the content.** One primary thing (bold, accent, top), two or three secondary (normal), the rest
   faint. If everything is bold, nothing is.
4. **Pick the interaction model**: read-only (glance), buttons (click / hotkey), or a Client (keyboard
   focus). Prefer the lightest one that works.

## Visual language

**Color is meaning, not decoration.**
- One accent per mod, used for its name, the active/primary thing and the focus mark. deck `#e8875b`,
  aside `#4fd6be`, files `#5cc8ff`, dock hands each pinned item its own from a bright palette.
- Fixed semantic colors across mods: success `#7fc77a`, warning `#e8c15b`, error `#e8645b`/`#ff6b6b`,
  text `#d8d8de`, secondary `#8a8a96`, faint `#5b5b66`, card border `#3a3f4b`.
- Never rely on color alone: pair it with a glyph (`✓ ✗ ⚠ ● ○`), so it reads in mono and for color-blind
  people.
- Background color sparingly: one current line, one selected row, one active chip.

**Hierarchy with three weights**: `bold` + accent for the one thing, plain for content, `dimColor`/faint
for metadata (times, counts, hints). Metadata goes right-aligned (`justifyContent="space-between"`).

**Glyphs are the icon set.** A small, consistent vocabulary beats emoji (emoji are double width and
break alignment):
`◆ ◇ ● ○ ◉ ▸ ▾ › ✓ ✗ ⚠ ✎ ◷ ⟲ ⚡ ↻ → ⧉ ± ⎇ ⏱ ♥ ♡ ▤ ◧ ⠋…` (spinner `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`).
Bars and charts: `█ ▓ ▒ ░`, `▁▂▃▄▅▆▇█`, braille `⣀⣤⣶⣿` for area charts, `┊` for a marker line.

**Structure**
- Cards: `borderStyle="round"` + `borderColor` faint + `paddingX={1}` for a unit (a section, an answer).
  Don't nest cards; a card title is a bold line inside it with meta on the right.
- Air: `marginTop={1}` between units, never blank `Text` rows; `columnGap={1}`/`{2}` in rows.
- Truncate, don't wrap, anything in a fixed row (`wrap="truncate"`); wrap only prose.
- Align numbers right, labels left; pad with `padStart`/`padEnd` for columns.
- Width: draw to `e.props.bodyColumns`; test the mockup at 40 and 80 columns.

## States (design all of them)

| State | What it shows |
| --- | --- |
| Empty / first run | what the mod is for in one line + 2–3 clickable examples. Never a blank pane. |
| Busy | a spinner + what it is doing + elapsed seconds (`⠹ reading the session… 3s`). Dim the inputs. |
| Normal | the primary thing first; newest where the eye is (bottom near an input, top in a feed). |
| Error | red `✗` + the cause in plain words + what to do next. Show it in the UI: installed plugins' hook failures go only to the debug log. |
| Long content | fold it (`▾ 12 more`), scroll inside, or show the last N with a count. |

## Motion (sparingly, with purpose)

- Animate only what is alive: a spinner while waiting, a pet that reacts to events, a blink for an alarm.
- Redraw cadence: spinners ~8/s (`clock.every(120)` while busy, stop when idle); counters 1/s; nothing
  ticks when idle. `$.ui.blit` for pixel animation, not full redraws.
- Feedback within one frame of an action: a pressed button changes state (chip, ✓) immediately; the
  slow work shows a spinner.

## Interaction

- **Every action has a click and a key.** Buttons get `hotkey` digits/letters; list keys show in a faint
  footer hint line that changes with focus (`↑↓ move · enter open · tab editor · esc prompt`).
- **Toggle, don't stack**: the command that opens a pane closes it; a dock button lights while its pane is
  open.
- **Never lose the person's work**: unsaved edits survive outside changes; a destructive action needs a
  second press, with the reason shown.
- **Respect the conversation**: no unasked pane takeovers on narrow terminals, no toasts per event (one
  per meaningful change), nothing added to the transcript unless that is the point.
- **Bridge to the main flow**: an answer, a file, a link gets `→ prompt` (insert into the input) and
  `⧉ copy` where it helps.

## Delight (the "mega interesting" part)

Small, earned touches make a mod memorable:
- a character with moods (deck's Bolt dances on green tests, sleeps after 2 quiet minutes);
- live numbers that tell a story (context pulse per turn, "auto-compact in ~3 turns");
- color identity (dock's per-mod colors, chips for what is on);
- instant answers that feel like magic (aside reading the whole session from the cache in 2s).
One or two per mod; delight that slows the person down is noise.

## UI review checklist (run before handing over)

- [ ] The one question is answered by the first line the eye hits.
- [ ] At 40 columns nothing wraps where it shouldn't, nothing important is cut.
- [ ] Empty, busy, error states exist and are helpful.
- [ ] One accent, semantic colors, glyph + color for status.
- [ ] Metadata is faint and right-aligned; there are at most two bold things on screen.
- [ ] Every clickable thing also has a key; the footer hints match the focus.
- [ ] Nothing animates when nothing happens.
- [ ] Failures are visible in the UI.
- [ ] Ask the user for a screenshot and iterate on what they see — terminals differ (Terminal.app has no
      OSC 8 links and no kitty images; fonts change glyph widths).
