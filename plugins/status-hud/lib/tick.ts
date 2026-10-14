import type { Heartbeat, QuietErr, Snapshot } from '../types'
import type { Config } from './config'
import { type Io } from './io'
import { liveSessions, parseHeartbeat, serializeHeartbeat } from './heartbeat'
import { refreshHost } from './hostRefresh'
import { crossedReport } from './thresholds'
import { quietAvailable, quietModeOn } from './quietmode'

export const sessionsDir = (c: Config): string => `${c.statusDir}/sessions`
const hbPath = (c: Config, id: string): string => `${sessionsDir(c)}/${id.replace(/[^A-Za-z0-9_-]/g, '_')}.json`

export type TickState = { prevTokens: Map<string, number>; flash: Record<string, number>; quietErr: QuietErr | null }
export const newTickState = (): TickState => ({ prevTokens: new Map(), flash: {}, quietErr: null })

/**
 * One refresh: write own heartbeat, refresh the host if stale (single writer), read every session, find report-mark
 * crossings. Everything the drawing needs ends up in the returned snapshot; drawing never touches disk.
 */
export async function tick(
  io: Io, c: Config, own: Heartbeat, ts: TickState, exists: (p: string) => Promise<boolean>, cwd = '',
): Promise<Snapshot> {
  const now = await io.now()
  await io.writeAtomic(hbPath(c, own.id), serializeHeartbeat({ ...own, at: now }))
  const { host } = await refreshHost(io, c)

  const all: Heartbeat[] = []
  for (const f of await io.list(sessionsDir(c))) {
    const path = `${sessionsDir(c)}/${f.name}`
    // An orphaned tmp (a writer died between write and rename) is swept once it is clearly dead.
    if (f.name.endsWith('.tmp')) {
      if (now - f.mtimeMs > c.staleMs) await io.remove(path)
      continue
    }
    if (!f.name.endsWith('.json')) continue
    // A file twice as old as the stale limit is a dead session's: sweep it.
    if (now - f.mtimeMs > c.staleMs * 2) {
      await io.remove(path)
      continue
    }
    const t = await io.read(path)
    const hb = t === null ? null : parseHeartbeat(t)
    if (hb && hb.id !== own.id) all.push(hb)
  }
  all.push({ ...own, at: now })
  const sessions = liveSessions(all, now, c.staleMs)

  for (const s of sessions) {
    if (c.flashMs > 0 && crossedReport(ts.prevTokens.get(s.id), s.tokens, c)) ts.flash[s.id] = now + c.flashMs
    ts.prevTokens.set(s.id, s.tokens)
  }
  for (const [id, until] of Object.entries(ts.flash)) if (until <= now) delete ts.flash[id]

  for (const f of await io.list(c.statusDir)) {
    if (f.name.endsWith('.tmp') && now - f.mtimeMs > c.staleMs) await io.remove(`${c.statusDir}/${f.name}`)
  }
  const quietMode = await quietModeOn(io, c, exists)
  if (ts.quietErr && ts.quietErr.until <= now) ts.quietErr = null
  return { now, selfId: own.id, sessions, host, quietMode, quietAvail: await quietAvailable(c, cwd, exists), quietErr: ts.quietErr }
}
