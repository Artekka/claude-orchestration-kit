import { expect, test } from 'claude-code/testing'

import { parseConfig } from '../lib/config'
import { chips, drawBand, drawPane, lineText, nameWidth, sessionRow, spin, type Line, type View } from '../lib/layout'
import type { Heartbeat, Snapshot } from '../types'

const S = (name: string, k: number, state: Heartbeat['state'] = 'busy', account = 1): Heartbeat => ({ id: name, name, model: 'opus', account, tokens: k * 1000, window: 1_000_000, state, activity: 'doing a long thing that should truncate rather than wrap', at: 0 })
const sessions = ['Orca', 'Vali', 'Vali2', 'Vali4', 'Sib3', 'Sib5', 'Sib10', 'Sib11', 'Sib12', 'Sib13'].map((n, i) => S(n, 90 + i * 30, 'busy', i % 3 === 0 ? 2 : 1))
const snap: Snapshot = {
  now: 1_000, selfId: 'Orca', sessions, quietMode: false,
  host: {
    at: 0, threads: 28, load: [28.3, 28, 27], ramUsedGb: 15.6, ramTotalGb: 62, gpu: { util: 9, vramUsedGb: 11.8, vramTotalGb: 32.6, tempC: 44 },
    disks: [{ mount: '/', usedGb: 818, totalGb: 1007 }, { mount: '/data', usedGb: 900, totalGb: 2000 }],
    commit: { usedPct: 88, limitGb: 127, usedGb: 112, at: 0 },
    hist: { load: [20, 25, 30], ram: [10, 12], gpu: [1, 5] },
  },
}
const cfg = parseConfig({ quietModeOnCmd: 'a', quietModeOffCmd: 'b' }, '/h')
const view = (o: Partial<View> = {}): View => ({ snap, cfg, flash: {}, sel: 0, now: 1_000, ...o })
// Display width: an emoji (a session face) takes two terminal columns.
const widthOf = (l: Line): number => Array.from(lineText(l)).reduce((n, ch) => n + ((ch.codePointAt(0) ?? 0) >= 0x1f000 ? 2 : 1), 0)

test('variant A: 10 rows at 180 columns, every line exactly the width, never wider', async () => {
  const lines = drawBand(view(), 180, 10)
  expect(lines.length).toBe(10)
  for (const l of lines) expect(widthOf(l)).toBe(180)
})

test('variant A degrades: narrower terminals truncate, short ones fall back to 3 rows, nothing exceeds the width', async () => {
  for (const cols of [150, 120, 100, 89, 60, 30]) {
    const lines = drawBand(view(), cols, 10)
    for (const l of lines) expect(widthOf(l)).toBeLessThanOrEqual(cols)
  }
  expect(drawBand(view(), 100, 10).length).toBe(10)
  expect(drawBand(view(), 80, 10).length).toBe(3)
  expect(drawBand(view(), 180, 6).length).toBe(3)
  expect(lineText(drawBand(view(), 100, 10)[6] as Line)).toContain('more')
})

test('variant C: about 60 columns, lines fit, every session row is a press target', async () => {
  const lines = drawPane(view(), 60)
  for (const l of lines) expect(widthOf(l)).toBeLessThanOrEqual(60)
  const targets = lines.flatMap(l => l.map(s => s.press)).filter((p): p is string => p !== undefined && p.startsWith('sel:'))
  expect(targets.length).toBe(10)
  for (const w of [30, 44, 80]) for (const l of drawPane(view(), w)) expect(widthOf(l)).toBeLessThanOrEqual(w)
})

test('thresholds color the session row: green, amber, red', async () => {
  const col = (k: number): string => sessionRow(view(), S('X', k), 70).runs(0).find(r => r.text.includes('K'))?.fg ?? ''
  const [g, a, r] = [col(100), col(310), col(360)]
  expect(new Set([g, a, r]).size).toBe(3)
  expect(col(300)).toBe(a)
  expect(col(349)).toBe(a)
  expect(col(350)).toBe(r)
})

test('the flash paints the crossing session red on one blink phase and not the other', async () => {
  const bgs = (now: number): (string | null)[] => sessionRow(view({ now, flash: { X: 5_000 } }), S('X', 360), 70).runs(0).map(r => r.bg)
  expect(bgs(0).includes('#6a1c22')).toBe(true)
  expect(bgs(500).includes('#6a1c22')).toBe(false)
  expect(sessionRow(view({ now: 6_000, flash: { X: 5_000 } }), S('X', 360), 70).runs(0).some(r => r.bg === '#6a1c22')).toBe(false)
})

test('chips: quiet mode (clickable only when both commands are set), commit warning, over-mark sessions', async () => {
  const labels = (v: View) => chips(v).map(c => c.label.trim())
  const c = chips(view())
  expect(c[0]?.press).toBe('quiet')
  expect(labels(view()).some(l => l.includes('Windows commit 88%'))).toBe(true)
  expect(labels(view()).some(l => l.startsWith('≥350K'))).toBe(true)
  expect(chips(view({ cfg: parseConfig({}, '/h') }))[0]?.press).toBe(undefined)
  expect(chips(view({ snap: { ...snap, quietMode: null } })).some(x => x.label.includes('mode'))).toBe(false)
  const calm = { ...snap, host: { ...snap.host!, commit: { ...snap.host!.commit!, usedPct: 40 } } }
  expect(chips(view({ snap: calm })).some(x => x.label.includes('commit'))).toBe(false)
})

test('session rows: optional face, model badge, project-coloured dot, STUCK and quiet activity', async () => {
  const txt = (r: ReturnType<typeof sessionRow>): string => r.runs(0).map(x => x.text).join('')
  const faces = parseConfig({ sessionFaces: 'on' }, '/h')
  const row = (k: number, c = cfg, h: Partial<Heartbeat> = {}): string => txt(sessionRow(view({ cfg: c }), { ...S('Mars', k), model: 'claude-opus-5-5[1m]', ...h }, 70))
  // faces are off unless asked for
  expect(row(0).startsWith('● Mars    OPS')).toBe(true)
  expect(row(0, faces).slice(0, 10)).toBe('● 😀 Mars ')
  expect(row(180, faces).includes('😐')).toBe(true)
  expect(row(400, faces).includes('💀')).toBe(true)
  const r = sessionRow(view({ cfg: faces }), S('Mars', 100), 70)
  expect(r.cells[0]!.length).toBe(70)
  expect(r.cells[0]![3]!.ch).toBe('')
  // model badges
  expect(row(100, cfg, { model: 'claude-sonnet-5-5' }).includes(' SNT ')).toBe(true)
  expect(row(100, cfg, { model: 'gemini-2.5-pro' }).includes(' GEM ')).toBe(true)
  // dot: account by default, the project's tab color in project mode
  const proj = parseConfig({ dotMode: 'project' }, '/h')
  const dot = (c: typeof cfg, h: Partial<Heartbeat>): string => sessionRow(view({ cfg: c }), { ...S('Mars', 10), ...h }, 70).cells[0]![0]!.fg
  expect(dot(cfg, { account: 2 })).toBe('#b98cf0')
  expect(dot(proj, { color: '#16a085' })).toBe('#16a085')
  // STUCK in red with its reason; quiet for 25 minutes in amber
  const stuck = sessionRow(view(), { ...S('Mars', 10), stuck: 'waiting on you (permission)' }, 90).runs(0).find(x => x.text.includes('STUCK'))
  expect(stuck?.text.includes('STUCK · waiting on you (permission)')).toBe(true)
  expect(stuck?.fg).toBe('#f05050')
  const quiet = sessionRow(view(), { ...S('Mars', 10), quietMs: 25 * 60_000 }, 90).runs(0).find(x => x.text.includes('no progress'))
  expect(quiet?.text.startsWith('no progress 25 min')).toBe(true)
  expect(quiet?.fg).toBe('#e8b030')
  // hideItems switches parts off
  const bare = parseConfig({ hideItems: 'dot,model,activity' }, '/h')
  expect(row(100, bare).startsWith('Mars    ')).toBe(true)
  expect(row(100, bare).includes('OPS')).toBe(false)
})

test('chips: permission mode, test slots, queue, holding, extra, live and next versions; each can be hidden', async () => {
  const host = { ...snap.host!, gates: { running: 1, waiting: 3 }, extra: ['blender 0/2'], wsl: true }
  const s2 = { ...snap, host, local: { mode: 'auto', live: 'v0.06', next: 'v0.07', slots: 1, kit: true } }
  const labels = (o: Record<string, unknown> = {}): string[] => chips({ ...view(), snap: s2, cfg: parseConfig({ quietModeOnCmd: 'a', quietModeOffCmd: 'b', ...o }, '/h') }).map(c => c.label.trim())
  const all = labels()
  for (const want of ['auto mode on', 'gates 1+1 slots', 'queue 3 waiting', 'holding: load 28.3 ≥ 25.2', 'blender 0/2', 'live v0.06', 'next v0.07']) expect(all).toContain(want)
  const fewer = labels({ hideItems: 'perm-mode,gates,queue,holding,extra,live,next' })
  for (const gone of ['auto mode on', 'gates 1+1 slots', 'queue 3 waiting', 'blender 0/2', 'live v0.06', 'next v0.07']) expect(fewer).not.toContain(gone)
  // the slots chip shows before the limiter has ever run (no queue yet), from the project's setting
  const fresh = chips({ ...view(), snap: { ...s2, host: { ...host, gates: undefined } } }).map(c => c.label.trim())
  expect(fresh).toContain('gates 1+1 slots')
  // no waiters: no queue chip and nothing held
  const calm = chips({ ...view(), snap: { ...s2, host: { ...host, gates: { running: 1, waiting: 0 } } } }).map(c => c.label.trim())
  expect(calm.some(l => l.startsWith('queue') || l.startsWith('holding'))).toBe(false)
})

test('band: WSL2 in the host title, the CPU red mark, the state key, and the project key in project mode', async () => {
  const s2 = { ...snap, host: { ...snap.host!, wsl: true }, sessions: sessions.map((h, i) => ({ ...h, project: i % 2 ? 'Web Shop' : 'Docs Site', color: i % 2 ? '#16a085' : '#d35400' })) }
  const text = drawBand({ ...view(), snap: s2 }, 180, 10).map(l => lineText(l)).join('\n')
  expect(text.includes('HOST · WSL2 · 28 threads')).toBe(true)
  expect(text.includes('▘ busy')).toBe(true)
  expect(text.includes('acct 1')).toBe(true)
  const pv = drawBand({ ...view(), snap: s2, cfg: parseConfig({ dotMode: 'project' }, '/h') }, 180, 10).map(l => lineText(l)).join('\n')
  expect(pv.includes('Web Shop')).toBe(true)
  expect(pv.includes('2 projects')).toBe(true)
  expect(pv.includes('acct 1')).toBe(false)
  // the CPU bar carries the red-load mark; hidden with cpu-mark
  const cpuLine = (o: Record<string, unknown>): string => drawBand({ ...view(), snap: { ...s2, host: { ...s2.host, load: [1, 1, 1] as [number, number, number] } }, cfg: parseConfig(o, '/h') }, 180, 10).map(l => lineText(l)).find(l => l.includes('CPU')) ?? ''
  expect(cpuLine({}).includes('┊')).toBe(true)
  expect(cpuLine({ hideItems: 'cpu-mark' }).includes('┊')).toBe(false)
})

test('the pane header icon follows headerIcon: helm (default), astronaut or saturn', async () => {
  const head = (icon?: string): string => {
    const c = parseConfig(icon ? { headerIcon: icon } : {}, '/h')
    return drawPane(view({ cfg: c }), 60).slice(0, 6).map(l => l.map(s => s.runs.map(r => `${r.text}${r.fg}${r.bg}`).join('')).join('')).join('\n')
  }
  const [h, a, s] = [head(), head('astronaut'), head('saturn')]
  expect(head('helm')).toBe(h)
  expect(new Set([h, a, s]).size).toBe(3)
  expect(head('bogus')).toBe(h)
  expect(a.includes('#e0b050')).toBe(true) // the gold visor
  expect(s.includes('#e8b030')).toBe(true) // the amber planet
  for (const icon of ['helm', 'astronaut', 'saturn']) for (const l of drawPane(view({ cfg: parseConfig({ headerIcon: icon }, '/h') }), 60)) expect(widthOf(l)).toBeLessThanOrEqual(60)
})

test('the selected session detail sits under its own DETAIL heading', async () => {
  const text = drawPane(view({ sel: 1 }), 60).map(l => lineText(l))
  const i = text.findIndex(t => t.includes('DETAIL · click a row above'))
  expect(i).toBeGreaterThan(0)
  expect(text[i + 1]!.includes(`▸ ${sessions[1]!.name}`)).toBe(true)
})

test('the name column fits the longest name (7 to 12), so Atlas-BS is not cut', async () => {
  const ss = [S('Atlas-BS', 10), S('Mars', 10)]
  const row = sessionRow(view(), ss[0]!, 90, false, nameWidth(ss)).runs(0).map(r => r.text).join('')
  expect(row.includes('Atlas-BS')).toBe(true)
  expect(nameWidth([S('a', 1)])).toBe(7)
  expect(nameWidth([S('a-very-long-session-name', 1)])).toBe(12)
})

test('a busy session\'s mark turns clockwise: ▘ ▝ ▗ ▖, one step per half second', async () => {
  expect([0, 500, 1000, 1500, 2000].map(spin).join('')).toBe('▘▝▗▖▘')
  const mark = (now: number): string => sessionRow(view({ now }), S('Mars', 10, 'busy'), 70).runs(0).map(r => r.text).join('')
  expect(mark(0).includes('▘')).toBe(true)
  expect(mark(1000).includes('▗')).toBe(true)
  expect(sessionRow(view({ now: 1000 }), S('Mars', 10, 'idle'), 70).runs(0).map(r => r.text).join('').includes('○')).toBe(true)
})

test('alerts sit at the right of the chip line, most urgent first; holding is amber information', async () => {
  // snap: commit 88% (amber warning), load 28.3/28 (high); add a stuck session and one past the report mark
  const host = { ...snap.host!, gates: { running: 1, waiting: 2 } }
  const ss = sessions.map((h, i) => (i === 0 ? { ...h, stuck: 'waiting on you (permission)' } : h))
  const s2 = { ...snap, host, sessions: ss, local: { mode: 'auto', live: 'v0.06', next: '', slots: 1, kit: true } }
  const v2 = { ...view(), snap: s2 }
  const cs = chips(v2)
  const alerts = cs.filter(c => c.alert !== undefined).map(c => c.label.trim().split(':')[0]!.split(' ')[0])
  expect(alerts).toEqual(['⚠', 'STUCK', '≥350K', 'load'])
  const holding = cs.find(c => c.label.includes('holding'))
  expect(holding?.alert).toBe(undefined)
  expect(holding?.bg).toBe('#e8b030')
  // in the band every information chip comes before every alert, and the alerts end at the frame's right edge
  const line = lineText(drawBand(v2, 200, 10)[8]!)
  const lastInfo = Math.max(line.indexOf('sessions'), line.indexOf('live v0.06'))
  expect(lastInfo).toBeLessThan(line.indexOf('⚠ Windows commit'))
  expect(line.indexOf('⚠ Windows commit')).toBeLessThan(line.indexOf('STUCK'))
  expect(line.trimEnd().endsWith('high │')).toBe(true)
  expect(Array.from(line).length).toBe(200)
})
