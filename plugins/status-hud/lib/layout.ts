import type { Heartbeat, Host, Snapshot } from '../types'
import type { Config } from './config'
import { C, type Col, type Run, Scr, bar, clamp, graph2, lpad, pad, spark, sprite, trunc } from './cells'
import { commitLevel, faceFor, fillLevel, flashPhase, isFlashing, loadLevel, modelLabel, type Level } from './thresholds'
import { canToggle } from './quietmode'

export type View = { snap: Snapshot; cfg: Config; flash: Record<string, number>; sel: number; now: number }
/** One drawn piece of a line; `press` makes it a Button (`quiet`, `mode`, or `sel:<index>`). */
export type Seg = { runs: Run[]; press?: string }
export type Line = Seg[]

const LV: Record<Level, Col> = { ok: C.green, amber: C.amber, red: C.red }
const LVD: Record<Level, Col> = { ok: C.gD, amber: C.aD, red: C.rD }
const seg = (s: Scr, y: number, press?: string): Seg => (press ? { runs: s.runs(y), press } : { runs: s.runs(y) })
const one = (text: string, fg: Col, bg: Col | null = null, bold = false, press?: string): Seg => {
  const runs = [{ text, fg, bg, bold }]
  return press ? { runs, press } : { runs }
}
export const kfmt = (t: number): string => `${Math.round(t / 1000)}K`
const gb = (v: number, d = 1): string => v.toFixed(d)

/** `alert`: a warning to act on, its urgency (1 = most urgent); alerts are drawn apart, at the right, most urgent first. */
export type Chip = { label: string; fg: Col; bg: Col; press?: string; alert?: number }

// `changed`: the chip was just clicked; Claude Code's own line below the prompt says the new mode until a hook reports it.
const MODE_LABEL: Record<string, string> = { normal: 'normal mode', acceptEdits: 'accept-edits mode', auto: 'auto mode on', bypass: 'bypass mode on', plan: 'plan mode', changed: 'mode changed ↓' }

export function chips(v: View): Chip[] {
  const out: Chip[] = []
  const { snap, cfg } = v
  const on = (id: string): boolean => !cfg.hide.has(id)
  if (snap.quietMode !== null && on('work-mode')) {
    const qm = snap.quietMode
    const tog = canToggle(cfg)
    out.push({ label: ` ${qm ? 'QUIET mode' : 'WORK mode'}${tog ? ' ⏻' : ''} `, fg: qm ? C.white : C.bg, bg: qm ? C.orange : C.green, ...(tog ? { press: 'quiet' } : {}) })
  }
  const local = snap.local
  if (local && on('perm-mode')) {
    const label = ` ${MODE_LABEL[local.mode] ?? `${local.mode} mode`}${local.cycle ? ' ⇆' : ''} `
    out.push({ label, fg: C.tx, bg: C.bD, ...(local.cycle ? { press: 'mode' } : {}) })
  }
  const host = snap.host
  // The slots are the project's setting, shown even before the first test run creates the limiter's queue.
  if (local?.kit && on('gates')) out.push({ label: ` gates ${local.slots}+1 slots `, fg: C.tx, bg: C.gray })
  if (host?.gates) {
    if (on('queue') && host.gates.waiting > 0) out.push({ label: ` queue ${host.gates.waiting} waiting `, fg: C.bg, bg: C.amber })
    // The limiter holds the head of the line while the load is at or above 90% of the threads (its default).
    const maxLoad = host.threads * 0.9
    if (on('holding') && host.gates.waiting > 0 && host.load[0] >= maxLoad) {
      out.push({ label: ` holding: load ${host.load[0].toFixed(1)} ≥ ${maxLoad.toFixed(1)} `, fg: C.bg, bg: C.amber })
    }
  }
  if (on('extra')) for (const e of host?.extra ?? []) out.push({ label: ` ${e} `, fg: C.tx, bg: C.goldD })
  if (local?.live && on('live')) out.push({ label: ` live ${local.live} `, fg: C.gold, bg: C.goldD })
  if (local?.next && on('next')) out.push({ label: ` next ${local.next} `, fg: C.cyan, bg: C.cyanD })
  if (on('count')) out.push({ label: ` ${snap.sessions.length} sessions `, fg: C.tx, bg: C.gray })
  if (on('warnings')) {
    // Most urgent first: Windows memory (all of WSL dies at 100%), a stuck session (needs you), a session past the
    // report mark (hand it over soon), then a high load (watch).
    if (host?.commit) {
      const lv = commitLevel(host.commit.usedPct, cfg)
      if (lv !== 'ok') out.push({ label: ` ⚠ Windows commit ${Math.round(host.commit.usedPct)}% `, fg: C.white, bg: lv === 'red' ? C.rD : C.aD, alert: 1 })
    }
    const stuck = snap.sessions.filter(s => s.stuck)
    if (stuck.length > 0) out.push({ label: ` STUCK: ${stuck.map(s => s.name).join(' ')} `, fg: C.white, bg: C.rD, alert: 2 })
    const over = snap.sessions.filter(s => s.tokens >= cfg.reportMark)
    if (over.length > 0) out.push({ label: ` ≥${kfmt(cfg.reportMark)}: ${over.map(s => s.name).join(' ')} `, fg: C.white, bg: C.rD, alert: 3 })
    if (host && loadLevel(host.load[0], host.threads, cfg) === 'red') out.push({ label: ` load ${host.load[0].toFixed(1)} high `, fg: C.white, bg: C.rD, alert: 4 })
  }
  return out
}

/** Chips in two groups: information from the left, alerts against the right edge, so the two never mix. */
function chipLine(v: View, width: number, left: string, right: string): Line {
  const all = chips(v)
  const alerts = all.filter(c => c.alert !== undefined)
  const info = all.filter(c => c.alert === undefined)
  let used = left.length + right.length
  // Alerts claim their room first (they matter most), then information fills what is left.
  const shownAlerts: Chip[] = []
  for (const c of alerts) {
    if (used + c.label.length + 1 > width) break
    shownAlerts.push(c)
    used += c.label.length + 1
  }
  const line: Line = [one(left, C.dim)]
  for (const c of info) {
    if (used + c.label.length + 1 > width) break
    line.push(one(c.label, c.fg, c.bg, true, c.press), one(' ', C.tx))
    used += c.label.length + 1
  }
  line.push(one(' '.repeat(Math.max(0, width - used)), C.tx))
  for (const c of shownAlerts) line.push(one(' ', C.tx), one(c.label, c.fg, c.bg, true, c.press))
  line.push(one(right, C.dim))
  return line
}

function meterRow(s: Scr, x: number, y: number, label: string, f: number, fg: Col, text: string, barW: number, textFg: Col = C.tx, mark = -1): void {
  s.put(x, y, pad(label, 5), C.steel)
  bar(s, x + 5, y, barW, f, fg, mark)
  s.put(x + 6 + barW, y, text, textFg, null, true)
}

type Meter = { label: string; f: number; fg: Col; text: string; textFg: Col; mark: number; /** A mark as a fraction of the bar, for any bar width. */ markF?: number; hist?: { d: number[]; lo: number; hi: number } }

const markAt = (m: Meter, w: number): number => (m.markF !== undefined ? Math.min(w - 1, Math.round(m.markF * w)) : m.mark)

export function meters(v: View, max: number): Meter[] {
  const host = v.snap.host
  if (!host) return []
  const lv = loadLevel(host.load[0], host.threads, v.cfg)
  const out: Meter[] = []
  const cpuRed = v.cfg.cpuRedLoad > 0 ? v.cfg.cpuRedLoad : host.threads * 0.9
  // The bar is full at cpuRed / 0.9, so the red point sits at 90% of it: the mark shows how close the load is.
  out.push({ label: 'CPU', f: host.load[0] / (cpuRed / 0.9 || 1), fg: LV[lv], text: `${lpad(host.load[0].toFixed(1), 4)}/${host.threads}t`, textFg: LV[lv], mark: -1, ...(v.cfg.hide.has('cpu-mark') ? {} : { markF: 0.9 }), hist: { d: host.hist.load, lo: 0, hi: Math.max(host.threads, 1) } })
  out.push({ label: 'RAM', f: host.ramUsedGb / host.ramTotalGb, fg: C.cyan, text: `${gb(host.ramUsedGb)}/${gb(host.ramTotalGb, 0)}G`, textFg: C.tx, mark: -1, hist: { d: host.hist.ram, lo: 0, hi: host.ramTotalGb } })
  if (host.commit) {
    const cl = commitLevel(host.commit.usedPct, v.cfg)
    out.push({ label: 'WIN', f: host.commit.usedPct / 100, fg: LV[cl], text: `${Math.round(host.commit.usedPct)}% commit`, textFg: LV[cl], mark: Math.round((v.cfg.commitWarnPct / 100) * 14) })
  }
  if (host.gpu) {
    out.push({ label: 'GPU', f: host.gpu.util / 100, fg: C.purple, text: `${lpad(String(Math.round(host.gpu.util)), 3)}% ${Math.round(host.gpu.tempC)}°C`, textFg: C.purple, mark: -1, hist: { d: host.hist.gpu, lo: 0, hi: 100 } })
    out.push({ label: 'VRAM', f: host.gpu.vramUsedGb / host.gpu.vramTotalGb, fg: C.purple, text: `${gb(host.gpu.vramUsedGb)}/${gb(host.gpu.vramTotalGb)}G`, textFg: C.purple, mark: -1 })
  }
  for (const d of host.disks) {
    const f = d.usedGb / d.totalGb
    const hot = f >= 0.9 ? C.red : f >= 0.8 ? C.amber : C.green
    const total = d.totalGb >= 1000 ? `${gb(d.totalGb / 1024)}T` : `${Math.round(d.totalGb)}G`
    const used = d.totalGb >= 1000 ? `${gb(d.usedGb / 1024)}` : `${Math.round(d.usedGb)}`
    const wl = /^\/mnt\/([a-z])$/.exec(d.mount)
    out.push({ label: trunc(d.mount === '/' ? 'DISK' : wl ? `${(wl[1] as string).toUpperCase()}:` : (d.mount.split('/').pop() || d.mount).toUpperCase(), 5), f, fg: hot, text: `${used}/${total} ${Math.round(f * 100)}%`, textFg: hot, mark: -1 })
  }
  // Switched-off items go first: CPU/RAM/WIN/GPU/VRAM by name, the root disk as "disk", any other as "disk2".
  const STD: Record<string, string> = { CPU: 'cpu', RAM: 'ram', WIN: 'win', GPU: 'gpu', VRAM: 'vram' }
  let firstDisk = true
  const keep = out.filter(m => {
    const id = STD[m.label] ?? (firstDisk ? ((firstDisk = false), 'disk') : 'disk2')
    return !v.cfg.hide.has(id)
  })
  out.length = 0
  out.push(...keep)
  // Too many for the rows: drop disks beyond the first, then VRAM, before anything else.
  const drop = (pred: (m: Meter, i: number) => boolean): void => {
    const i = out.findIndex(pred)
    if (i >= 0) out.splice(i, 1)
  }
  const isDisk = (m: Meter): boolean => !['CPU', 'RAM', 'WIN', 'GPU', 'VRAM'].includes(m.label)
  while (out.length > max) {
    const firstDisk = out.findIndex(isDisk)
    const before = out.length
    drop((m, i) => isDisk(m) && i > firstDisk)
    if (out.length === before) drop(m => m.label === 'VRAM')
    if (out.length === before) out.pop()
  }
  return out
}

/** Model badge: OPS opus, SNT sonnet, HKU haiku, GEM gemini, else the family's first three letters. */
export function modelBadge(model: string): [string, Col] {
  const f = modelLabel(model)
  const map: Record<string, [string, Col]> = { opus: ['OPS', C.amber], sonnet: ['SNT', C.cyan], haiku: ['HKU', C.green], gemini: ['GEM', C.purple] }
  return map[f] ?? [f.slice(0, 3).toUpperCase().padEnd(3), C.steel]
}

/** The row's dot: the Claude account (blue 1, purple 2) or, in project mode, the project's tab color. */
export function dotColor(v: View, h: Heartbeat): Col {
  if (v.cfg.dotMode === 'project') return h.color || C.dim
  return h.account === 2 ? C.purple : C.blue
}

/** The activity cell: STUCK (red) with its reason, quiet for a while (amber), or the last action. */
export function activityOf(v: View, h: Heartbeat): [string, Col] {
  if (h.stuck) return [`STUCK · ${h.stuck}`, C.red]
  if (v.cfg.quietMs > 0 && (h.quietMs ?? 0) >= v.cfg.quietMs) return [`no progress ${Math.floor((h.quietMs ?? 0) / 60_000)} min · ${h.activity}`, C.amber]
  return [h.activity, C.dim]
}

/** One session row: dot, (face), name, model badge, context bar + K, state glyph, activity. Flashes red after crossing the report mark. */
export function sessionRow(v: View, h: Heartbeat, w: number, selected = false, nameW = 7): Scr {
  const s = new Scr(w, 1)
  const on = (id: string): boolean => !v.cfg.hide.has(id)
  const lv = fillLevel(h.tokens, v.cfg)
  const flashing = isFlashing(v.flash[h.id], v.now) && flashPhase(v.now)
  const bg = flashing ? C.rD : selected ? C.gray : null
  const fg = flashing ? C.white : LV[lv]
  for (let x = 0; x < w; x++) s.put(x, 0, ' ', C.tx, bg)
  const st = h.state === 'busy' ? [spin(v.now), C.green] : h.state === 'shell' ? ['$', C.orange] : ['○', C.dim]
  let x = 0
  if (on('dot')) {
    s.put(0, 0, '●', dotColor(v, h), bg)
    x = 2
  }
  if (v.cfg.faces && on('face') && w >= 30) {
    // An emoji is two terminal columns: the second cell holds nothing so the row keeps its width.
    s.put(x, 0, faceFor(h.tokens, v.cfg), C.tx, bg)
    s.cells[0]![x + 1] = { ch: '', fg: C.tx, bg, bold: false }
    x += 3
  }
  s.put(x, 0, pad(trunc(h.name, nameW), nameW), flashing ? C.white : h.state === 'idle' ? C.dim : C.tx, bg, true)
  x += nameW + 1
  if (on('model') && w >= 30) {
    const [b, c] = modelBadge(h.model)
    s.put(x, 0, b, flashing ? C.white : c, bg, true)
    x += 4
  }
  if (on('bar') && w >= 24) {
    const mark = Math.round((v.cfg.reportMark / h.window) * 8)
    bar(s, x, 0, 8, h.tokens / h.window, fg, mark)
    if (flashing) for (let i = 0; i < 8; i++) s.cells[0]![x + i]!.bg = bg
    x += 9
  }
  if (on('tokens')) {
    s.put(x, 0, `${lpad(kfmt(h.tokens), 5)}${lv === 'red' ? '!' : lv === 'amber' ? '~' : ' '}`, fg, bg, true)
    x += 7
  }
  if (on('state')) {
    s.put(x, 0, st[0] as string, flashing ? C.white : (st[1] as Col), bg, true)
    x += 2
  }
  if (on('activity') && w - x > 6) {
    const [text, col] = activityOf(v, h)
    s.put(x, 0, trunc(text, w - x), flashing ? C.white : col, bg, col === C.red)
  }
  return s
}

/** A busy session's mark turns clockwise through the four corners (▘ ▝ ▗ ▖), one step per half second. */
export const spin = (now: number): string => '▘▝▗▖'.charAt(Math.floor(now / 500) % 4)

/** The name column: wide enough for the longest name, 7 to 12 characters. */
export const nameWidth = (ss: readonly Heartbeat[]): number => clamp(Math.max(0, ...ss.map(h => h.name.length)), 7, 12)

const acctSummary = (ss: readonly Heartbeat[], shown = ss.length, cfg?: Config): string => {
  const head = shown < ss.length ? `SESSIONS ${shown}/${ss.length}` : `SESSIONS ${ss.length}`
  if (cfg?.dotMode === 'project') {
    const n = new Set(ss.map(s => s.project || '?')).size
    return `${head} · ${n} project${n === 1 ? '' : 's'}`
  }
  const a1 = ss.filter(s => s.account !== 2).length
  return `${head} · acct 1 ×${a1} · acct 2 ×${ss.length - a1}`
}

export const hostTitle = (v: View): string => `HOST · ${v.snap.host?.wsl ? 'WSL2 · ' : ''}${v.snap.host?.threads ?? '?'} threads`

/** Variant A: the framed band, up to 10 rows at 180 columns; falls back to the 3-row compact form when narrow or short. */
export function drawBand(v: View, cols: number, maxRows: number): Line[] {
  const W = clamp(cols, 20, 200)
  if (W < 90 || maxRows < 10) return drawCompact(v, W)
  const ss = v.snap.sessions
  const LX = 47
  const s = new Scr(W, 10)
  const dim = C.dim
  s.put(0, 0, `┌${'─'.repeat(W - 2)}┐`, dim)
  s.put(LX, 0, '┬', dim)
  const on = (id: string): boolean => !v.cfg.hide.has(id)
  if (on('host-title')) s.put(2, 0, ` ${hostTitle(v)} `, C.gold, null, true)
  const tag = ' STATUS HUD '
  if (on('frame-title')) s.put(W - 2 - tag.length, 0, tag, dim)
  for (let y = 1; y <= 6; y++) {
    s.put(0, y, '│', dim)
    s.put(LX, y, '│', dim)
    s.put(W - 1, y, '│', dim)
  }
  s.put(0, 7, `├${'─'.repeat(W - 2)}┤`, dim)
  s.put(LX, 7, '┴', dim)
  s.put(0, 9, `└${'─'.repeat(W - 2)}┘`, dim)

  const ms = meters(v, 6)
  ms.forEach((m, i) => {
    meterRow(s, 2, 1 + i, m.label, m.f, m.fg, m.text, 14, m.textFg, markAt(m, 14))
    if (m.hist && on('history') && LX - 2 - 32 >= 8) spark(s, 34, 1 + i, m.hist.d, Math.min(12, LX - 36), m.hist.lo, m.hist.hi, m.fg)
  })
  if (!v.snap.host) s.put(2, 2, 'waiting for host reading…', dim)

  const rx = LX + 2
  const area = W - rx - 2
  const win = ss[0]?.window ?? 1_000_000
  let kx = rx
  const key = (mark: string, col: Col, text: string): void => {
    if (kx + mark.length + text.length + 3 > W - 2) return
    s.put(kx, 1, mark, col)
    kx = s.put(kx + mark.length + 1, 1, text, dim) + 2
  }
  if (on('context-key')) {
    kx = s.put(kx, 1, `CONTEXT of ${win >= 1_000_000 ? `${win / 1_000_000}M` : kfmt(win)}`, dim) + 2
    key('■', C.green, `<${kfmt(v.cfg.amberMark)}`)
    key('■', C.amber, `${kfmt(v.cfg.amberMark)}-${kfmt(v.cfg.reportMark)}`)
    key('■', C.red, `≥${kfmt(v.cfg.reportMark)} report mark`)
  }
  if (on('dot-key') && on('dot')) {
    if (v.cfg.dotMode === 'project') {
      const seen = new Map<string, Col>()
      for (const h of ss) if (h.project && !seen.has(h.project)) seen.set(h.project, h.color || C.dim)
      for (const [name, col] of seen) key('●', col, trunc(name, 14))
    } else {
      key('●', C.blue, 'acct 1')
      key('●', C.purple, 'acct 2')
    }
  }
  if (on('state-key')) {
    key('▘', C.green, 'busy')
    key('$', C.orange, 'shell')
    key('○', C.dim, 'idle')
  }
  const cap = Math.max(0, area)
  const two = cap >= 126 && on('column2')
  const colW = two ? Math.floor((cap - 2) / 2) : cap
  const nCols = two ? 2 : 1
  const slots = 5 * nCols
  const shown = ss.length > slots ? slots - 1 : ss.length
  for (let i = 0; i < shown; i++) {
    const r = sessionRow(v, ss[i] as Heartbeat, colW, false, nameWidth(ss))
    const cx = rx + Math.floor(i / 5) * (colW + 2)
    const cy = 2 + (i % 5)
    r.cells[0]!.forEach((c, k) => {
      const row = s.cells[cy]
      if (row && cx + k < W - 1) row[cx + k] = c
    })
  }
  if (ss.length > slots) s.put(rx + (nCols - 1) * (colW + 2), 6, `+${ss.length - shown} more (/hud pane)`, dim)
  if (on('sessions-title')) s.put(LX + 2, 0, ` ${acctSummary(ss, shown, v.cfg)} `, C.gold, null, true)
  if (ss.length === 0) s.put(rx, 3, 'no sessions reporting yet', dim)

  const lines: Line[] = []
  for (let y = 0; y < 8; y++) lines.push([seg(s, y)])
  lines.push(chipLine(v, W, '│ ', '│'))
  lines.push([seg(s, 9)])
  return lines
}

/** Variant B form, used as the band's narrow/short fallback: meters, session pills, chips. */
export function drawCompact(v: View, W: number): Line[] {
  const s = new Scr(W, 2)
  let x = 1
  const host = v.snap.host
  for (const m of meters(v, 6)) {
    const need = m.label.length + 1 + 8 + 1 + m.text.length + 2
    if (x + need > W) break
    s.put(x, 0, m.label, C.steel)
    x += m.label.length + 1
    bar(s, x, 0, 8, m.f, m.fg, markAt(m, 8))
    x += 9
    x = s.put(x, 0, m.text, m.textFg, null, true) + 2
  }
  if (!host) s.put(1, 0, 'waiting for host reading…', C.dim)
  x = 1
  for (const h of v.snap.sessions) {
    const lv = fillLevel(h.tokens, v.cfg)
    const flashing = isFlashing(v.flash[h.id], v.now) && flashPhase(v.now)
    const bg = flashing ? C.rD : h.state === 'idle' ? C.gray : LVD[lv]
    const txt = ` ${trunc(h.name, 8)} ${kfmt(h.tokens)}${lv === 'red' ? '!' : ''} `
    const g = h.state === 'busy' ? spin(v.now) : h.state === 'shell' ? '$' : '○'
    if (x + txt.length + 4 > W) break
    s.put(x, 1, ' ', C.tx, bg)
    s.put(x + 1, 1, '●', h.account === 2 ? C.purple : C.blue, bg)
    s.put(x + 2, 1, txt, flashing ? C.white : h.state === 'idle' ? C.dim : LV[lv], bg, true)
    s.put(x + 2 + txt.length, 1, g, C.tx, bg, true)
    s.put(x + 3 + txt.length, 1, ' ', C.tx, bg)
    x += txt.length + 5
  }
  return [[seg(s, 0)], [seg(s, 1)], chipLine(v, W, ' ', '')]
}

const HELM = [
  '..H..........H..', '.HH..........HH.', '.HH..KKKKKK..HH.', '..HHKSSSSSSKHH..',
  '...KSLLSSSSSK...', '...KSLSSSSSSK...', '...KGGGGGGGGK...', '...KSSSKKSSSK...',
  '...KSSSKKSSDK...', '....KSSKKSSK....', '....KDS..SDK....', '.....KK..KK.....',
]
const PX: Record<string, Col> = { K: C.ol, S: C.steel, L: C.steelL, D: C.steelD, G: C.gold, H: C.bone }
// An astronaut's helmet: white shell, gold visor with a cyan glint, steel neck ring.
const ASTRONAUT = [
  '.....KKKKKK.....', '...KKWWWWWWKK...', '..KWWWWWWWWWWK..', '.KWWKKKKKKKKWWK.',
  '.KWKGGGGGGCCKWK.', '.KWKGGGGGGGCKWK.', '.KWKGGGGGGGGKWK.', '.KWKDGGGGGGDKWK.',
  '.KWWKKKKKKKKWWK.', '..KWWWWWWWWWWK..', '..KSSSSSSSSSSK..', '...KKKKKKKKKK...',
]
const ASTRONAUT_PX: Record<string, Col> = { K: C.ol, W: C.white, G: C.gold, C: C.cyan, D: C.goldD, S: C.steel }
// Saturn: a banded gold planet with its ring passing in front.
const SATURN = [
  '................', '......AAAA......', '....AAAAAAAA....', '...AYYYYYYYYA...',
  '...AAAAAAAAAA...', 'RR.AYYYYYYYYA.RR', '.RRRRRRRRRRRRRR.', '...RRRRRRRRRR...',
  '...AAAAAAAAAA...', '....AYYYYYYA....', '.....AAAAAA.....', '................',
]
const SATURN_PX: Record<string, Col> = { A: C.amber, Y: C.bone, R: C.steelL }
const ICONS: Record<Config['headerIcon'], [readonly string[], Record<string, Col>]> = {
  helm: [HELM, PX], astronaut: [ASTRONAUT, ASTRONAUT_PX], saturn: [SATURN, SATURN_PX],
}

const sep = (W: number, label: string): Line => {
  const s = new Scr(W, 1)
  s.put(0, 0, '─'.repeat(W), C.dim)
  if (label) s.put(1, 0, ` ${label} `, C.gold, null, true)
  return [seg(s, 0)]
}

/** Variant C: the taller pane (about 60 columns), sprite helm on top, every session a clickable row. */
export function drawPane(v: View, cols: number): Line[] {
  const W = clamp(cols, 30, 80)
  const host = v.snap.host
  const ss = v.snap.sessions
  const lines: Line[] = []
  const head = new Scr(W, 6)
  const showHelm = W >= 44
  if (showHelm) sprite(head, 1, 0, ...ICONS[v.cfg.headerIcon])
  const hx = showHelm ? 19 : 1
  head.put(hx, 0, 'STATUS HUD', C.gold, null, true)
  head.put(hx, 1, 'terminal status hud', C.steel)
  const d = new Date(v.now)
  const z = (n: number): string => String(n).padStart(2, '0')
  head.put(hx, 2, `${z(d.getHours())}:${z(d.getMinutes())}:${z(d.getSeconds())}`, C.dim)
  head.put(hx, 3, `${ss.length} sessions`, C.tx)
  for (let y = 0; y < 6; y++) lines.push([seg(head, y)])
  lines.push(sep(W, hostTitle(v)))
  const barW = clamp(W - 30, 8, 26)
  const ms = meters(v, 8)
  const m = new Scr(W, Math.max(1, ms.length))
  ms.forEach((x, i) => meterRow(m, 1, i, x.label, x.f, x.fg, x.text, barW, x.textFg, markAt(x, barW)))
  if (!host) m.put(1, 0, 'waiting for host reading…', C.dim)
  for (let y = 0; y < m.h; y++) lines.push([seg(m, y)])
  if (host && !v.cfg.hide.has('history')) {
    const g = new Scr(W, 3)
    g.put(1, 0, `LOAD HISTORY   avg ${host.load.map(x => x.toFixed(1)).join(' / ')}`, C.dim)
    graph2(g, 1, 1, host.hist.load, W - 2, 0, Math.max(host.threads, 1), LV[loadLevel(host.load[0], host.threads, v.cfg)])
    for (let y = 0; y < 3; y++) lines.push([seg(g, y)])
  }
  lines.push(sep(W, acctSummary(ss, ss.length, v.cfg)))
  ss.forEach((h, i) => lines.push([seg(sessionRow(v, h, W - 2, i === v.sel, nameWidth(ss)), 0, `sel:${i}`)]))
  const cur = ss[clamp(v.sel, 0, Math.max(0, ss.length - 1))]
  if (cur) {
    const lv = fillLevel(cur.tokens, v.cfg)
    // A labelled block, so the selected session's detail is not read as a second copy of its row.
    lines.push(sep(W, 'DETAIL · click a row above'))
    const t = new Scr(W, 3)
    t.put(1, 0, `▸ ${cur.name}`, C.gold, null, true)
    t.put(4 + cur.name.length, 0, `${cur.state} · ${kfmt(cur.tokens)} of ${kfmt(cur.window)} · ${v.cfg.dotMode === 'project' ? cur.project || 'no project' : `acct ${cur.account}`} · ${cur.model}`, C.dim)
    const [act, actCol] = activityOf(v, cur)
    t.put(1, 1, trunc(act, W - 2), actCol === C.dim ? C.tx : actCol)
    t.put(1, 2, `context ${Math.round((cur.tokens / cur.window) * 100)}% ${lv === 'red' ? '(report now)' : lv === 'amber' ? '(hand over soon)' : '(ok)'}`, LV[lv])
    for (let y = 0; y < 3; y++) lines.push([seg(t, y)])
  }
  lines.push(sep(W, 'MODE'))
  const all = chips(v)
  // Information first, then the alerts on a row of their own, most urgent first: the two never mix.
  const cl = [...all.filter(c => c.alert === undefined), ...all.filter(c => c.alert !== undefined)]
  let row: Line = [one(' ', C.tx)]
  let used = 1
  let inAlerts = false
  for (const c of cl) {
    const w = c.label.length + 1
    const breakToAlerts = c.alert !== undefined && !inAlerts && row.length > 1
    if (c.alert !== undefined) inAlerts = true
    if ((used + w > W || breakToAlerts) && row.length > 1) {
      lines.push(row)
      row = [one(' ', C.tx)]
      used = 1
    }
    row.push(one(c.label, c.fg, c.bg, true, c.press), one(' ', C.tx))
    used += w
  }
  lines.push(row)
  return lines
}

export const lineText = (l: Line): string => l.map(sg => sg.runs.map(r => r.text).join('')).join('')
export type { Host }
