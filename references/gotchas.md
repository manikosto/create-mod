# Gotchas

Each one broke a real mod. Symptom → cause → fix.

## Loading and validation

- **`h is not a function` when drawing.** JSX compiles to calls of the global `h`; a local variable named
  `h` (`const h = hearts(...)`, `for (const h of list)`) shadows it. Never name anything `h` or `Fragment`
  in a `.tsx` file. Same for `on` and `$`: the validator refuses them shadowed ("`on` is declared again").
- **"$ is passed to X, which is not a function declared at the top of this file".** Any function that
  takes `$` must be a top-level `function` or `const` arrow, not a closure inside `register`.
- **"glint.recent is not declared"** — the state contract (`types/index.d.ts`, named in `plugin.json`
  `"types"`) must be self-contained: no `import` lines. `StateFamily<T>` is usable inside
  `declare module 'claude-code' { ... }` without importing it.
- **Comparing tool names fails to type-check** (`'Task'`, `'MultiEdit'` not in the union): compare
  `String(e.tool)`.
- **`tsc` "import path can only end with .ts"**: the mod's tsconfig extends a file the engine writes
  after a load. Check with a temp tsconfig that sets `allowImportingTsExtensions` (check.sh does).
- **"gating hook without .catch: tool.call"**: work after `await next(e)` must never throw (wrap it in
  `try {}`), or the tool call it wraps can be lost. Don't add a `.catch` that calls `next` again.

## Drawing

- **Render hooks cannot write state.** `$.state.set`/`update` while drawing is denied. Write from a press
  handler, another event, or `$.clock.after(0, ...)`.
- **State that drives drawing goes in `$.state` atoms** (`atom`, `read`, `update` from `'claude-code'`);
  module variables reset on every reload. A `read` while drawing subscribes the instance: an `update`
  redraws exactly the readers. `$.ui.invalidate('ui.render')` for module-held data (≤10/s, 30/s for a
  shown pane).
- **Button has no color prop.** Put a colored `Text` beside a `plain` Button (dock's icons). `plain` beats
  `variant="primary"`.
- **`Link` clicks go to the terminal, not the plugin.** Terminal.app has no OSC 8, so a Link there draws
  its text and then the URL again in dim, and does nothing on click. For a click the plugin handles, use
  a `Button`, or a `Markdown` element with `onLinkPress` (fullscreen only).
- **Mouse clicks reach Buttons only in fullscreen mode.** Elsewhere: ctrl+x Tab, then `hotkey` digits.
- **Code element**: max 10k chars, engine colors only; drawn per line (`wrap="truncate-end"`) to keep one
  row per line in an editor.
- **Raster** = one grid of colored cells (pixel art, charts); `$.ui.blit` repaints it without a redraw.
  Half blocks `▀/▄` give two pixels per cell; the empty half must be the terminal's default
  (`0x01000000`), so draw `▄` with the bottom pixel as foreground when the top is empty.
- **Image** draws real pixels only on kitty-protocol terminals (Ghostty, kitty, WezTerm); elsewhere its
  `alt`. Detect with `TERM_PROGRAM` / `KITTY_WINDOW_ID` and fall back to a Raster.

## Panes

- **Unasked panes wait below 144 columns** ("waits: unasked below 144 columns"). A pane counts as asked
  only when opened from the hook of a command the person typed, or a Button/Input/Select they worked —
  never a timer, `session.start`, `focus`, or a plugin's `$.command.run`. Once the person has opened an id,
  its floor drops to 110. So: call `$.ui.open` first in the command handler, don't pass `focus`, and
  don't re-open from timers unless the pane is already shown.
- **The dock is shared.** All panes sit in one dock as tabs; its width is whichever pane asked last. Ask
  for your width again when your tab comes to the front (poll `$.ui.panes()` and re-open on the
  hidden→shown edge). A width the person dragged wins until then.
- **A kept dock width beats every request.** Once the person drags or keys the dock, Claude Code stores
  `pluginPanes.dockColumns` in `~/.claude.json` and every pane opens at that width, whatever `columns` a mod
  asks for. Symptom: all panes open at the same width across reloads. Fix: delete that key (with Claude Code
  closed, or restart after) — then each mod's `columns` applies again.
- **`e.viewport.columns` in a docked Pane is the transcript beside it, not the terminal.** Take the
  terminal's width from `command.run`'s `e.presentation.columns`.
- **Size the tree to `e.props.bodyColumns`** (the pane body), not `e.viewport.columns` (the terminal).
  `e.props.scroll.bodyRows` is the height. The viewport is the terminal only when wider than the body.
- **Pane ids = command names** so dock can light the button of an open pane.

## Client modules (keyboard UIs)

- A `Client` runs a surface module on the drawing thread with local state, `onKey`, `onPointer`, `every`.
  It cannot touch disk: `surface.post(data)` → the plugin's `ui.message` hook → answer `{ props }`.
- **Don't over-filter `ui.message`.** A matcher of `{ component, requestId }` silently never matched in
  files; match by `e.element` (the Client's key) inside the hook. Answer `{ props: {...model} }` AND
  `$.ui.invalidate('ui.render')` — the redraw path is the one that always lands.
- Register `onKey`/`onPointer` once, on the first call (state undefined); keep the latest props in a ref
  inside state (`s.ref.props = props` each call) since listeners close over the first call.
- `setState` on three renders in a row with no input between unmounts the instance (render loop).
- Keys arrive only after a click into the region; Escape always returns focus to the prompt.
- A paste arrives as one key event whose `key` is the whole pasted string.

## Data from the engine

- `$.session.usage({ breakdown: 'summary' })` → context window, categories, MCP tools by server, memory
  files, skills, rate limits (`five_hour`, `seven_day` with `resetsAt`), cost. Cheap; `full` is not.
- `$.session.model()` returns an id like `claude-opus-5-5[1m]` — prettify it yourself.
- `$.model.fork({ prompt })` answers over the main thread's last request from the prompt cache; tools
  are denied; `nothing-to-fork` before the first response. One prompt per call: send recent side Q&A
  along for follow-ups.
- `$.command.list()` lists every slash command (builtin, plugin, user, mcp); `$.command.run` runs any,
  builtins included.
- `turn.complete` carries `answer` (the final text) and `usage`; `e.agentId` set = a subagent's turn.
- Test outcome detection: match a count before "failed" and a capital `FAIL`; "0 failed" is a pass.

## Security (mods run with the user's rights)

- Confine file access to a root: reject `..` and absolute paths, compare `$.fs.stat(p, { resolve: true })
  .realPath` against the root's real path.
- Anything a reply or the model produced is untrusted: never hand it to `open` (a `.command` or `.app`
  would run, any URL scheme launches an app). Only `https?://` to `open`; files with `open -R` (reveal).
- Vendored third-party code: rebuild it from pinned npm packages and compare hashes (glint's
  `scripts/verify.sh`); keep an allow-list of engine calls and check it.

## Shipping

- Installed-from-folder plugins: in the terminal edits apply on `/reload-plugins`. The desktop app runs a
  snapshot in the plugin cache: bump the version, `claude plugin update <name>@<marketplace>`, restart.
- The desktop draws Buttons in its own style (white chips, even `plain`): keep them few and secondary there.
- Two mods drawing the same site fight; when forking a renderer (glint from prismantis) disable the
  original.
- In zsh, `git $VAR commit` does not split `$VAR`; set author via `GIT_AUTHOR_*`/`GIT_COMMITTER_*`
  env vars.
- Upstream CI files from a fork may enforce rules your code breaks (prismantis forbids comments): replace
  them with your own minimal CI.
