#!/usr/bin/env python3
"""Report a Claude Code session's REAL context fill (orchestration-kit).

The only honest number is the `usage` block the API returns on each assistant turn:
    input_tokens + cache_read_input_tokens + cache_creation_input_tokens
That is the prompt size the model actually saw. Everything else is a guess -- and the
popular guess, `bytes / 4` of the session jsonl, over-reports by roughly 30-60% with a bias
that is not stable, so no threshold expressed against it is safe.

What this CANNOT tell you: the session's context WINDOW. The transcript's `model` field does
not carry it (a 1M-window variant and a 200K-window variant can record the same model string).
The only authoritative source is the session's OWN system-prompt environment block. What the
transcript CAN prove is a lower bound: a session that reached N tokens has a window >= N.

Usage:
    python3 scripts/ctx-fill.py                    # this session (from $CLAUDE_CODE_SESSION_ID)
    python3 scripts/ctx-fill.py <session-uuid>     # a specific session
    python3 scripts/ctx-fill.py <path/to/x.jsonl>  # a specific transcript file
    python3 scripts/ctx-fill.py --all              # every session of this project, newest first
    ... --window 1m|200k|<tokens>                  # state the window (from YOUR env block)

Marks: self-report at the PROMPT mark, hand the terminal over by the HANDOVER mark.
    1M window (>= 500K)       -> 350,000 / 400,000 (absolute)
    200K window (every Haiku) -> 120,000 / 150,000 (60% / 75% of the window)
    anything in between       -> 60% / 75% of the window, capped at the 1M marks
Why the small window is not 70% / 80%: a seat on a ~200K window died at 175,725 tokens with no
handover, so a 160K handover leaves too little margin for the retro itself.

Which window? Never the transcript's model string for Opus or Sonnet: both come in 200K and 1M and
record the same string. The one safe model rule only ever LOWERS the window: Haiku has no 1M
variant, so a `haiku` model string means 200K. --window (what your env block says) beats everything;
with none of those the window is UNKNOWN and BOTH sets of marks are printed.
Transcripts live at ~/.claude/projects/<slug>/<uuid>.jsonl, where <slug> is the session's
working directory with every non-alphanumeric character replaced by '-'.
"""
import glob
import json
import os
import re
import sys

CLAUDE_HOME = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
PROJECTS = os.path.join(CLAUDE_HOME, "projects")
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

ABS_PROMPT, ABS_HANDOVER = 350_000, 400_000
SMALL_WINDOW = 200_000
LARGE_WINDOW = 1_000_000
LARGE_FROM = 500_000   # a window at or above this uses the absolute marks
PROMPT_PCT, HANDOVER_PCT = 0.60, 0.75   # of a smaller window: 200K -> 120K / 150K
WINDOW_ALIASES = {"1m": LARGE_WINDOW, "200k": SMALL_WINDOW}
TOO_LONG = "Prompt is too long"


def slug(path):
    """Claude Code's project-dir name for a working directory."""
    return re.sub(r"[^A-Za-z0-9]", "-", path)


def project_dir():
    return os.path.join(PROJECTS, slug(os.getcwd()))


def marks(window):
    """(prompt, handover) for a window in tokens. Unknown is handled by the caller (both sets)."""
    if window is None or window >= LARGE_FROM:
        return ABS_PROMPT, ABS_HANDOVER
    return min(ABS_PROMPT, int(window * PROMPT_PCT)), min(ABS_HANDOVER, int(window * HANDOVER_PCT))


def parse_window(text):
    """`1m`, `200k`, `200000`, `200,000`, `200_000` -> tokens; anything else -> None."""
    t = text.strip().lower().replace("_", "").replace(",", "")
    if t in WINDOW_ALIASES:
        return WINDOW_ALIASES[t]
    return int(t) if t.isdigit() and int(t) > 0 else None


def resolve_window(model, peak, stated):
    """(window or None, how it was known). Evidence, not a lookup table: see the module docstring."""
    if stated:
        return stated, "STATED by you with --window (from your env block, not the transcript)"
    if peak > SMALL_WINDOW:
        return LARGE_WINDOW, f"PROVEN: this session already reached {peak:,}"
    if model and "haiku" in model.lower():
        return SMALL_WINDOW, "model is Haiku, which has only a 200K window"
    return None, "UNKNOWN"


def find(uuid):
    """The cwd's project dir first; then any project (a worktree session has its own slug)."""
    here = os.path.join(project_dir(), uuid + ".jsonl")
    if os.path.exists(here):
        return here
    hits = glob.glob(os.path.join(PROJECTS, "*", uuid + ".jsonl"))
    return hits[0] if len(hits) == 1 else (None if not hits else sys.exit(
        "uuid found in several project dirs -- pass the .jsonl path:\n  " + "\n  ".join(hits)))


def measure(path):
    """Return (model, peak, final, turns, too_long, wall_at, recovered)."""
    model, peak, final, turns = None, 0, 0, 0
    too_long, wall_at, recovered = 0, 0, False
    with open(path) as fh:
        for line in fh:
            try:
                o = json.loads(line)
            except (ValueError, TypeError):
                continue
            if o.get("type") != "assistant":
                continue
            msg = o.get("message") or {}
            content = msg.get("content")
            if isinstance(content, list) and any(
                isinstance(b, dict) and b.get("type") == "text" and TOO_LONG in b.get("text", "")
                for b in content
            ):
                too_long += 1
                wall_at, recovered = peak, False
            u = msg.get("usage") or {}
            ctx = (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
                   + u.get("cache_creation_input_tokens", 0))
            if ctx:
                model = msg.get("model") or model
                peak, final, turns = max(peak, ctx), ctx, turns + 1
                if too_long:
                    recovered = True
    return model, peak, final, turns, too_long, wall_at, recovered


def report(path, stated):
    uuid = os.path.basename(path)[:-6]
    model, peak, final, turns, too_long, wall_at, recovered = measure(path)
    if not turns:
        print(f"{uuid}  (no assistant turns with usage yet)")
        return
    window, how = resolve_window(model, peak, stated)
    small_prompt, small_handover = marks(SMALL_WINDOW)
    if window is not None:
        prompt_mark, handover_mark = marks(window)
        window_note = f"{window:,}  ({how})"
        marks_lines = [f"marks     prompt {prompt_mark:,} | handover {handover_mark:,}  ({window:,} window)"]
    else:
        prompt_mark = handover_mark = None
        window_note = (f"UNKNOWN -- not knowable from a transcript: {model} comes in both sizes. Read your OWN env "
                       f"block and re-run with --window 1m or --window 200k.")
        marks_lines = [f"marks     IF 1M:   prompt {ABS_PROMPT:,} | handover {ABS_HANDOVER:,}",
                       f"marks     IF 200K: prompt {small_prompt:,} | handover {small_handover:,}"]

    # A session that already hit its wall must never read "OK" because it sits under a mark
    # calibrated for a larger window.
    if too_long and not recovered:
        verdict = f"!! WALL ALREADY HIT at {peak:,} -- this session is dead, not 'approaching' anything"
    elif too_long:
        verdict = f"~  RECOVERED from a wall at {wall_at:,}; judge it on `current`"
    elif window is None and final >= small_handover:
        verdict = f"?  PAST the 200K handover mark ({small_handover:,}) IF this is a 200K window -- read your env block NOW"
    elif window is None and final >= small_prompt:
        verdict = f"?  AT the 200K prompt mark ({small_prompt:,}) IF this is a 200K window -- read your env block NOW"
    elif window is None:
        verdict = f"OK on either window -- {small_prompt - final:,} to the 200K prompt mark"
    elif final >= handover_mark:
        verdict = "!! PAST HANDOVER -- retro now, then recycle (an in-flight row may finish first)"
    elif final >= prompt_mark:
        verdict = "!  AT PROMPT MARK -- self-report to the seat (or the human, if no seat)"
    else:
        verdict = f"OK -- {prompt_mark - final:,} to the prompt mark"

    print(f"session   {uuid}")
    print(f"model     {model}   (names the window only for Haiku)")
    print(f"window    {window_note}")
    print(f"current   {final:,}")
    print(f"peak      {peak:,}   over {turns} assistant turns")
    for line in marks_lines:
        print(line)
    print(f"verdict   {verdict}")


def detect():
    """This session's transcript from an authoritative source -- or refuse. Never guess
    (e.g. "most recently modified jsonl"): measuring the wrong object is not measuring."""
    sid = os.environ.get("CLAUDE_CODE_SESSION_ID", "")
    if UUID_RE.match(sid):
        path = find(sid)
        if path:
            return path, "CLAUDE_CODE_SESSION_ID"
    sys.exit(
        "REFUSING TO GUESS: no authoritative session id in the environment.\n"
        "Pass it explicitly:  python3 scripts/ctx-fill.py <uuid>\n"
        "Your uuid is the path segment after the project slug in your scratchpad directory\n"
        "(named in your own system prompt), or run /status in the session."
    )


def main():
    argv = sys.argv[1:]
    window = None
    for i, a in enumerate(argv):
        if a == "--window" or a.startswith("--window="):
            val = a.split("=", 1)[1] if "=" in a else (argv[i + 1] if i + 1 < len(argv) else "")
            window = parse_window(val)
            if window is None:
                sys.exit(f"--window must be 1m, 200k or a token count (e.g. 200000); got '{val}'")
            del argv[i:i + (1 if "=" in a else 2)]
            break
    if window is None and os.environ.get("CTX_WINDOW"):
        window = parse_window(os.environ["CTX_WINDOW"])

    if "--all" in argv:
        paths = sorted(glob.glob(os.path.join(project_dir(), "*.jsonl")), key=os.path.getmtime, reverse=True)
        if not paths:
            sys.exit(f"no transcripts under {project_dir()}")
        for p in paths:
            report(p, window)
            print()
        return
    if argv:
        arg = argv[0]
        path = arg if arg.endswith(".jsonl") else find(arg)
    else:
        path, via = detect()
        print(f"(identified from {via})")
    if not path or not os.path.exists(path):
        sys.exit(f"No such session transcript: {argv[0] if argv else '?'} (looked under {PROJECTS})")
    report(path, window)


if __name__ == "__main__":
    main()
