import { expect, test } from 'claude-code/testing'

import { parseConfig } from '../lib/config'
import { canToggle, quietModeOn, toggleQuietMode } from '../lib/quietmode'
import { fakeIo } from './fakeio'

const withCmds = parseConfig({ quietModeOnCmd: 'bash g.sh on', quietModeOffCmd: 'bash g.sh off', quietModeFlagFile: '/f/quiet-mode' }, '/h')

test('the toggle asks for the opposite state and runs the configured command (mocked)', async () => {
  const f = fakeIo()
  const off = await toggleQuietMode(f.io, withCmds, false)
  expect(off).toEqual({ ran: true, wanted: true, ok: true })
  expect(f.calls[0]).toEqual(['sh', '-c', 'bash g.sh on'])
  const on = await toggleQuietMode(f.io, withCmds, true)
  expect(on.wanted).toBe(false)
  expect(f.calls[1]).toEqual(['sh', '-c', 'bash g.sh off'])
})

test('a failing command is reported, an unconfigured toggle runs nothing', async () => {
  const f = fakeIo({ runs: () => ({ exitCode: 2, stdout: '' }) })
  expect((await toggleQuietMode(f.io, withCmds, false)).ok).toBe(false)
  const bare = parseConfig({}, '/h')
  const g = fakeIo()
  expect(canToggle(bare)).toBe(false)
  expect(await toggleQuietMode(g.io, bare, false)).toEqual({ ran: false, wanted: true, ok: false })
  expect(g.calls.length).toBe(0)
})

test('state comes from the flag file, else the status command, else it is hidden (null)', async () => {
  const f = fakeIo()
  expect(await quietModeOn(f.io, withCmds, async p => p === '/f/quiet-mode')).toBe(true)
  expect(await quietModeOn(f.io, withCmds, async () => false)).toBe(false)
  const byCmd = parseConfig({ quietModeStatusCmd: 'test -f x' }, '/h')
  const g = fakeIo({ runs: () => ({ exitCode: 1, stdout: '' }) })
  expect(await quietModeOn(g.io, byCmd, async () => true)).toBe(false)
  expect(await quietModeOn(f.io, parseConfig({}, '/h'), async () => true)).toBe(null)
})

test('a ~ in the quiet-mode flag file means home (the kit default is ~/.orchestration-kit/runtime/quiet-mode)', () => {
  expect(parseConfig({ quietModeFlagFile: '~/.orchestration-kit/runtime/quiet-mode' }, '/h').quietFlagFile).toBe('/h/.orchestration-kit/runtime/quiet-mode')
  expect(parseConfig({ quietModeFlagFile: '/abs/q' }, '/h').quietFlagFile).toBe('/abs/q')
  expect(parseConfig({ quietModeFlagFile: '~x/q' }, '/h').quietFlagFile).toBe('~x/q')
})
