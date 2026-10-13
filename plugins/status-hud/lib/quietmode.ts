import type { Config } from './config'
import { type Io, sh } from './io'

/** null = not configured (the chip is hidden). */
export async function quietModeOn(io: Io, c: Config, exists: (p: string) => Promise<boolean>): Promise<boolean | null> {
  if (c.quietFlagFile !== '') return exists(c.quietFlagFile)
  if (c.quietStatusCmd !== '') return (await io.run(sh(c.quietStatusCmd), 10_000)).exitCode === 0
  return null
}

export function canToggle(c: Config): boolean {
  return c.quietOnCmd !== '' && c.quietOffCmd !== ''
}

/** Runs the configured on/off command for the OPPOSITE of the current state; returns the state asked for. */
export async function toggleQuietMode(io: Io, c: Config, current: boolean | null): Promise<{ ran: boolean; wanted: boolean; ok: boolean }> {
  const wanted = current !== true
  if (!canToggle(c)) return { ran: false, wanted, ok: false }
  const r = await io.run(sh(wanted ? c.quietOnCmd : c.quietOffCmd), 30_000)
  return { ran: true, wanted, ok: r.exitCode === 0 }
}
