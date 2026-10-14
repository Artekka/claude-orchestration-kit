import type { PluginOptions } from 'claude-code'

export type Config = {
  variant: 'band' | 'pane' | 'off'
  /** The pixel picture at the top of the pane. */
  headerIcon: 'helm' | 'astronaut' | 'saturn'
  amberMark: number
  reportMark: number
  /** Context the face scale ends at (💀): the kit's hand-over mark. */
  handoverMark: number
  /** Draw a face per session row: 😀 when fresh to 💀 at the hand-over mark. */
  faces: boolean
  /** What a session row's dot shows: its Claude account (blue/purple) or its project's tab color. */
  dotMode: 'account' | 'project'
  /** Items switched off, by id (see README "Items"). */
  hide: Set<string>
  /** A shell command whose output lines each become a chip; '' = none. */
  extraChipsCmd: string
  /** Busy with no progress for this long = shown as quiet (amber); 0 = off. */
  quietMs: number
  /** The kit's runtime dir: the test-run limiter's queue and slots live there. */
  kitRuntimeDir: string
  flashMs: number
  commitWarnPct: number
  commitCritPct: number
  commitCmd: string
  commitMs: number
  mounts: string[]
  /** Session names that draw the HUD; empty means every session. Hidden sessions still write heartbeats. */
  showForNames: string[]
  statusDir: string
  sessionName: string
  refreshMs: number
  staleMs: number
  cpuRedLoad: number
  quietFlagFile: string
  quietStatusCmd: string
  quietOnCmd: string
  quietOffCmd: string
  /** The file (relative to the session directory, or absolute) the on/off commands need; the chip is hidden without it. Empty skips the check. */
  quietRequiresFile: string
}

const num = (v: unknown, d: number, min = 0): number =>
  typeof v === 'number' && Number.isFinite(v) && v >= min ? v : d
const str = (v: unknown, d = ''): string => (typeof v === 'string' ? v : d)

/** Whether a session draws the HUD: listed by name, or by a prefix ending in * ("Atlas*" matches Atlas-BS). */
export function nameShown(names: readonly string[], name: string): boolean {
  return names.length === 0 || names.some(n => (n.endsWith('*') ? name.startsWith(n.slice(0, -1)) : n === name))
}

/** Options arrive typed by the manifest, but a hand-edited settings file can hold anything: clamp, never throw. */
export function parseConfig(o: PluginOptions, home: string): Config {
  const variant = str(o.variant, 'band')
  const dir = str(o.statusDir).trim()
  return {
    variant: variant === 'pane' || variant === 'off' ? variant : 'band',
    headerIcon: ((i: string): Config['headerIcon'] => (i === 'astronaut' || i === 'saturn' ? i : 'helm'))(str(o.headerIcon, 'helm')),
    amberMark: num(o.contextAmberMark, 300_000),
    reportMark: num(o.contextReportMark, 350_000),
    handoverMark: num(o.contextHandoverMark, 400_000, 1),
    faces: str(o.sessionFaces, 'off') === 'on',
    dotMode: str(o.dotMode, 'account') === 'project' ? 'project' : 'account',
    hide: new Set(str(o.hideItems).split(',').map(s => s.trim().toLowerCase()).filter(Boolean)),
    extraChipsCmd: str(o.extraChipsCmd).trim(),
    quietMs: num(o.quietMinutes, 20) * 60_000,
    kitRuntimeDir: (str(o.kitRuntimeDir).trim() || '~/.orchestration-kit/runtime').replace(/^~(?=\/|$)/, home),
    flashMs: num(o.flashSeconds, 6) * 1000,
    commitWarnPct: num(o.commitWarnPct, 85),
    commitCritPct: num(o.commitCritPct, 95),
    commitCmd: str(o.commitCmd),
    commitMs: Math.max(5, num(o.commitSeconds, 30)) * 1000,
    mounts: str(o.mounts, '/').split(',').map(s => s.trim()).filter(Boolean),
    showForNames: str(o.showForNames, 'Orca').split(',').map(s => s.trim()).filter(Boolean),
    statusDir: dir === '' ? `${home}/.claude-status-hud` : dir.replace(/^~(?=\/|$)/, home),
    sessionName: str(o.sessionName).trim(),
    refreshMs: Math.max(1, num(o.refreshSeconds, 3)) * 1000,
    staleMs: Math.max(10, num(o.staleSeconds, 120)) * 1000,
    cpuRedLoad: num(o.cpuRedLoad, 0),
    quietFlagFile: str(o.quietModeFlagFile).trim().replace(/^~(?=\/|$)/, home),
    quietStatusCmd: str(o.quietModeStatusCmd).trim(),
    quietOnCmd: str(o.quietModeOnCmd).trim(),
    quietOffCmd: str(o.quietModeOffCmd).trim(),
    quietRequiresFile: str(o.quietModeRequiresFile, 'scripts/quiet-mode.sh').trim(),
  }
}
