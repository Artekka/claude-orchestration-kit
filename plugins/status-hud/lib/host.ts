import type { Host } from '../types'

const GB = 1024 * 1024

const shq = (s: string): string => `'${s.replace(/'/g, `'\\''`)}'`

/** One shell spawn for every cheap metric; sections are marked so one bad tool cannot shift the rest. */
export function sampleScript(mounts: readonly string[]): string {
  return [
    `echo '##load'; cat /proc/loadavg`,
    `echo '##nproc'; nproc`,
    `echo '##mem'; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo`,
    `echo '##df'; df -Pk ${mounts.map(shq).join(' ')} 2>/dev/null`,
    `echo '##gpu'; nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null`,
    `true`,
  ].join('; ')
}

export function sections(out: string): Record<string, string[]> {
  const res: Record<string, string[]> = {}
  let cur: string[] | undefined
  for (const line of out.split('\n')) {
    const m = /^##(\w+)$/.exec(line)
    if (m) {
      cur = []
      res[m[1] as string] = cur
    } else if (cur && line.trim() !== '') cur.push(line)
  }
  return res
}

export function parseLoadavg(lines: string[]): [number, number, number] | null {
  const p = (lines[0] ?? '').split(/\s+/).map(Number)
  const [a, b, c] = p
  return a !== undefined && b !== undefined && c !== undefined && [a, b, c].every(Number.isFinite) ? [a, b, c] : null
}

export function parseMeminfo(lines: string[]): { totalGb: number; usedGb: number } | null {
  const get = (k: string): number | undefined => {
    const l = lines.find(x => x.startsWith(`${k}:`))
    const n = l ? Number(/(\d+)/.exec(l)?.[1]) : NaN
    return Number.isFinite(n) ? n : undefined
  }
  const total = get('MemTotal')
  const avail = get('MemAvailable')
  if (total === undefined || avail === undefined) return null
  return { totalGb: total / GB, usedGb: (total - avail) / GB }
}

/** `df -Pk` rows: Filesystem 1K-blocks Used Available Capacity Mounted-on. */
export function parseDf(lines: string[]): Host['disks'] {
  const out: Host['disks'] = []
  for (const l of lines) {
    const f = l.trim().split(/\s+/)
    if (f.length < 6 || f[0] === 'Filesystem') continue
    const total = Number(f[1])
    const used = Number(f[2])
    if (!Number.isFinite(total) || !Number.isFinite(used)) continue
    out.push({ mount: f.slice(5).join(' '), usedGb: used / GB, totalGb: total / GB })
  }
  return out
}

export function parseGpu(lines: string[]): Host['gpu'] {
  const f = (lines[0] ?? '').split(',').map(s => Number(s.trim()))
  const [util, used, total, temp] = f
  if (util === undefined || used === undefined || total === undefined || temp === undefined) return null
  if (![util, used, total, temp].every(Number.isFinite)) return null
  return { util, vramUsedGb: used / 1024, vramTotalGb: total / 1024, tempC: temp }
}

/** The commit command prints "<TotalVirtualMemorySize KB> <FreeVirtualMemory KB>". */
export function parseCommit(out: string, at: number): NonNullable<Host['commit']> | null {
  const m = /(\d+)\s+(\d+)/.exec(out)
  if (!m) return null
  const limitKb = Number(m[1])
  const freeKb = Number(m[2])
  if (!(limitKb > 0) || freeKb > limitKb) return null
  const usedKb = limitKb - freeKb
  return { usedPct: (usedKb / limitKb) * 100, limitGb: limitKb / GB, usedGb: usedKb / GB, at }
}

export function pushHist(h: number[], v: number, max = 80): number[] {
  const n = [...h, v]
  return n.length > max ? n.slice(n.length - max) : n
}

export function parseHost(text: string): Host | null {
  try {
    const v = JSON.parse(text) as Host
    return typeof v.at === 'number' && Array.isArray(v.load) ? v : null
  } catch {
    return null
  }
}
