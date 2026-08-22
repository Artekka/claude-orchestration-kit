# Settings snippets — offered by bootstrap-project, APPROVAL-GATED

Both snippets edit the project's `.claude/settings.json` — user configuration. The
bootstrap OFFERS them as ONE approval step (they pair: the hook starts sessions right,
the compact setting keeps them coherent); it never applies them without a yes.

## 1. SessionStart hook — fresh sessions orient + check the banner

Skips resume/compact re-entries so only genuinely fresh sessions get the nudge.

```json
"hooks": {
  "SessionStart": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "in=$(cat); case \"$in\" in *'\"source\":\"resume\"'*|*'\"source\":\"compact\"'*) ;; *) printf '%s' '{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"Fresh session: run /orient before any other work. Then check the top of docs/orchestration/AGENT_BOARD.md for an ORCHESTRATOR ACTIVE banner - if one names another session as orchestrator, report availability to it instead of asking the human for work.\"}}';; esac",
          "timeout": 10
        }
      ]
    }
  ]
}
```

## 2. Auto-compact off — the no-/compact house flow

The CLAUDE-section carries the rule (never /compact mid-orchestration; context pressure →
retro-before-clear handshake). This setting makes the automatic side match:

```json
"autoCompact": false
```

> Verify the key name against the current Claude Code version before applying (`/config`
> lists it as "Auto-compact"); if it has moved, apply the equivalent toggle rather than a
> dead key.
