// Dev preview: prints the band or pane for a sample snapshot as ANSI truecolor text. Usage: tsx scripts/preview.ts band 180 | pane 60
import { parseConfig } from '../lib/config'
import { drawBand, drawPane, type Line } from '../lib/layout'
import type { Heartbeat, Snapshot } from '../types'

const hex = (h: string): string => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)).join(';')
function ansi(lines: Line[]): string {
  return lines
    .map(l => l.map(sg => sg.runs.map(r => `\x1b[38;2;${hex(r.fg)}m${r.bg ? `\x1b[48;2;${hex(r.bg)}m` : ''}${r.bold ? '\x1b[1m' : ''}${r.text}\x1b[0m`).join('')).join(''))
    .join('\n')
}
const S = (name: string, k: number, state: Heartbeat['state'], account: number, activity: string): Heartbeat => ({ id: name, name, model: 'opus', account, tokens: k * 1000, window: 1_000_000, state, activity, at: 0 })
const sessions = [
  S('Orca', 170, 'busy', 1, 'orchestrating · train 12 gate queued'), S('Vali', 113, 'busy', 1, 'AUDIT train 11'), S('Vali2', 105, 'busy', 1, 're-check row 7-4b r3'),
  S('Vali4', 92, 'busy', 1, 'READ row 6-4 r3'), S('Sib3', 56, 'busy', 2, 'row 6-3 settings page'), S('Sib5', 352, 'busy', 1, 'row 7-7 gate-final → retro'),
  S('Sib10', 231, 'shell', 2, 'row 6-5 r1 import job'), S('Sib11', 306, 'busy', 2, 'row 7-1 FALSIFY'), S('Sib12', 236, 'idle', 1, 'row 6-4 r3 design'), S('Sib13', 157, 'shell', 1, 'row 6-6 cache r1'),
]
const snap: Snapshot = {
  now: Date.now(), selfId: 'Orca', sessions, quietMode: false,
  host: {
    at: 0, threads: 28, load: [28.3, 28.0, 27.1], ramUsedGb: 15.6, ramTotalGb: 62, gpu: { util: 9, vramUsedGb: 11.8, vramTotalGb: 32.6, tempC: 44 },
    disks: [{ mount: '/', usedGb: 818, totalGb: 1007 }, { mount: '/mnt/n', usedGb: 4300, totalGb: 10150 }],
    commit: { usedPct: 88, limitGb: 127, usedGb: 112, at: 0 },
    hist: { load: Array.from({ length: 60 }, (_, i) => 24 + 6 * Math.sin(i / 5)), ram: Array.from({ length: 60 }, (_, i) => 14 + Math.sin(i / 7)), gpu: Array.from({ length: 60 }, (_, i) => 10 + 8 * Math.sin(i / 3)) },
  },
}
const cfg = parseConfig({ quietModeOnCmd: 'x', quietModeOffCmd: 'y' }, '/home/u')
const [kind = 'band', cols = '180', rows = '10', flash = '0'] = process.argv.slice(2)
const v = { snap, cfg, flash: flash === '1' ? { Sib5: Date.now() + 5000 } : {}, sel: 5, now: snap.now }
console.log(ansi(kind === 'pane' ? drawPane(v, Number(cols)) : drawBand(v, Number(cols), Number(rows))))
