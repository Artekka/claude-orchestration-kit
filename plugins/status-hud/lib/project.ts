import type { Local } from '../types'

/** The permission mode a claude command line starts in: normal, acceptEdits, auto, plan or bypass. */
export function modeFromArgs(args: string): string {
  if (/(^|\s)--dangerously-skip-permissions(\s|$)/.test(args)) return 'bypass'
  const m = /--permission-mode[= ]+(\S+)/.exec(args)
  const v = m?.[1] ?? 'default'
  if (v === 'bypassPermissions') return 'bypass'
  return v === 'default' ? 'normal' : v
}

/** The main checkout from `git rev-parse --path-format=absolute --git-common-dir` output; '' outside a repo. */
export function repoFromCommonDir(out: string): string {
  const d = out.trim()
  return d.endsWith('/.git') ? d.slice(0, -5) : ''
}

/**
 * A session's dot color: its own tab's color (CLAUDE_TAB_COLOR, set by whatever opened the tab), else the kit's
 * recorded color for the repo, else the team block's `tab_color:`, else ''.
 */
export function projectColor(repo: string, tabColors: string, overlay: string, tabColor = ''): string {
  if (/^#[0-9a-fA-F]{6}$/.test(tabColor.trim())) return tabColor.trim()
  for (const line of tabColors.split('\n')) {
    const [path, color] = line.split('\t')
    if (path === repo && color && /^#[0-9a-fA-F]{6}$/.test(color.trim())) return color.trim()
  }
  const m = /^[ \t]+tab_color:[ \t]*(#[0-9a-fA-F]{6})\b/m.exec(overlay)
  return m?.[1] ?? ''
}

/** Versions and test slots from a project's ORCHESTRATION.md (`live_version:`, `next_version:`, `gate_slots:`). */
export function localFromOverlay(overlay: string, mode: string): Local {
  const key = (k: string): string => (new RegExp(`^[ \\t]*${k}:[ \\t]*([^\\s#<]+)`, 'm').exec(overlay)?.[1] ?? '')
  const slots = Number(key('gate_slots'))
  return { mode, live: key('live_version'), next: key('next_version'), slots: Number.isInteger(slots) && slots > 0 ? slots : 2, kit: overlay.trim() !== '' }
}

/**
 * A stuck flag (written by scripts/hud-flag.sh: `{"reason","at"}`) counts until the session makes progress after it.
 * Returns the reason, or '' when there is no flag, it is malformed, or the session has moved on since.
 */
export function flagReason(text: string | null, progressAt: number): string {
  if (text === null) return ''
  try {
    const v = JSON.parse(text) as { reason?: unknown; at?: unknown }
    if (typeof v.reason !== 'string' || typeof v.at !== 'number') return ''
    return progressAt > v.at ? '' : v.reason.slice(0, 60)
  } catch {
    return ''
  }
}
