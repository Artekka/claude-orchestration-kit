import { expect, test } from 'claude-code/testing'

import { nameShown } from '../lib/config'
import { flagReason, localFromOverlay, modeFromArgs, modeFromHook, projectColor, repoFromCommonDir } from '../lib/project'

test('permission mode from the claude command line', async () => {
  expect(modeFromArgs('claude --name Mars --permission-mode auto --model opus')).toBe('auto')
  expect(modeFromArgs('claude --name Mars --dangerously-skip-permissions')).toBe('bypass')
  expect(modeFromArgs('claude --permission-mode bypassPermissions')).toBe('bypass')
  expect(modeFromArgs('claude --permission-mode=acceptEdits')).toBe('acceptEdits')
  expect(modeFromArgs('claude --name Mars')).toBe('normal')
  // what a hook reports, in the chip's words
  expect(modeFromHook('default')).toBe('normal')
  expect(modeFromHook('bypassPermissions')).toBe('bypass')
  expect(modeFromHook('plan')).toBe('plan')
  expect(modeFromHook(undefined)).toBe('')
})

test('the project is the main checkout, also from inside a worktree', async () => {
  expect(repoFromCommonDir('/home/u/projects/My App/.git\n')).toBe('/home/u/projects/My App')
  expect(repoFromCommonDir('/home/u/projects/x/.git/worktrees/w1\n')).toBe('')
  expect(repoFromCommonDir('')).toBe('')
})

test('tab color: the recorded one first, else the team block, else none', async () => {
  const rec = '/p/a\t#16a085\n/p/b\t#d35400\n'
  expect(projectColor('/p/b', rec, '')).toBe('#d35400')
  expect(projectColor('/p/c', rec, 'team:\n  tab_color:        #27ae60\n')).toBe('#27ae60')
  expect(projectColor('/p/c', rec, 'team:\n  tab_color:        none\n')).toBe('')
  // The session's own tab color (CLAUDE_TAB_COLOR) wins over the project's, so the dot matches the tab it sits in.
  expect(projectColor('/p/b', rec, '', '#8e44ad')).toBe('#8e44ad')
  expect(projectColor('', '', '', '#8e44ad ')).toBe('#8e44ad')
  expect(projectColor('/p/b', rec, '', 'purple')).toBe('#d35400')
})

test('versions and test slots from ORCHESTRATION.md', async () => {
  const o = 'live_version:   v0.06\nnext_version:   v0.07   # set at release review\nteam:\n  gate_slots:       1\n'
  expect(localFromOverlay(o, 'auto')).toEqual({ mode: 'auto', live: 'v0.06', next: 'v0.07', slots: 1, kit: true })
  expect(localFromOverlay('next_version: <v1.2.3>\n', 'normal')).toEqual({ mode: 'normal', live: '', next: '', slots: 2, kit: true })
  expect(localFromOverlay('', 'normal').kit).toBe(false)
})

test('a stuck flag counts until the session makes progress after it', async () => {
  const f = JSON.stringify({ reason: 'no reply to ping (20 min)', at: 1000 })
  expect(flagReason(f, 500)).toBe('no reply to ping (20 min)')
  expect(flagReason(f, 1500)).toBe('')
  expect(flagReason('not json', 0)).toBe('')
  expect(flagReason(null, 0)).toBe('')
})

test('showForNames: exact names, or a prefix ending in *', async () => {
  expect(nameShown(['Atlas*'], 'Atlas-BS')).toBe(true)
  expect(nameShown(['Atlas*'], 'Mars')).toBe(false)
  expect(nameShown(['Orca'], 'Orca')).toBe(true)
  expect(nameShown(['Orca'], 'Orca2')).toBe(false)
  expect(nameShown([], 'anyone')).toBe(true)
})
