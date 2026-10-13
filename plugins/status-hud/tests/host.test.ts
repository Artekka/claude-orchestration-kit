import { expect, test } from 'claude-code/testing'

import { parseConfig } from '../lib/config'
import { parseCommit, parseDf, parseGpu, parseLoadavg, parseMeminfo, pushHist, sections } from '../lib/host'
import { refreshHost, HOLD_MAX_MS, HOST_MAX_AGE_MS, LOCK_STALE_MS, hostPath } from '../lib/hostRefresh'
import { SAMPLE_OUT, fakeIo } from './fakeio'

// Every fake is microtask-based, so a bounded number of turns lets a started writer reach its blocking call.
const flush = async (): Promise<void> => {
  for (let i = 0; i < 50; i++) await Promise.resolve()
}
const cfg = parseConfig({ statusDir: '/s', mounts: '/,/data', commitCmd: 'ps1' }, '/home/u')

test('parsers read /proc, df and nvidia-smi output', async () => {
  const s = sections(SAMPLE_OUT)
  expect(parseLoadavg(s.load ?? [])).toEqual([28.31, 30, 31.2])
  const mem = parseMeminfo(s.mem ?? [])
  expect(Math.round((mem?.totalGb ?? 0) * 10) / 10).toBe(62)
  expect(Math.round((mem?.usedGb ?? 0) * 10) / 10).toBe(16)
  const disks = parseDf(s.df ?? [])
  expect(disks.map(d => d.mount)).toEqual(['/', '/data'])
  expect(parseGpu(s.gpu ?? [])).toEqual({ util: 9, vramUsedGb: 12100 / 1024, vramTotalGb: 32607 / 1024, tempC: 44 })
  expect(parseGpu([])).toBe(null)
  expect(parseLoadavg(['garbage'])).toBe(null)
})

test('commit parse: used percent of the Windows limit', async () => {
  const c = parseCommit('131000000 13100000\r\n', 5)
  expect(Math.round(c?.usedPct ?? 0)).toBe(90)
  expect(parseCommit('nope', 5)).toBe(null)
  expect(parseCommit('100 200', 5)).toBe(null)
})

test('history ring keeps the newest 80', async () => {
  let h: number[] = []
  for (let i = 0; i < 100; i++) h = pushHist(h, i)
  expect(h.length).toBe(80)
  expect(h[0]).toBe(20)
})

test('a fresh host.json is reused: no lock, no shell', async () => {
  const f = fakeIo({ runs: argv => (argv[0] === 'sh' ? { exitCode: 0, stdout: SAMPLE_OUT } : undefined) })
  expect((await refreshHost(f.io, { ...cfg, commitCmd: '' })).ran).toBe(true)
  f.calls.length = 0
  f.setNow(1_000_000 + HOST_MAX_AGE_MS - 1)
  const r = await refreshHost(f.io, cfg)
  expect(r.ran).toBe(false)
  expect(f.calls.length).toBe(0)
})

test('two sessions racing on a stale host: exactly one runs the sampler', async () => {
  let sampled = 0
  const f = fakeIo({
    runs: argv => {
      if (argv[0] === 'sh' && String(argv[2]).includes('/proc/loadavg')) {
        sampled++
        return { exitCode: 0, stdout: SAMPLE_OUT }
      }
      if (argv[0] === 'sh' && String(argv[2]).includes('ps1')) return { exitCode: 0, stdout: '131000000 13100000' }
      return undefined
    },
  })
  const [a, b] = await Promise.all([refreshHost(f.io, cfg), refreshHost(f.io, cfg)])
  expect([a.ran, b.ran].filter(Boolean).length).toBe(1)
  expect(sampled).toBe(1)
  expect(f.locks.size).toBe(0)
  const host = JSON.parse(f.files.get(hostPath(cfg))?.text ?? '{}')
  expect(host.threads).toBe(28)
  expect(Math.round(host.commit.usedPct)).toBe(90)
  expect(host.hist.load).toEqual([28.31])
})

test('the commit reading is slow-cadence: reused until commitSeconds passes', async () => {
  let commits = 0
  const f = fakeIo({
    runs: argv => {
      if (argv[0] !== 'sh') return undefined
      if (String(argv[2]).includes('/proc/loadavg')) return { exitCode: 0, stdout: SAMPLE_OUT }
      commits++
      return { exitCode: 0, stdout: '131000000 13100000' }
    },
  })
  await refreshHost(f.io, cfg)
  f.setNow(1_000_000 + 10_000)
  await refreshHost(f.io, cfg)
  expect(commits).toBe(1)
  f.setNow(1_000_000 + 31_000)
  await refreshHost(f.io, cfg)
  expect(commits).toBe(2)
})

test('a dead writer\u2019s lock is taken over once it is older than LOCK_STALE_MS, by exactly one of several sessions', async () => {
  const f = fakeIo({ now: 100_000_000 })
  f.locks.add('/s/host.lock')
  f.files.set('/s/host.lock/owner', { text: `dead-token ${100_000_000 - LOCK_STALE_MS - 1}`, mtimeMs: 0 })
  const rs = await Promise.all([refreshHost(f.io, cfg), refreshHost(f.io, cfg), refreshHost(f.io, cfg)])
  expect(rs.every(r => !r.ran)).toBe(true)
  expect(f.calls.filter(a => a[0] === 'mv').length).toBe(3)
  expect(f.graves.size).toBe(1)
  expect(f.locks.size).toBe(0)
})

test('a lock younger than LOCK_STALE_MS is never broken and costs no process spawn to judge', async () => {
  const f = fakeIo({ now: 100_000_000 })
  f.locks.add('/s/host.lock')
  f.files.set('/s/host.lock/owner', { text: `live ${100_000_000 - LOCK_STALE_MS + 1000}`, mtimeMs: 0 })
  await refreshHost(f.io, cfg)
  expect(f.calls.some(a => a[0] === 'mv' || a[0] === 'rm' || a[0] === 'sh')).toBe(false)
  expect(f.locks.size).toBe(1)
})

test('a slow live writer (sampler + commit near their timeouts) keeps its lock; a second session cannot start another', async () => {
  let commits = 0
  const gate: { release?: () => void } = {}
  const f = fakeIo({
    now: 100_000_000,
    runs: async argv => {
      if (argv[0] !== 'sh') return undefined
      if (String(argv[2]).includes('/proc/loadavg')) return { exitCode: 0, stdout: SAMPLE_OUT }
      commits++
      await new Promise<void>(r => (gate.release = r))
      return { exitCode: 0, stdout: '131000000 13100000' }
    },
  })
  const a = refreshHost(f.io, cfg)
  await flush()
  f.setNow(100_000_000 + HOLD_MAX_MS) // the longest a live writer can hold
  const b = await refreshHost(f.io, cfg)
  const c = await refreshHost(f.io, cfg)
  expect(b.ran || c.ran).toBe(false)
  expect(commits).toBe(1)
  expect(f.locks.size).toBe(1)
  gate.release?.()
  expect((await a).ran).toBe(true)
  expect(f.locks.size).toBe(0)
})

test('a writer whose lock was taken over does not delete the new owner\u2019s lock', async () => {
  const gate: { release?: () => void } = {}
  const f = fakeIo({
    now: 100_000_000,
    runs: async argv => {
      if (argv[0] !== 'sh') return undefined
      if (String(argv[2]).includes('/proc/loadavg')) return { exitCode: 0, stdout: SAMPLE_OUT }
      await new Promise<void>(r => (gate.release = r))
      return { exitCode: 0, stdout: '131000000 13100000' }
    },
  })
  const a = refreshHost(f.io, cfg)
  await flush()
  // simulate the lock being stolen and re-taken by another writer while A is still running
  f.locks.clear()
  f.locks.add('/s/host.lock')
  f.files.set('/s/host.lock/owner', { text: 'someone-else 100000001', mtimeMs: 0 })
  gate.release?.()
  await a
  expect(f.locks.has('/s/host.lock')).toBe(true)
  expect(f.files.get('/s/host.lock/owner')?.text).toBe('someone-else 100000001')
})

test('a failed sampler leaves the old reading and frees the lock', async () => {
  const f = fakeIo({ runs: argv => (argv[0] === 'sh' ? { exitCode: 0, stdout: '' } : undefined) })
  const r = await refreshHost(f.io, cfg)
  expect(r.ran).toBe(false)
  expect(f.locks.size).toBe(0)
  expect(f.files.has(hostPath(cfg))).toBe(false)
})
