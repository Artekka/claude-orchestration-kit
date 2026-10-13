import type { Io, RunResult } from '../lib/io'

/** In-memory Io: files in a map, `run` answered by a script of handlers, every call recorded. */
export function fakeIo(opts: { now?: number; runs?: (argv: string[]) => RunResult | undefined | Promise<RunResult | undefined> } = {}) {
  const files = new Map<string, { text: string; mtimeMs: number }>()
  const locks = new Set<string>()
  const calls: string[][] = []
  const graves = new Map<string, string>()
  let now = opts.now ?? 1_000_000
  const io: Io = {
    read: async p => files.get(p)?.text ?? null,
    writeAtomic: async (p, text) => void files.set(p, { text, mtimeMs: now }),
    list: async d => [...files.entries()].filter(([p]) => p.startsWith(`${d}/`)).map(([p, f]) => ({ name: p.slice(d.length + 1), mtimeMs: f.mtimeMs })),
    remove: async p => void files.delete(p),
    now: async () => now,
    run: async argv => {
      calls.push(argv)
      // The lock is a directory: mkdir is atomic, `mv` of it is an atomic rename, `rm -rf` frees it.
      if (argv[0] === 'mkdir') {
        const p = argv[1] as string
        if (locks.has(p)) return { exitCode: 1, stdout: '' }
        locks.add(p)
        return { exitCode: 0, stdout: '' }
      }
      if (argv[0] === 'rm') {
        const p = argv[argv.length - 1] as string
        locks.delete(p)
        files.delete(`${p}/owner`)
        return { exitCode: 0, stdout: '' }
      }
      if (argv[0] === 'mv') {
        const [from, to] = [argv[1] as string, argv[2] as string]
        if (!locks.has(from)) return { exitCode: 1, stdout: '' }
        locks.delete(from)
        const owner = files.get(`${from}/owner`)?.text
        files.delete(`${from}/owner`)
        graves.set(to, owner ?? '')
        return { exitCode: 0, stdout: '' }
      }
      return (await opts.runs?.(argv)) ?? { exitCode: 0, stdout: '' }
    },
  }
  return { io, files, locks, calls, graves, setNow: (n: number) => void (now = n) }
}

export const SAMPLE_OUT = [
  '##load', '28.31 30.00 31.20 5/900 12345',
  '##nproc', '28',
  '##mem', 'MemTotal:       65011712 kB', 'MemAvailable:   48234496 kB',
  '##df', 'Filesystem Type 1024-blocks Used Available Capacity Mounted on', '/dev/sdc ext4 1056858112 857000000 150000000 86% /', 'x ext4 2097152000 943718400 1153433600 45% /data',
  '##gpu', '9, 12100, 32607, 44',
].join('\n')
