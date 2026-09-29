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
    ... --window 200000                            # state the window (from your env block)

Marks: self-report at the PROMPT mark, hand the terminal over by the HANDOVER mark.
    window >= ~500K (default assumption: 1M) -> 350,000 / 400,000 (absolute)
    smaller window (e.g. 200K)               -> 70% / 80% of the window
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
TOO_LONG = "Prompt is too long"


def slug(path):
    """Claude Code's project-dir name for a working directory."""
    return re.sub(r"[^A-Za-z0-9]", "-", path)


def project_dir():
    return os.path.join(PROJECTS, slug(os.getcwd()))


def marks(window):
    if window is None:
        return ABS_PROMPT, ABS_HANDOVER
    return min(ABS_PROMPT, int(window * 0.70)), min(ABS_HANDOVER, int(window * 0.80))


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


def report(path, window):
    uuid = os.path.basename(path)[:-6]
    model, peak, final, turns, too_long, wall_at, recovered = measure(path)
    if not turns:
        print(f"{uuid}  (no assistant turns with usage yet)")
        return
    prompt_mark, handover_mark = marks(window)

    if window:
        window_note = f"{window:,} (as STATED by you -- from your env block, not the transcript)"
    elif peak > SMALL_WINDOW:
        window_note = f"at least {peak:,} (PROVEN: this session reached it)"
    else:
        window_note = (f"UNKNOWN -- not knowable from a transcript. Read your OWN env block; "
                       f"if it is {SMALL_WINDOW:,}, re-run with --window {SMALL_WINDOW}.")

    # A session that already hit its wall must never read "OK" because it sits under a mark
    # calibrated for a larger window.
    if too_long and not recovered:
        verdict = f"!! WALL ALREADY HIT at {peak:,} -- this session is dead, not 'approaching' anything"
    elif too_long:
        verdict = f"~  RECOVERED from a wall at {wall_at:,}; judge it on `current`"
    elif final >= handover_mark:
        verdict = "!! PAST HANDOVER -- retro now, then recycle (an in-flight row may finish first)"
    elif final >= prompt_mark:
        verdict = "!  AT PROMPT MARK -- self-report to the seat (or the human, if no seat)"
    elif window is None and peak <= SMALL_WINDOW and final >= 0.6 * SMALL_WINDOW:
        verdict = (f"?  {final / SMALL_WINDOW * 100:.0f}% full IF this is a {SMALL_WINDOW:,} window -- "
                   f"check your env block now")
    else:
        verdict = f"OK -- {prompt_mark - final:,} to the prompt mark"

    print(f"session   {uuid}")
    print(f"model     {model}   (NOT a window indicator)")
    print(f"window    {window_note}")
    print(f"current   {final:,}")
    print(f"peak      {peak:,}   over {turns} assistant turns")
    print(f"marks     prompt {prompt_mark:,} | handover {handover_mark:,}")
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
    if "--window" in argv:
        i = argv.index("--window")
        try:
            window = int(argv[i + 1].replace("_", "").replace(",", ""))
        except (IndexError, ValueError):
            sys.exit("--window needs a token count, e.g. --window 200000")
        del argv[i:i + 2]
    window = window or (int(os.environ["CTX_WINDOW"]) if os.environ.get("CTX_WINDOW", "").isdigit() else None)

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
