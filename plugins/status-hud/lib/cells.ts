/** A text-mode canvas: every cell is one character with a foreground, a background and bold. */
export const C = {
  bg: '#0b0d10', tx: '#cfd4d9', dim: '#6a727c', dim2: '#2f363e', green: '#4fd160', amber: '#e8b030',
  red: '#f05050', blue: '#58a6ff', cyan: '#4cd0e0', purple: '#b98cf0', gold: '#e0b050', orange: '#ee8a3c',
  white: '#f4f4f4', steel: '#8a9bb0', steelL: '#c5d3e3', steelD: '#4a5668', bone: '#e8dcc0', ol: '#2d3643',
  gD: '#123a1c', aD: '#40300a', rD: '#6a1c22', bD: '#12304d', goldD: '#43330e', cyanD: '#0e3a40', gray: '#262c33',
} as const
export type Col = string

export type Cell = { ch: string; fg: Col; bg: Col | null; bold: boolean }
export type Run = { text: string; fg: Col; bg: Col | null; bold: boolean }

export class Scr {
  readonly cells: Cell[][]
  constructor(readonly w: number, readonly h: number) {
    this.cells = Array.from({ length: h }, () => Array.from({ length: w }, () => ({ ch: ' ', fg: C.tx, bg: null, bold: false })))
  }
  put(x: number, y: number, s: string, fg: Col = C.tx, bg: Col | null = null, bold = false): number {
    const row = this.cells[y]
    if (!row) return x
    for (const ch of Array.from(s)) {
      if (x >= 0 && x < this.w) row[x] = { ch, fg, bg, bold }
      x++
    }
    return x
  }
  runs(y: number): Run[] {
    const out: Run[] = []
    for (const c of this.cells[y] ?? []) {
      const last = out[out.length - 1]
      if (last && last.fg === c.fg && last.bg === c.bg && last.bold === c.bold) last.text += c.ch
      else out.push({ text: c.ch, fg: c.fg, bg: c.bg, bold: c.bold })
    }
    return out
  }
}

export const clamp = (v: number, a: number, b: number): number => Math.max(a, Math.min(b, v))
export const trunc = (s: string, n: number): string => (n <= 0 ? '' : s.length > n ? `${s.slice(0, Math.max(0, n - 1))}…` : s)
export const pad = (s: string, n: number): string => (s.length >= n ? s.slice(0, n) : s + ' '.repeat(n - s.length))
export const lpad = (s: string, n: number): string => (s.length >= n ? s : ' '.repeat(n - s.length) + s)

/** Chunky meter: full blocks, a half block for the partial cell, shaded rest, optional threshold tick. */
export function bar(s: Scr, x: number, y: number, w: number, f: number, fg: Col, mark = -1): void {
  const q = clamp(f, 0, 1) * w
  const full = Math.floor(q)
  const half = q - full >= 0.5
  for (let i = 0; i < w; i++) {
    if (i < full) s.put(x + i, y, '█', fg)
    else if (i === full && half) s.put(x + i, y, '▌', fg)
    else if (i === mark) s.put(x + i, y, '┊', C.amber)
    else s.put(x + i, y, '░', C.dim2)
  }
}

const SP = '▁▂▃▄▅▆▇█'
export function spark(s: Scr, x: number, y: number, h: readonly number[], w: number, lo: number, hi: number, fg: Col): void {
  const d = h.slice(-w)
  d.forEach((v, i) => s.put(x + i, y, SP.charAt(Math.round(clamp((v - lo) / (hi - lo || 1), 0, 1) * 7)), fg))
}

/** Two-row pixel graph, four pixels tall, from full and lower-half blocks. */
export function graph2(s: Scr, x: number, y: number, h: readonly number[], w: number, lo: number, hi: number, fg: Col): void {
  const d = h.slice(-w)
  d.forEach((v, i) => {
    const px = Math.round(clamp((v - lo) / (hi - lo || 1), 0, 1) * 4)
    s.put(x + i, y, px >= 4 ? '█' : px === 3 ? '▄' : ' ', fg)
    s.put(x + i, y + 1, px >= 2 ? '█' : px === 1 ? '▄' : ' ', fg)
  })
}

/** Half-block sprite: two pixel rows per text row (top = foreground of ▀, bottom = its background). */
export function sprite(s: Scr, x: number, y: number, rows: readonly string[], px: Record<string, Col>): void {
  for (let r = 0; r < rows.length; r += 2) {
    const top = rows[r] ?? ''
    const bot = rows[r + 1] ?? ''
    for (let c = 0; c < top.length; c++) {
      const t = px[top.charAt(c)]
      const u = px[bot.charAt(c)]
      if (t && u) s.put(x + c, y + r / 2, '▀', t, u)
      else if (t) s.put(x + c, y + r / 2, '▀', t, null)
      else if (u) s.put(x + c, y + r / 2, '▄', u, null)
    }
  }
}
