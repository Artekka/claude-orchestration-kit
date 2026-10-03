# Keep CLAUDE.md slim

`CLAUDE.md` is loaded in full at the start of EVERY session and then re-read as part of the prompt
on every turn. Its size is the **startup floor**: every byte is paid again by every session, every
turn, for the life of the project. A 40 KB `CLAUDE.md` is roughly 10K tokens a session before anyone
has read a board or opened a file; across a seat and three siblings over a working day that is a
large, silent tax, and it crowds out the context the work needs.

## The rule

- **Rules go in `CLAUDE.md`. Narrative goes in a linked archive.** A rule is something a session
  must obey to avoid a known failure; the story of the incident that taught it is not.
- Keep, per rule: the imperative, the exact command or flag, the guard (what it prevents), and at
  most one line of "why". Cut the war story.
- Put the cut text, verbatim and dated, in an archive (`docs/rules/CLAUDE_FULL_<YYYY-MM-DD>.md` is a
  good name) and link it from the top of `CLAUDE.md`: "Read it when a rule's reason matters to a
  decision. Never read it just to orient."
- **Compress rationale, never the rule itself.** Do not drop a command, a flag, a guard or a
  pass/fail assertion to save bytes: a rule that lost its `--no-file-parallelism` is a regression.
- Prefer a table to a paragraph; a short "start here" list to a long preamble.

## How to trim an existing file

1. Copy the current `CLAUDE.md` verbatim to the dated archive and commit it first (so nothing is lost).
2. Rewrite `CLAUDE.md` rule by rule: keep the imperative + command + guard, move the story out.
3. Add the archive link under the title.
4. Diff the two: every command, flag and number in the old file must appear in the new one or in
   the archive. Run your own `wc -c` before and after; a trim worth doing is usually 2–3x.

## Same idea, other always-loaded files

Skills load fully each time they are invoked; the memory index loads every session. The same split
applies: terse schema in the loaded file, history in a file you read on demand.
