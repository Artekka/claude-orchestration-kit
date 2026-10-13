import { expect, test } from 'claude-code/testing'

import { parseConfig } from '../lib/config'
import { chips, drawBand, drawPane, lineText, sessionRow, type Line, type View } from '../lib/layout'
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

test('each session row shows a face from 😀 to 💀 at the hand-over mark, and its model', async () => {
  const row = (k: number, model = 'claude-opus-5-5[1m]'): string => sessionRow(view(), { ...S('Mars', k), model }, 70).runs(0).map(r => r.text).join('')
  expect(row(0).slice(0, 10)).toBe('● 😀 Mars ')
  expect(row(180).includes('😐')).toBe(true)
  expect(row(399).includes('😱')).toBe(true)
  expect(row(400).includes('💀')).toBe(true)
  expect(row(100).includes(' opus ')).toBe(true)
  expect(row(100, 'claude-sonnet-5-5').includes(' sonnet')).toBe(true)
  // the emoji's second column is an empty cell, so the row stays exactly 70 columns wide on screen
  const r = sessionRow(view(), S('Mars', 100), 70)
  expect(r.cells[0]!.length).toBe(70)
  expect(r.cells[0]![3]!.ch).toBe('')
  // faces off: the row starts with the name, as before
  const off = parseConfig({ sessionFaces: 'off' }, '/h')
  expect(sessionRow(view({ cfg: off }), S('Mars', 100), 70).runs(0).map(x => x.text).join('').startsWith('● Mars')).toBe(true)
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
