---
name: create-mod
description: Build a Claude Code mod (a plugin of function hooks) with a beautiful, clear, delightful terminal UI, end to end — a side pane, a row under or above the prompt, a reply renderer, a tool-call gate, a side chat, an editor — from idea to a published GitHub repo colleagues install in two commands. Use whenever the user wants a new mod, plugin, pane, panel, toolbar, button, status, overlay or "something inside Claude Code that shows/does X", wants to change how Claude Code looks or behaves, or says "сделай мод", "новый мод", "createmod", "/create-mod". Also use to fix, restyle or publish an existing mod.
---

# create-mod

Everything learned building [deck](https://github.com/manikosto/deck),
[glint](https://github.com/manikosto/glint), [files](https://github.com/manikosto/files),
[dock](https://github.com/manikosto/dock) and [aside](https://github.com/manikosto/aside), as one workflow.

**Paths.** `SKILL_DIR` below is the folder holding this file (usually `~/.claude/skills/create-mod`).
Mods live in `$CLAUDE_MODS_DIR` (default `~/claude-mods`), one folder each, installed from a local
marketplace the scripts create there on first use. Publishing goes to the GitHub account `gh` is logged
into.

**The bar is the interface.** A mod that works but looks like a log dump has failed. Every mod built with
this skill must be glanceable, calm, consistent with the other mods, and have one or two moments of
delight. `references/terminal-ux.md` is the design system; its design pass and review checklist are
mandatory steps below, not suggestions.
The engine's API is early access and moves between releases: its declaration file is the authority,
this skill is the map and the list of traps.

## 0. Load the engine's own guide first

Invoke the `plugin-authoring` skill before writing code. It prints where the API types are for this
build (`.../plugin-authoring/types/claude-code.d.ts`, ~20k lines) and the canonical examples. Grep that file
for what you need (`"export type PaneOpenArgs"`, `"'ui.message'"`, `"fork: ("`) and read the declaration;
never guess a prop or an event name.

Then read `references/terminal-ux.md` and `references/gotchas.md` (this folder). The first is how a mod
should look and feel; every item in the second cost a broken build or a round trip with the user.

## 1. Pin the shape before coding

Decide, in one or two sentences to the user, which of these the mod is. Each maps to one engine site:

| The user wants | Site | Pattern in `references/patterns.md` |
| --- | --- | --- |
| a panel beside the chat | `Pane` via `$.ui.open` + `ui.render {component:'Pane', requestId}` | Pane |
| buttons/row under the prompt | `PromptHint` (the dim line under the input) | Under-prompt row |
| a row above the prompt | `AbovePrompt` (glint already uses it: check before taking it) | Band |
| restyle replies | `AssistantMessage` / `CommandOutput` (glint owns these) | — extend glint instead |
| keyboard-driven UI (editor, list, game) | a `Client` surface module inside a Pane | Client module |
| react to / gate tool calls | `tool.call` hook (`{ deny }` to refuse) | Tool hook |
| ask the model about the session | `$.model.fork` (cached, adds nothing to the chat) | Side question |
| a slash command | `$.command.register` in `session.start` + `command.run` | everywhere |

Only one plugin can draw a given site instance: if two mods hook the same component, one wins. Check
`$CLAUDE_MODS_DIR/*/hooks/register.tsx` for `component: '<Site>'` before claiming a site.

## 2. Design pass — show it before you build it

Follow "The design pass" in `references/terminal-ux.md`:
1. the one question the mod answers at a glance;
2. an ASCII mockup at the real width (≈40–80 columns for a pane, one row under the prompt) with real
   content, in three states: empty, busy, full or error;
3. accent color, glyphs, what is bold / normal / faint, every action's click and key;
4. the one or two delight touches.

Show the mockup to the user in a fenced `text` block and get a yes (or changes) before writing code.
Changing a mockup costs seconds; changing a built UI costs a reload loop.

## 3. Scaffold

```sh
$SKILL_DIR/scripts/scaffold.sh <name> "<one-line description>"
```

It writes `$CLAUDE_MODS_DIR/<name>/` with `plugin.json`, `marketplace.json` (own repo),
`hooks/hooks.json`, a starter `hooks/register.tsx` (pane + command), `types/index.d.ts`, `tsconfig.json`,
`LICENSE` (MIT), `.gitignore`, `README.md`, and adds the mod to the local `claude-mods` marketplace.

Conventions every mod follows:
- folder and plugin name = the slash command = the pane id. dock lights a button up by pane id == command.
- a docked pane asks for a share of the terminal (`widthPercent` userConfig) and asks again when its tab
  comes to the front (the dock is shared by all panes).
- colors are hex strings; one accent per mod (deck orange `#e8875b`, aside teal `#4fd6be`, files blue).
- UI copy in English (mods are public); the conversation with the user in their language.

## 4. Write it

Start from the pattern, then grow. Build the UI to the agreed mockup exactly: same order, same glyphs,
same colors, all three states. Keep pure logic (parsing, layout math, formatting) in separate `.ts`
files with no engine calls, so Node can test them. Comment the why, not the what.

## 5. Check — all four, every time

```sh
$SKILL_DIR/scripts/check.sh <name>
```

1. `claude plugin validate` — the engine's own reading of the module (calls, state keys, refusals).
2. `tsc` against this build's types (the script builds a temp tsconfig; the mod's own extends a folder the
   engine writes only after a load).
3. Pure logic in Node: `node --experimental-strip-types --no-warnings test.mts` importing the `.ts` files.
4. A `Client` module: bundle with esbuild and drive it with a fake surface (see patterns: "Testing a
   Client"). `claude plugin test` needs the hooks rollout switch on; when it says "turned off in this
   process", say so and rely on 1–4.

Then run the **UI review checklist** in `references/terminal-ux.md` against your own render code and
fix what fails.

Never report "works" from these alone: they prove it loads and the logic is right, not how it looks.
Say what was checked, show the mockup of what they should see, and ask for a screenshot after
`/reload-plugins`. Iterate on the screenshot: that is where the real polish happens.

## 6. Install and iterate

```sh
claude plugin marketplace update claude-mods && claude plugin install <name>@claude-mods
```

In the terminal the plugin is read from its folder, so after each edit the user runs `/reload-plugins`.
The desktop app runs a snapshot copied into the plugin cache: bump `version` in `plugin.json`, run
`claude plugin marketplace update claude-mods && claude plugin update <name>@claude-mods`, and restart it (installed
plugins log hook failures to the debug log only — no transcript line — so make failures visible in the
UI: a red status line or a toast).

## 7. Publish (when the user asks)

```sh
$SKILL_DIR/scripts/publish.sh <name>   # git init, commit, public repo, push
```

Then colleagues run:

```sh
claude plugin marketplace add <you>/<name> && claude plugin install <name>@<name>
```

For an update: bump `version` in `.claude-plugin/plugin.json`, add a CHANGELOG line if the repo has one,
commit, push. Confirm visibility with the user before the first push (default: public, as they chose).

## Reference files

- `references/terminal-ux.md` — the design system: design pass, colors, glyphs, states, motion,
  interaction, delight, and the UI review checklist.
- `references/gotchas.md` — the traps, each with its fix. Read before writing.
- `references/patterns.md` — copy-ready code for each site and for testing.
