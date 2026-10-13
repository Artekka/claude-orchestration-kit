// The setup guide's data: the band drawn for a sample in which every item shows, and where each item sits.
// Each item is found by drawing the band again with only that item hidden: the first cell that changes is
// where its number goes, so the guide follows the real layout code and never a hand-drawn picture.
// Usage (from the kit): bash scripts/hud-guide.sh build   — writes docs/status-hud-guide.html
import { parseConfig } from '../lib/config'
import { drawBand, type Line } from '../lib/layout'
import type { Heartbeat, Snapshot } from '../types'

export const COLS = 180

/** Every item, in the README's order, with a plain name and what it shows. `when` = only drawn sometimes. */
export const ITEMS: { id: string; area: string; name: string; what: string; when?: string; faces?: true }[] = [
  { id: 'host-title', area: 'Machine', name: 'Machine title', what: 'The heading of the machine box: how many processor threads this computer has (and WSL2 when Linux runs inside Windows).' },
  { id: 'cpu', area: 'Machine', name: 'CPU meter', what: 'How busy the processor is: the 1-minute load against the number of threads. Turns red near full.' },
  { id: 'cpu-mark', area: 'Machine', name: 'CPU red mark', what: 'The small tick on the CPU bar at 90%, where the bar turns red.' },
  { id: 'history', area: 'Machine', name: 'History graphs', what: 'The small graphs to the right of the meters: the last few minutes of each reading.' },
  { id: 'ram', area: 'Machine', name: 'Memory (RAM)', what: 'Memory in use out of the total.' },
  { id: 'win', area: 'Machine', name: 'Windows memory limit', what: 'On WSL only: how much of the memory Windows can promise is promised. At 100% Windows stops WSL, and every session with it.', when: 'WSL only' },
  { id: 'gpu', area: 'Machine', name: 'Graphics card', what: 'How busy the graphics card is, and its temperature.', when: 'with an NVIDIA card' },
  { id: 'vram', area: 'Machine', name: 'Graphics memory', what: 'Memory on the graphics card in use out of the total.', when: 'with an NVIDIA card' },
  { id: 'disk', area: 'Machine', name: 'Main disk', what: 'Space used on the main drive.' },
  { id: 'disk2', area: 'Machine', name: 'Second disk', what: 'Space used on a second drive, when one is in use.', when: 'with a second drive' },
  { id: 'sessions-title', area: 'Sessions', name: 'Sessions title', what: 'The heading of the sessions box: how many Claude sessions are running, and across how many accounts or projects.' },
  { id: 'context-key', area: 'Sessions', name: 'Context colour key', what: 'Explains the bar colours: green is fine, amber is filling up, red is past the point where a session should hand over.' },
  { id: 'dot-key', area: 'Sessions', name: 'Dot key', what: 'Explains the dot colours: which account, or which project, each colour means.' },
  { id: 'state-key', area: 'Sessions', name: 'Busy/idle key', what: 'Explains the marks: a turning mark is busy, $ is running a command, ○ is idle.' },
  { id: 'dot', area: 'Sessions', name: 'Session dot', what: 'A coloured dot per session: its Claude account, or its project (the same colour as its terminal tab).' },
  { id: 'face', area: 'Sessions', name: 'Session face', what: 'A face per session that tires as its context fills: 😀 when fresh, 💀 when it should hand over.', faces: true },
  { id: 'model', area: 'Sessions', name: 'Model badge', what: 'Which model the session runs: OPS (Opus), SNT (Sonnet), HKU (Haiku).' },
  { id: 'bar', area: 'Sessions', name: 'Context bar', what: 'How full the session\'s context (its working memory) is, coloured by the key.' },
  { id: 'tokens', area: 'Sessions', name: 'Context number', what: 'The same fill as a number of tokens, e.g. 230K.' },
  { id: 'state', area: 'Sessions', name: 'Busy/idle mark', what: 'Whether the session is working, running a command, or waiting.' },
  { id: 'activity', area: 'Sessions', name: 'Last action', what: 'What the session did last, or STUCK and why when it needs you.' },
  { id: 'column2', area: 'Sessions', name: 'Second column', what: 'With more than five sessions, a second column of rows (otherwise "+N more").', when: 'more than five sessions' },
  { id: 'frame-title', area: 'Sessions', name: 'STATUS HUD label', what: 'The name on the top-right corner of the frame.' },
  { id: 'work-mode', area: 'Bottom chips', name: 'Work/Quiet mode', what: 'A button: Quiet mode pauses heavy work (test runs) so the machine stays responsive; Work mode is normal.' },
  { id: 'perm-mode', area: 'Bottom chips', name: 'Permission mode', what: 'How this session asks before acting: normal, accept-edits, auto or bypass.' },
  { id: 'gates', area: 'Bottom chips', name: 'Test slots', what: 'How many test runs may go at once in this project.' },
  { id: 'queue', area: 'Bottom chips', name: 'Test queue', what: 'Test runs waiting for a free slot.', when: 'when tests wait' },
  { id: 'holding', area: 'Bottom chips', name: 'Holding', what: 'The queue is held back because the machine is too busy; it moves again when the load drops.', when: 'when the machine is too busy' },
  { id: 'extra', area: 'Bottom chips', name: 'Your own chips', what: 'Lines from a command you choose (extraChipsCmd), one chip each.', when: 'with extraChipsCmd set' },
  { id: 'live', area: 'Bottom chips', name: 'Live version', what: 'The version your users have now (live_version in the project).' },
  { id: 'next', area: 'Bottom chips', name: 'Next version', what: 'The version being built (next_version in the project).' },
  { id: 'count', area: 'Bottom chips', name: 'Session count', what: 'How many sessions are reporting.' },
  { id: 'warnings', area: 'Bottom chips', name: 'Alerts', what: 'Red chips at the right, most urgent first: Windows memory, a STUCK session, a session past the report mark, a high load.', when: 'when something needs you' },
]

const S = (name: string, k: number, state: Heartbeat['state'], project: string, color: string, account: number, activity: string, model = 'opus', stuck = ''): Heartbeat =>
  ({ id: name, name, model, account, tokens: k * 1000, window: 1_000_000, state, activity, at: 0, project, color, mode: 'auto', stuck })
const sessions = [
  S('Orca', 170, 'busy', 'my-app', '#16a085', 1, 'orchestrating · row 7 gate queued'),
  S('Mars', 64, 'busy', 'my-app', '#16a085', 1, 'row 6-3 settings page'),
  S('Venus', 322, 'busy', 'my-app', '#16a085', 2, 'row 7-7 final gate', 'sonnet'),
  S('Vulcan', 231, 'shell', 'my-app', '#16a085', 2, 'npm test'),
  S('Apollo', 120, 'idle', 'my-app', '#16a085', 1, 'READ row 6-4', 'haiku', 'waiting on you'),
  S('Lotus', 95, 'busy', 'website', '#8e44ad', 1, 'editing index.html'),
  S('Finch', 40, 'idle', 'website', '#8e44ad', 2, 'Bash'),
]
const wave = (n: number, a: number, b: number, p: number): number[] => Array.from({ length: n }, (_, i) => a + b * Math.sin(i / p))
export const SNAP: Snapshot = {
  now: 0, selfId: 'Orca', sessions, quietMode: false,
  local: { mode: 'auto', live: 'v1.4', next: 'v1.5', slots: 1, kit: true },
  host: {
    at: 0, threads: 20, load: [18.6, 17.9, 16.2], ramUsedGb: 9.8, ramTotalGb: 16, wsl: true,
    gpu: { util: 31, vramUsedGb: 3.1, vramTotalGb: 8, tempC: 52 },
    disks: [{ mount: '/', usedGb: 410, totalGb: 1007 }, { mount: '/mnt/d', usedGb: 1200, totalGb: 2000 }],
    commit: { usedPct: 71, limitGb: 40, usedGb: 28, at: 0 },
    hist: { load: wave(60, 15, 4, 5), ram: wave(60, 9, 1, 7), gpu: wave(60, 30, 15, 3) },
    gates: { running: 2, waiting: 1 }, extra: ['render 0/2'],
  },
}

type Cell = [string, string, string, number] // char, fg, bg ('' = none), bold
const grid = (lines: Line[]): Cell[][] =>
  lines.map(l => l.flatMap(sg => sg.runs.flatMap(r => Array.from(r.text).map((ch): Cell => [ch, r.fg, r.bg ?? '', r.bold ? 1 : 0]))))
const draw = (opts: Record<string, string>): Cell[][] =>
  grid(drawBand({ snap: SNAP, cfg: parseConfig({ quietModeOnCmd: 'a', quietModeOffCmd: 'b', sessionFaces: 'on', ...opts }, '/h'), flash: {}, sel: -1, now: 0 }, COLS, 10))
const same = (a: Cell | undefined, b: Cell | undefined): boolean => !!a && !!b && a.join('\u0000') === b.join('\u0000')

/** Where an item sits: per row it touches, the columns that are its own (the rest of the row only shifted). */
function locate(full: Cell[][], hidden: Cell[][]): { row: number; from: number; to: number }[] {
  const out: { row: number; from: number; to: number }[] = []
  for (let y = 0; y < full.length; y++) {
    const a = full[y] ?? [], b = hidden[y] ?? []
    let x = 0
    while (x < a.length && same(a[x], b[x])) x++
    if (x >= a.length) continue
    // The item's cells: the shortest span after which this row and the hidden row line up again.
    let to = a.length
    for (let k = 1; k <= 60 && x + k < a.length; k++) {
      let ok = true
      for (let j = 0; j < 8 && x + k + j < a.length; j++) if (!same(a[x + k + j], b[x + j])) { ok = false; break }
      if (ok) { to = x + k; break }
    }
    if (to === a.length) { to = x; while (to < a.length && !same(a[to], b[to])) to++ }
    out.push({ row: y, from: x, to })
  }
  return out
}

export function guideData(): { cols: number; account: Cell[][]; project: Cell[][]; items: (typeof ITEMS[number] & { at: { row: number; from: number; to: number }[] })[] } {
  const project = draw({ dotMode: 'project' })
  return {
    cols: COLS,
    account: draw({ dotMode: 'account' }),
    project,
    items: ITEMS.map(it => {
      // The dot key goes with the dots, so the dots are found with the key already off; the second column
      // also changes the title's count, so its place is below the title.
      const base = it.id === 'dot' ? draw({ dotMode: 'project', hideItems: 'dot-key' }) : project
      let at = locate(base, draw({ dotMode: 'project', hideItems: it.id }))
      if (it.id === 'column2') at = at.filter(a => a.row > 0)
      // Rows below a removed meter move up, and a removed chip moves the rest: keep the rows that are the
      // item's own. Per-session items touch every session row; anything else is one row.
      const perRow = ['dot', 'face', 'model', 'bar', 'tokens', 'state', 'activity'].includes(it.id)
      if (!perRow) at = at.slice(0, 1)
      else at = at.filter(a => a.row >= 2 && a.row <= 6)
      return { ...it, at }
    }),
  }
}

if (process.argv[1]?.endsWith('guide.ts')) process.stdout.write(JSON.stringify(guideData()))
