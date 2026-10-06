import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'
import type { __TITLE__Item } from '../types'

type Engine = EngineInterface

// __DESC__
const PANE = '__NAME__'
const MIN_COLS = 40

const C = { accent: '__ACCENT__', text: '#d8d8de', dim: '#8a8a96', faint: '#5b5b66', card: '#3a3f4b', ok: '#7fc77a', warn: '#e8c15b', err: '#ff6b6b' }

const items = atom({ plugin: '__NAME__', key: 'items' } as const, [] as __TITLE__Item[])
const busy = atom({ plugin: '__NAME__', key: 'busy' } as const, false)

let share = 0.4
let termCols = 0
let wasShown = false

const openArgs = (term?: number) =>
  term && term > 0 ? { id: PANE, title: PANE, columns: Math.max(MIN_COLS, Math.round(term * share)) } : { id: PANE, title: PANE }

// The dock is shared by every pane: ask for our width again whenever our tab comes to the front.
async function watchTab($: Engine) {
  const me = (await $.ui.panes().catch(() => [])).find(p => p.id === PANE)
  const shownNow = !!me?.isShown
  if (shownNow && !wasShown && termCols > 0) void $.ui.open(openArgs(termCols))
  wasShown = shownNow
}

async function add($: Engine, text: string) {
  await update($, items, list => [...list, { id: Date.now(), text, at: Date.now() }].slice(-50))
}

export const register: Register = (on, options) => {
  const pct = Number(options.widthPercent)
  share = Number.isFinite(pct) && pct >= 20 && pct <= 90 ? pct / 100 : 0.4

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: PANE, description: '__DESC__' })
    $.clock.every(800, () => { void watchTab($) })
    return next(e)
  })

  on('command.run', { command: PANE }, async ($, e) => {
    termCols = e.presentation.columns
    // open or close first, straight from the person's command, without focus: it then counts as asked
    if (wasShown) {
      await $.ui.close({ id: PANE })
      wasShown = false
      return { text: '__TITLE__ closed.' }
    }
    const r = await $.ui.open(openArgs(termCols))
    return { text: r.isPlaced ? '__TITLE__ open.' : `__TITLE__ waits: ${r.reason ?? 'no room'}` }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e) as any
    const props = e.props as { bodyColumns?: number }
    const cols = Math.max(30, props.bodyColumns ?? 60)
    const term = e.viewport?.columns
    if (term && props.bodyColumns && term > props.bodyColumns + 4) termCols = term
    const list = await read($, items)
    const isBusy = await read($, busy)

    const empty = (
      <Box key="empty" borderStyle="round" borderColor={C.card} paddingX={1} marginTop={1} width={cols}>
        <Text color={C.accent} bold>What __TITLE__ is for</Text>
        <Text color={C.dim} wrap="wrap">One sentence on why it helps. Try:</Text>
        <Button key="try" plain dimColor label="› an example action" onPress={() => { void add($, 'example') }} />
      </Box>
    )

    return (
      <Box flexDirection="column" width={cols}>
        <Box key="head" flexDirection="row" justifyContent="space-between" width={cols}>
          <Text wrap="truncate"><Text color={C.accent} bold>◇ __TITLE__</Text><Text color={C.faint}>  one-line subtitle</Text></Text>
          <Text color={C.faint}>{isBusy ? 'working…' : `${list.length} items`}</Text>
        </Box>
        {list.length === 0 ? empty : (
          <Box key="list" flexDirection="column" borderStyle="round" borderColor={C.card} paddingX={1} marginTop={1} width={cols}>
            {list.slice(-12).map(it => (
              <Box key={`it${it.id}`} flexDirection="row" justifyContent="space-between">
                <Text color={C.text} wrap="truncate">{`● ${it.text}`}</Text>
                <Text color={C.faint}>{new Date(it.at).toLocaleTimeString()}</Text>
              </Box>
            ))}
          </Box>
        )}
        <Text key="hint" color={C.faint} wrap="truncate">{`/${PANE} closes · esc returns to the prompt`}</Text>
      </Box>
    )
  })
}
