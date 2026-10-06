# Patterns

Copy-ready pieces from working mods. Imports for all of them:

```tsx
import { atom, memberOf, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'
type Engine = EngineInterface
```

Palette used across mods (see terminal-ux.md):

```ts
const C = { accent: '#4fd6be', text: '#d8d8de', dim: '#8a8a96', faint: '#5b5b66', card: '#3a3f4b',
  ok: '#7fc77a', warn: '#e8c15b', err: '#ff6b6b' }
const SPIN = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
```

## Pane: open, toggle, width share, re-ask on tab front

```tsx
const PANE = 'mymod'            // = command name = folder name
const MIN_COLS = 40
let share = 0.4, termCols = 0, wasShown = false

const openArgs = (term?: number) =>
  term && term > 0 ? { id: PANE, title: PANE, columns: Math.max(MIN_COLS, Math.round(term * share)) } : { id: PANE, title: PANE }

// the dock is shared: ask for our width again whenever our tab comes to the front
async function watchTab($: Engine) {
  const me = (await $.ui.panes().catch(() => [])).find(p => p.id === PANE)
  const shownNow = !!me?.isShown
  if (shownNow && !wasShown && termCols > 0) void $.ui.open(openArgs(termCols))
  wasShown = shownNow
}

export const register: Register = (on, options) => {
  const pct = Number(options.widthPercent)
  share = Number.isFinite(pct) && pct >= 20 && pct <= 90 ? pct / 100 : 0.4

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: PANE, description: 'What it does, in one line', argumentHint: '[arg]' })
    $.clock.every(800, () => { void watchTab($) })
    return next(e)
  })

  on('command.run', { command: PANE }, async ($, e) => {
    termCols = e.presentation.columns
    // open (or close) FIRST, straight from the person's command, without `focus`: that is what makes
    // the open count as asked, which places it below 144 columns
    if (wasShown && !e.args.trim()) { await $.ui.close({ id: PANE }); wasShown = false; return { text: 'Closed.' } }
    const r = await $.ui.open(openArgs(termCols))
    return { text: r.isPlaced ? 'Open.' : `Waits: ${r.reason ?? 'no room'}` }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e) as any
    const props = e.props as { bodyColumns?: number; scroll?: { bodyRows?: number } }
    const cols = Math.max(30, props.bodyColumns ?? 60)
    const rows = props.scroll?.bodyRows ?? 30
    const term = e.viewport?.columns
    if (term && props.bodyColumns && term > props.bodyColumns + 4) termCols = term
    return (
      <Box flexDirection="column" width={cols}>
        <Box flexDirection="row" justifyContent="space-between" width={cols}>
          <Text wrap="truncate"><Text color={C.accent} bold>◇ My mod</Text><Text color={C.faint}>  what it is</Text></Text>
          <Text color={C.faint}>meta</Text>
        </Box>
        {/* content cards */}
      </Box>
    )
  })
}
```

## Card, row with right-aligned meta, footer hint

```tsx
<Box borderStyle="round" borderColor={C.card} paddingX={1} marginTop={1} width={cols}>
  <Box flexDirection="row" justifyContent="space-between">
    <Text bold color={C.text}>TITLE</Text>
    <Text color={C.dim}>2/4</Text>
  </Box>
  <Text wrap="truncate"><Text color={C.ok}>✓ </Text><Text color={C.dim}>done thing</Text></Text>
</Box>
<Text color={C.faint} wrap="truncate">↑↓ move · enter open · esc prompt</Text>
```

## State that redraws its readers

```ts
// types/index.d.ts — self-contained, no imports
export type Item = { id: number; text: string }
declare module 'claude-code' {
  interface PluginState {
    mymod: { items: Item[]; busy: boolean; open: StateFamily<number[]> }
  }
}
```

```tsx
const items = atom({ plugin: 'mymod', key: 'items' } as const, [] as Item[])
const busy = atom({ plugin: 'mymod', key: 'busy' } as const, false)
// per drawn instance (per message, per row): memberOf(family, e) inside a render hook
const open = atom({ plugin: 'mymod', key: 'open' } as const, [] as number[])

// in a render hook:  const list = await read($, items)            (subscribes)
// in a handler:      onPress={() => { void update($, items, l => [...l, x]) }}
// per instance:      const mine = memberOf(open, e); await read($, mine)
```

## Busy state with a spinner (animates only while busy)

```tsx
let spin = 0
// session.start:
$.clock.every(120, () => { void read($, busy).then(b => { if (b) { spin++; $.ui.invalidate('ui.render') } }) })
// render:
<Text><Text color={C.accent}>{SPIN[spin % SPIN.length]}</Text><Text color={C.dim}>{` working… ${secs}s`}</Text></Text>
```

## Empty state with clickable examples

```tsx
<Box borderStyle="round" borderColor={C.card} paddingX={1} marginTop={1} width={cols}>
  <Text color={C.accent} bold>What this is for</Text>
  <Text color={C.dim} wrap="wrap">One sentence on why it helps.</Text>
  {EXAMPLES.map((q, i) => <Button key={`ex${i}`} plain dimColor label={`› ${q}`} onPress={() => { void run($, q) }} />)}
</Box>
```

## Under-prompt row (PromptHint) with colored icons

```tsx
on('ui.render', { component: 'PromptHint' }, async ($, e) => {
  const { Box, Text, Button } = $.ui.resolve(e)
  return (
    <Box flexDirection="row" columnGap={1}>
      {list.map((it, i) => (
        <Box key={`it-${it.id}`} flexDirection="row">
          {/* Buttons have no color: the colored glyph sits beside a plain Button; an active item is a chip */}
          <Text color={it.on ? '#1e1e24' : it.color} backgroundColor={it.on ? it.color : undefined} bold>{` ${it.icon} `}</Text>
          <Button key={`b-${it.id}`} plain label={it.label} hotkey={String(i + 1)} dimColor={!it.on} onPress={() => { void act($, it) }} />
        </Box>
      ))}
      {e.props.hint ? <Text dimColor wrap="truncate">{`  ${e.props.hint}`}</Text> : null}
    </Box>
  )
})
```

Only one plugin can own PromptHint (dock does). Prefer adding a button to dock (`/dock add <cmd>`).

## Client module (keyboard UI) + ui.message bridge

```tsx
// register.tsx
const model: Model = { /* plain data the Client draws */ }
on('ui.message', async ($, e, next) => {
  if (e.element !== 'main') return next(e)          // match by key, not by a matcher
  try { await handle($, e.data as Request) } catch (err) { /* put the error into model.status */ }
  $.ui.invalidate('ui.render')                       // the redraw path always lands
  return { props: { ...model } }
})
on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
  const { Client } = $.ui.resolve(e) as any
  return <Client key="main" module="./view.tsx" props={{ ...model }} width={cols} height={rows} />
})
```

```tsx
// view.tsx — runs on the drawing thread, no $
import type { ClientModule, ClientSurface } from 'claude-code'
type State = { ref: { props: Model }; sel: number }
const View: ClientModule<Model, State> = (props, surface) => {
  const { Box, Text } = surface.elements as any
  let s = surface.state
  if (!s) {                                          // first call: listeners once, state once
    s = { ref: { props }, sel: 0 }
    surface.onKey(ev => onKey(surface, ev))
    surface.onPointer(ev => onPointer(surface, ev))
    surface.setState(s)
  }
  s.ref.props = props                                // listeners read the latest props through the ref
  return <Box flexDirection="column">{/* draw from s and props */}</Box>
}
export default View
function onKey(surface: ClientSurface<State>, ev: { key: string; ctrl?: true }) {
  const s = surface.state!; const next = { ...s }
  if (ev.key === 'down') next.sel++
  else if (ev.key === 'return') surface.post({ type: 'open', index: s.sel })
  else return
  surface.setState(next)
}
```

## Tool hook (react to or gate a tool call)

```ts
on('tool.call', async ($, e, next) => {
  const tool = String(e.tool)                         // names outside the build's union compare as strings
  const input = e as unknown as Record<string, unknown>
  // before: return { deny: 'why' } to refuse; next({ ...e, ... }) to rewrite
  const ran = await next(e)
  try {
    if (!ran.isError && ran.deny === undefined && tool === 'Edit') { /* react */ }
  } catch {}                                         // never let work after next() throw
  return ran
})
```

## Ask the model about the session (cached, invisible to the chat)

```ts
const r = await $.model.fork({ prompt: `[A side question… do not continue the task, no tools]\n\nQuestion: ${q}` })
if (r.isAnswered) show(r.text, r.usage.cache_read_input_tokens)
else if (r.reason === 'nothing-to-fork') show('Nothing to ask about yet.')
```

## Pixel art / animation (Raster + blit)

Pack `[codePoint, fg, bg]` u32 triplets, base64. Two pixels per cell with `▀` (top = fg, bottom = bg);
when the top pixel is empty use `▄` with the bottom pixel as fg and `0x01000000` (terminal default) as bg.
Draw once in the render (`<Raster key="pet" columns rows cells />`), then animate with
`$.ui.blit({ requestId: PANE, key: 'pet', cells, columns, rows })` from a `$.clock.every`.

## Testing pure logic in Node

```sh
node --experimental-strip-types --no-warnings test.mts   # test.mts imports ./hooks/*.ts (no JSX, no engine)
```

## Testing a Client module without the engine

```sh
W=$(mktemp -d) && cd $W && npm init -y >/dev/null && npm i -s esbuild >/dev/null 2>&1
npx esbuild <mod>/hooks/view.tsx --bundle --format=esm --jsx-factory=h --jsx-fragment=Fragment --outfile=view.mjs
```

```js
// harness.mjs
globalThis.h = (type, props, ...children) => ({ type, props: props ?? {}, children: children.flat(Infinity) })
globalThis.Fragment = 'Fragment'
const { default: View } = await import('./view.mjs')
let keyFn, ptrFn; const posts = []
const surface = { elements: { Box: 'Box', Text: 'Text', Code: 'Code' }, state: undefined, columns: 100, rows: 20,
  setState(s) { this.state = s }, every: () => () => {}, onKey: f => (keyFn = f, () => {}),
  onPointer: f => (ptrFn = f, () => {}), post: d => posts.push(d) }
let props = { /* model */ }
const render = () => View(props, surface)
render(); keyFn({ key: 'down' }); render()
console.log(surface.state, posts)
```
