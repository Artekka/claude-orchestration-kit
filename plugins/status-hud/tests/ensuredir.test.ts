import { expect, test } from 'claude-code/testing'

import { ensureStatusDirs } from '../lib/ensureDir'
import { fakeIo } from './fakeio'

test('a status dir this mod creates is made owner-only (mode 700 at creation)', async () => {
  const f = fakeIo({ runs: a => (a[0] === 'test' ? { exitCode: 1, stdout: '' } : undefined) })
  await ensureStatusDirs(f.io, '/s')
  const made = f.calls.filter(a => a[0] === 'mkdir')
  expect(made).toEqual([['mkdir', '-p', '-m', '700', '/s'], ['mkdir', '-p', '-m', '700', '/s/sessions']])
})

test('a pre-existing dir keeps its mode: no mkdir, no chmod, even for a shared directory like $HOME', async () => {
  const f = fakeIo({ runs: a => (a[0] === 'test' ? { exitCode: 0, stdout: '' } : undefined) })
  await ensureStatusDirs(f.io, '/home/u')
  expect(f.calls.some(a => a[0] === 'mkdir' || a[0] === 'chmod' || String(a[2]).includes('chmod'))).toBe(false)
})

test('only the missing piece is created: existing status dir, new sessions subdir', async () => {
  const f = fakeIo({ runs: a => (a[0] === 'test' ? { exitCode: a[2] === '/s' ? 0 : 1, stdout: '' } : undefined) })
  await ensureStatusDirs(f.io, '/s')
  expect(f.calls.filter(a => a[0] === 'mkdir')).toEqual([['mkdir', '-p', '-m', '700', '/s/sessions']])
})
