# create-mod

A Claude Code skill for building your own **mods**: panels, toolbars, editors, side chats and anything
else that lives inside the Claude Code terminal, with a UI that is a pleasure to use.

Say *"make a mod that…"* and the skill walks Claude through it:

1. **Design first.** Claude draws an ASCII mockup of the interface at its real width, in its empty, busy and
   error states, and builds only after you say yes.
2. **Scaffold.** One script makes the mod in a shared house style (accent color, cards, empty state, width,
   toggle) and installs it locally.
3. **Build** from copy-ready patterns: side pane, row under the prompt, keyboard-driven `Client` UIs,
   tool-call hooks, questions about the session, pixel art.
4. **Check.** The engine's validator, TypeScript against your build's API, logic tests in Node, a harness
   for keyboard UIs, and a UI review checklist.
5. **Publish.** A public GitHub repo your colleagues install in two commands.

It carries a **design system for terminal UIs** (`references/terminal-ux.md`) and every trap hit while
building [deck](https://github.com/manikosto/deck), [files](https://github.com/manikosto/files),
[dock](https://github.com/manikosto/dock), [aside](https://github.com/manikosto/aside),
[glint](https://github.com/manikosto/glint)
(`references/gotchas.md`).

## Install

```sh
git clone https://github.com/manikosto/create-mod ~/.claude/skills/create-mod
```

Then, in Claude Code: *"make a mod that shows …"*, or `/create-mod`.

Needs Claude Code 2.1.289 or later, `jq`, and for publishing the GitHub CLI (`gh auth login`).

## Where things go

| | |
| --- | --- |
| Your mods | `$CLAUDE_MODS_DIR` (default `~/claude-mods`), one folder each |
| Local install | a `claude-mods` marketplace in that folder: edits apply on `/reload-plugins` |
| Publishing | the GitHub account `gh` is logged into (or `MODS_OWNER`) |

## What's inside

| File | |
| --- | --- |
| `SKILL.md` | the workflow from idea to a published repo |
| `references/terminal-ux.md` | the design system and the UI review checklist |
| `references/gotchas.md` | the traps, each with its fix |
| `references/patterns.md` | copy-ready code for each kind of mod, and how to test it |
| `scripts/scaffold.sh` · `check.sh` · `publish.sh` | new mod · checks · public repo and push |

## License

MIT
