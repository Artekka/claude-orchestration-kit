import type { Host } from '../types'

const GB = 1024 * 1024

const shq = (s: string): string => `'${s.replace(/'/g, `'\\''`)}'`

/** One shell spawn for every cheap metric; sections are marked so one bad tool cannot shift the rest. */
export function sampleScript(mounts: readonly string[], extraCmd = '', kitRuntime = ''): string {
  // "auto" lists every mounted filesystem; pickDisks keeps the real drives.
  const df = mounts.includes('auto') ? `df -PkT 2>/dev/null` : `df -PkT ${mounts.map(shq).join(' ')} 2>/dev/null`
  return [
    `echo '##os'; grep -qi microsoft /proc/version 2>/dev/null && echo wsl`,
    `echo '##load'; cat /proc/loadavg`,
    `echo '##nproc'; nproc`,
    `echo '##mem'; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo`,
    `echo '##df'; ${df}`,
    `echo '##gpu'; nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null`,
    // The kit's test-run limiter: live runs holding a slot (running/<pid>) and live waiters (queue/<n>.<pid>).
    ...(kitRuntime ? [`R=${shq(kitRuntime)}; if [ -d "$R/running" ]; then echo '##gates'; r=0; q=0; for f in "$R"/running/*; do [ -e "$f" ] || continue; kill -0 "\${f##*/}" 2>/dev/null && r=$((r+1)); done; for f in "$R"/queue/[0-9]*.*; do [ -e "$f" ] || continue; kill -0 "\${f##*.}" 2>/dev/null && q=$((q+1)); done; echo "$r $q"; fi`] : []),
    ...(extraCmd ? [`echo '##extra'; timeout 3 sh -c ${shq(extraCmd)} 2>/dev/null | head -6`] : []),
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

/** `df -PkT` rows: Filesystem Type 1K-blocks Used Available Capacity Mounted-on. */
export function parseDf(lines: string[]): (Host['disks'][number] & { fs: string; type: string })[] {
  const out: (Host['disks'][number] & { fs: string; type: string })[] = []
  for (const l of lines) {
    const f = l.trim().split(/\s+/)
    if (f.length < 7 || f[0] === 'Filesystem') continue
    const total = Number(f[2])
    const used = Number(f[3])
    if (!Number.isFinite(total) || !Number.isFinite(used) || total <= 0) continue
    out.push({ fs: f[0] as string, type: f[1] as string, mount: f.slice(6).join(' '), usedGb: used / GB, totalGb: total / GB })
  }
  return out
}

/**
 * The disks to show. A configured list shows what df printed for it. "auto" shows the Linux root, then each other
 * real drive in use: on WSL a Windows drive letter other than C: (C: holds WSL's own disk, already shown as the
 * root); elsewhere a block device mounted outside /boot. Duplicates of one device are shown once.
 */
export function pickDisks(rows: ReturnType<typeof parseDf>, auto: boolean, wsl: boolean): Host['disks'] {
  const strip = ({ mount, usedGb, totalGb }: { mount: string; usedGb: number; totalGb: number }) => ({ mount, usedGb, totalGb })
  if (!auto) return rows.map(strip)
  const seen = new Set<string>()
  const out: Host['disks'] = []
  for (const r of rows) {
    const root = r.mount === '/'
    const winDrive = wsl && /^\/mnt\/[a-z]$/.test(r.mount) && r.mount !== '/mnt/c'
    const block = !wsl && r.fs.startsWith('/dev/') && !r.mount.startsWith('/boot') && !r.mount.startsWith('/snap')
    if (!(root || winDrive || block) || seen.has(r.fs)) continue
    seen.add(r.fs)
    out.push(strip(r))
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
