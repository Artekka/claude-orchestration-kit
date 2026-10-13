import type { Config } from './config'

export type Level = 'ok' | 'amber' | 'red'

/** Context fill color: amber from the amber mark, red from the report mark (both inclusive). */
export function fillLevel(tokens: number, c: Pick<Config, 'amberMark' | 'reportMark'>): Level {
  if (tokens >= c.reportMark) return 'red'
  if (tokens >= c.amberMark) return 'amber'
  return 'ok'
}

/** True only on the update that moves a session from below the report mark to at/above it. */
export function crossedReport(prev: number | undefined, now: number, c: Pick<Config, 'reportMark'>): boolean {
  return prev !== undefined && prev < c.reportMark && now >= c.reportMark
}

/** Windows commit charge level from the percent of the limit in use. */
export function commitLevel(pct: number, c: Pick<Config, 'commitWarnPct' | 'commitCritPct'>): Level {
  if (pct >= c.commitCritPct) return 'red'
  if (pct >= c.commitWarnPct) return 'amber'
  return 'ok'
}

/** CPU: red at the configured load, else at 90% of the thread count. */
export function loadLevel(load: number, threads: number, c: Pick<Config, 'cpuRedLoad'>): Level {
  const red = c.cpuRedLoad > 0 ? c.cpuRedLoad : threads * 0.9
  if (load >= red) return 'red'
  if (load >= red * 0.8) return 'amber'
  return 'ok'
}

/** A session is flashing while its flash deadline is in the future and the flash is enabled. */
export function isFlashing(until: number | undefined, now: number): boolean {
  return until !== undefined && now < until
}

/** Alternates once a second so the flash reads as a blink, not a color change. */
export function flashPhase(now: number): boolean {
  return Math.floor(now / 500) % 2 === 0
}
