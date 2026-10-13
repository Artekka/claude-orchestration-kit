import type { Host } from '../types'
import type { Config } from './config'
import { type Io, sh } from './io'
import { parseCommit, parseDf, pickDisks, parseGpu, parseHost, parseLoadavg, parseMeminfo, pushHist, sampleScript, sections } from './host'

/** Host readings older than this are re-taken by whichever session notices first. */
export const HOST_MAX_AGE_MS = 5000
/** Longest a live writer can hold the lock: the sampler's timeout plus the commit command's. */
export const SAMPLER_TIMEOUT_MS = 10_000
export const COMMIT_TIMEOUT_MS = 15_000
export const HOLD_MAX_MS = SAMPLER_TIMEOUT_MS + COMMIT_TIMEOUT_MS
/** A lock older than this belongs to a dead writer: well past the longest live hold, so a slow writer is never robbed. */
export const LOCK_STALE_MS = HOLD_MAX_MS * 2 + 10_000

export const hostPath = (c: Config): string => `${c.statusDir}/host.json`
export const lockPath = (c: Config): string => `${c.statusDir}/host.lock`

export async function readHost(io: Io, c: Config): Promise<Host | null> {
  const t = await io.read(hostPath(c))
  return t === null ? null : parseHost(t)
}

/**
 * Single-writer refresh. `mkdir` is atomic, so of N sessions that all see a stale host.json
 * exactly one wins the lock and runs the shell; the others return what is on disk.
 */
export async function refreshHost(io: Io, c: Config): Promise<{ ran: boolean; host: Host | null }> {
  const now = await io.now()
  const cur = await readHost(io, c)
  if (cur !== null && now - cur.at < HOST_MAX_AGE_MS) return { ran: false, host: cur }

  const lock = lockPath(c)
  const got = await io.run(['mkdir', lock])
  if (got.exitCode !== 0) {
    await breakStaleLock(io, c, now)
    return { ran: false, host: cur }
  }
  // The token proves ownership: only the writer whose token is inside the lock may release it.
  const token = `${now}-${Math.random().toString(36).slice(2, 10)}`
  await io.writeAtomic(`${lock}/owner`, `${token} ${now}`)
  try {
    const out = await io.run(sh(sampleScript(c.mounts, c.extraChipsCmd, c.kitRuntimeDir)), SAMPLER_TIMEOUT_MS)
    const s = sections(out.stdout)
    const load = parseLoadavg(s.load ?? [])
    const mem = parseMeminfo(s.mem ?? [])
    if (load === null || mem === null) return { ran: false, host: cur }
    const threads = Number((s.nproc ?? [])[0]) || cur?.threads || 1
    const gpu = parseGpu(s.gpu ?? [])
    let commit = cur?.commit ?? null
    if (c.commitCmd !== '' && (commit === null || now - commit.at >= c.commitMs)) {
      const r = await io.run(sh(c.commitCmd), COMMIT_TIMEOUT_MS)
      const parsed = r.exitCode === 0 ? parseCommit(r.stdout, now) : null
      if (parsed) commit = parsed
    }
    const host: Host = {
      at: now,
      threads,
      load,
      ramUsedGb: mem.usedGb,
      ramTotalGb: mem.totalGb,
      disks: pickDisks(parseDf(s.df ?? []), c.mounts.includes('auto'), (s.os ?? [])[0] === 'wsl'),
      wsl: (s.os ?? [])[0] === 'wsl',
      ...(s.gates ? { gates: ((p: number[]) => ({ running: p[0] ?? 0, waiting: p[1] ?? 0 }))((s.gates[0] ?? '').split(/\s+/).map(Number)) } : {}),
      extra: (s.extra ?? []).map(l => l.trim().slice(0, 40)).filter(Boolean),
      gpu,
      commit,
      hist: {
        load: pushHist(cur?.hist.load ?? [], load[0]),
        ram: pushHist(cur?.hist.ram ?? [], mem.usedGb),
        gpu: pushHist(cur?.hist.gpu ?? [], gpu?.util ?? 0),
      },
    }
    await io.writeAtomic(hostPath(c), JSON.stringify(host))
    return { ran: true, host }
  } finally {
    // Release only our own lock: if it was taken over meanwhile, the new owner's lock stays.
    const owner = await io.read(`${lock}/owner`)
    if (owner !== null && owner.split(' ')[0] === token) await io.run(['rm', '-rf', lock])
  }
}

/**
 * Takes over a dead writer's lock. The age comes from the owner file (no process spawned); only a lock with no
 * owner file (a crash between mkdir and the write) falls back to stat. The takeover is a rename, which is atomic:
 * of several sessions that all see the stale lock, exactly one rename succeeds, and only that one deletes it.
 */
async function breakStaleLock(io: Io, c: Config, now: number): Promise<void> {
  const lock = lockPath(c)
  const owner = await io.read(`${lock}/owner`)
  let acquired = Number(owner?.split(' ')[1])
  if (!Number.isFinite(acquired)) {
    const age = await io.run(sh(`stat -c %Y ${lock} 2>/dev/null`))
    acquired = age.exitCode === 0 ? Number(age.stdout.trim()) * 1000 : NaN
  }
  if (!Number.isFinite(acquired) || now - acquired <= LOCK_STALE_MS) return
  const grave = `${lock}.stale-${now}-${Math.random().toString(36).slice(2, 10)}`
  const moved = await io.run(['mv', lock, grave])
  if (moved.exitCode === 0) await io.run(['rm', '-rf', grave])
}
