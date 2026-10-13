import { expect, mock, test } from 'claude-code/testing'

// The module under test is loaded from this folder by the engine; hooks registered here sit beneath it and stand for the engine.
test('/hud pane opens the pane, /hud off closes it, /hud band closes it too, and the choice is stored', async ($, on) => {
  const stored: Record<string, unknown> = {}
  on('store.get', async (_$, e) => ({ value: stored[e.key] }))
  on('store.set', async (_$, e) => {
    stored[e.key] = e.value
    return { value: undefined }
  })
  mock.env(on, { HOME: '/home/u' })
  const opened: string[] = []
  const closed: string[] = []
  on('ui.open', async (_$, e) => {
    opened.push(e.id)
    return { value: { isPlaced: true } }
  })
  on('ui.close', async (_$, e) => {
    closed.push(e.id)
    return { value: undefined }
  })
  const r = await $.command.run({ command: 'hud', args: 'pane' } as never)
  expect(r.text).toContain('pane')
  expect(opened).toEqual(['status-hud'])
  expect(stored.variant).toBe('pane')
  const off = await $.command.run({ command: 'hud', args: 'off' } as never)
  expect(off.text).toContain('off')
  expect(closed).toEqual(['status-hud'])
  expect(stored.variant).toBe('off')
  await $.command.run({ command: 'hud', args: 'band' } as never)
  expect(closed.length).toBe(2)
  expect(stored.variant).toBe('band')
})

test('/hud quiet without both commands configured says what is missing and runs nothing', async ($, on) => {
  mock.store(on)
  mock.env(on, { HOME: '/home/u' })
  const ran: string[][] = []
  on('process.run', async (_$, e) => {
    ran.push([...e.argv])
    return { value: { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  const r = await $.command.run({ command: 'hud', args: 'quiet' } as never)
  expect(r.text).toContain('starting')
  expect(ran.length).toBe(0)
})
