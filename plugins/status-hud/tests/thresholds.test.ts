import { expect, test } from 'claude-code/testing'

import { parseConfig } from '../lib/config'
import { commitLevel, crossedReport, fillLevel, flashPhase, isFlashing, loadLevel } from '../lib/thresholds'

const cfg = parseConfig({}, '/home/u')

test('context color: amber at the amber mark, red at the report mark (inclusive)', async () => {
  expect(fillLevel(299_999, cfg)).toBe('ok')
  expect(fillLevel(300_000, cfg)).toBe('amber')
  expect(fillLevel(349_999, cfg)).toBe('amber')
  expect(fillLevel(350_000, cfg)).toBe('red')
})

test('marks follow the configuration', async () => {
  const c = parseConfig({ contextAmberMark: 100_000, contextReportMark: 150_000 }, '/home/u')
  expect(fillLevel(99_999, c)).toBe('ok')
  expect(fillLevel(100_000, c)).toBe('amber')
  expect(fillLevel(150_000, c)).toBe('red')
})

test('flash fires only on the crossing update, never on first sight or while staying above', async () => {
  expect(crossedReport(undefined, 400_000, cfg)).toBe(false)
  expect(crossedReport(349_000, 351_000, cfg)).toBe(true)
  expect(crossedReport(350_000, 360_000, cfg)).toBe(false)
  expect(crossedReport(351_000, 100_000, cfg)).toBe(false)
  expect(crossedReport(100_000, 349_999, cfg)).toBe(false)
})

test('flash window and blink phase', async () => {
  expect(isFlashing(undefined, 1000)).toBe(false)
  expect(isFlashing(2000, 1999)).toBe(true)
  expect(isFlashing(2000, 2000)).toBe(false)
  expect(flashPhase(0)).toBe(true)
  expect(flashPhase(500)).toBe(false)
  expect(flashPhase(1000)).toBe(true)
})

test('windows commit warn levels: amber at 85, red at 95 by default, configurable', async () => {
  expect(commitLevel(84.9, cfg)).toBe('ok')
  expect(commitLevel(85, cfg)).toBe('amber')
  expect(commitLevel(94.9, cfg)).toBe('amber')
  expect(commitLevel(95, cfg)).toBe('red')
  const c = parseConfig({ commitWarnPct: 70, commitCritPct: 80 }, '/home/u')
  expect(commitLevel(70, c)).toBe('amber')
  expect(commitLevel(80, c)).toBe('red')
})

test('cpu level uses 90% of threads unless cpuRedLoad is set', async () => {
  expect(loadLevel(25.2, 28, cfg)).toBe('red')
  expect(loadLevel(21, 28, cfg)).toBe('amber')
  expect(loadLevel(5, 28, cfg)).toBe('ok')
  expect(loadLevel(10, 28, parseConfig({ cpuRedLoad: 10 }, '/h'))).toBe('red')
})

test('bad option values fall back to defaults instead of throwing', async () => {
  const c = parseConfig({ contextReportMark: -5, variant: 'nonsense', refreshSeconds: 0, mounts: ' /, /mnt/n ,' }, '/home/u')
  expect(c.reportMark).toBe(350_000)
  expect(c.variant).toBe('band')
  expect(c.refreshMs).toBe(1000)
  expect(c.mounts).toEqual(['/', '/mnt/n'])
  // Settings written by `plugin configure` before this option existed lack it: the default keeps the HUD on the seat only.
  expect(c.showForNames).toEqual(['Orca'])
  expect(parseConfig({ showForNames: ' Orca , Vali ,' }, '/home/u').showForNames).toEqual(['Orca', 'Vali'])
  expect(parseConfig({ showForNames: '' }, '/home/u').showForNames).toEqual([])
  expect(c.statusDir).toBe('/home/u/.claude-status-hud')
  expect(parseConfig({ statusDir: '~/x' }, '/home/u').statusDir).toBe('/home/u/x')
})
