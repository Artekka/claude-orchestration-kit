import type { Io } from './io'

/**
 * Creates the status dir and its sessions/ subdir owner-only, but changes the mode of a directory ONLY when this
 * call created it: a user may point statusDir at a shared directory (even $HOME) and its permissions are theirs.
 */
export async function ensureStatusDirs(io: Io, dir: string): Promise<void> {
  for (const d of [dir, `${dir}/sessions`]) {
    const exists = (await io.run(['test', '-d', d])).exitCode === 0
    if (exists) continue
    // mkdir -m sets the mode at creation, so no window where it is world-readable.
    await io.run(['mkdir', '-p', '-m', '700', d])
  }
}
