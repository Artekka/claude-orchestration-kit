export type Busy = 'busy' | 'idle' | 'shell'

/** One session's self-report, written to <statusDir>/sessions/<id>.json. */
export type Heartbeat = {
  id: string
  name: string
  model: string
  /** 1 or 2: from CLAUDE_CONFIG_DIR (none = 1). */
  account: number
  tokens: number
  window: number
  state: Busy
  activity: string
  at: number
  /** The kit project the session works in (its main checkout's folder name); '' outside one. */
  project?: string
  /** That project's tab color (#rrggbb), from the kit's tab-colors record or its team block; '' when none. */
  color?: string
  /** Permission mode the session was started with: normal, acceptEdits, auto, bypass, plan. */
  mode?: string
  /** Why the session is stuck ('' = not stuck): waiting on you, or a reported or unanswered-ping flag. */
  stuck?: string
  /** ms since the session last made progress while busy (0 when idle or working). */
  quietMs?: number
}

/** The shared host reading, written to <statusDir>/host.json by whichever session finds it stale. */
export type Host = {
  at: number
  threads: number
  load: [number, number, number]
  ramUsedGb: number
  ramTotalGb: number
  disks: { mount: string; usedGb: number; totalGb: number }[]
  gpu: { util: number; vramUsedGb: number; vramTotalGb: number; tempC: number } | null
  commit: { usedPct: number; limitGb: number; usedGb: number; at: number } | null
  hist: { load: number[]; ram: number[]; gpu: number[] }
  /** Running under WSL (Linux inside Windows). */
  wsl?: boolean
  /** The kit's test-run limiter: runs holding a slot and runs waiting for one; absent = not in use here. */
  gates?: { running: number; waiting: number }
  /** Lines printed by the configured extra-chips command, one chip each (e.g. "blender 0/2"). */
  extra?: string[]
}

/** Facts about the project of the session drawing the HUD: its permission mode, versions and test slots. */
export type Local = { mode: string; live: string; next: string; slots: number; /** the project has a kit overlay */ kit?: boolean }

export type Snapshot = {
  now: number
  selfId: string
  sessions: Heartbeat[]
  host: Host | null
  /** null = no quiet mode configured. */
  quietMode: boolean | null
  local?: Local
}

declare module 'claude-code' {
  interface PluginState {
    'status-hud': {
      snap: Snapshot | null
      /** session id -> epoch ms until which it flashes red. */
      flash: Record<string, number>
      /** Highlighted session index in the pane. */
      sel: number
      /** Runtime variant override from /hud (config is the default). */
      variant: string | null
    }
  }
}
