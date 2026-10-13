import { mock } from 'claude-code/testing'

import { SAMPLE_OUT } from './fakeio'

type On = Parameters<typeof mock.clock>[0]

/** A mocked machine beneath the plugin: files, processes, session facts, env, store, clock. */
export function world(on: On, o: { name?: string; acct?: string; quietFlag?: string } = {}) {
  const files = new Map<string, string>()
  const ran: string[][] = []
  const usage = { tokens: 100_000, window: 1_000_000 }
  const clock = mock.clock(on, { now: 5_000_000 })
  mock.env(on, { HOME: '/home/u' })
  const stored: Record<string, unknown> = {}
  on('store.get', async (_$, e) => ({ value: stored[e.key] }))
  on('store.set', async (_$, e) => {
    stored[e.key] = e.value
    return { value: undefined }
  })
  on('session.start', async () => ({ cwd: '/x' }))
  on('session.id', async () => ({ value: 'sess-1234567' }))
  on('session.model', async () => ({ value: 'claude-opus-5-5' }))
  on('session.usage', async () => ({ value: { startedAt: 0, context: { tokens: usage.tokens, window: usage.window }, rateLimits: [] } as never }))
  on('command.register', async () => ({ value: undefined as never }))
  const opened: string[] = []
  on('ui.open', async (_$, e) => {
    opened.push(e.id)
    return { value: { isPlaced: true } }
  })
  on('ui.toast', async () => ({ value: undefined }))
  on('ui.status', async () => ({ value: undefined }))
  on('ui.close', async () => ({ value: undefined }))
  // The engine's own drawing beneath the mod: a pass-through (next) lands here and draws nothing of the HUD.
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e as never) as unknown as { Text: any }
    return h(Text, {}, 'ENGINE-DEFAULT') as never
  })
  on('fs.write', async (_$, e) => {
    files.set(e.path, e.text)
    return { value: undefined }
  })
  on('fs.read', async (_$, e) => {
    const t = files.get(e.path)
    return t === undefined ? { deny: 'ENOENT' } : { value: t }
  })
  on('fs.exists', async (_$, e) => ({ value: files.has(e.path) }))
  on('fs.list', async (_$, e) => ({
    value: [...files.keys()].filter(p => p.startsWith(`${e.path}/`) && !p.slice(e.path!.length + 1).includes('/')).map(p => ({ name: p.slice(e.path!.length + 1), kind: 'file' as const, size: 1, mtimeMs: 5_000_000, isLink: false })),
  }))
  on('process.run', async (_$, e) => {
    const argv = [...e.argv]
    ran.push(argv)
    const out = (stdout: string, exitCode = 0) => ({ value: { exitCode, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } })
    if (argv[0] === 'rm') {
      files.delete(argv[argv.length - 1] as string)
      return out('')
    }
    if (argv[0] === 'test') return out('', 1)
    if (argv[0] === 'mkdir' || argv[0] === 'mv') return out('')
    const script = String(argv[2] ?? '')
    if (script.includes('chmod 600')) {
      // writeAtomic: chmod then rename tmp ($1) over destination ($2)
      files.set(argv[5] as string, files.get(argv[4] as string) ?? '')
      files.delete(argv[4] as string)
      return out('')
    }
    if (script === 'false') return out('', 1)
    if (script.includes('/proc/loadavg')) return out(SAMPLE_OUT)
    if (script.includes('ps -o args=')) return out(`claude --name ${o.name ?? 'Orca'} --model opus::\nCLAUDE_CONFIG_DIR=${o.acct ?? '/home/u/.claude-acct2'}`)
    return out('')
  })
  return { files, ran, usage, clock, stored, opened }
}
