# Conductor: Shared Knowledge Base

This file contains shared infrastructure knowledge (CLI reference, protocols, formats) for all conductor sessions.
Each conductor has its own identity in its subdirectory and its own policy in POLICY.md.

## Agent-Deck CLI Reference

### Status & Listing
| Command | Description |
|---------|-------------|
| `agent-deck -p <PROFILE> status --json` | Get counts: `{"waiting": N, "running": N, "idle": N, "error": N, "total": N}` |
| `agent-deck -p <PROFILE> list --json` | List all sessions with details (id, title, path, tool, status, group) |
| `agent-deck -p <PROFILE> session show --json <id_or_title>` | Full details for one session |

### Reading Session Output
| Command | Description |
|---------|-------------|
| `agent-deck -p <PROFILE> session output <id_or_title> -q` | Get the last response (raw text, perfect for reading) |

### Sending Messages to Sessions
| Command | Description |
|---------|-------------|
| `agent-deck -p <PROFILE> session send <id_or_title> "message"` | Send a message. Has built-in 60s wait for agent readiness. |
| `agent-deck -p <PROFILE> session send <id_or_title> "message" --wait -q --timeout 300s` | Single-call send + wait + raw output (preferred when you need the reply now). |
| `agent-deck -p <PROFILE> session send <id_or_title> "message" --no-wait` | Send immediately without waiting for ready state. |

### Session Control
| Command | Description |
|---------|-------------|
| `agent-deck -p <PROFILE> session start <id_or_title>` | Start a stopped session |
| `agent-deck -p <PROFILE> session stop <id_or_title>` | Stop a running session |
| `agent-deck -p <PROFILE> session restart <id_or_title>` | Restart (reloads MCPs for Claude) |
| `agent-deck -p <PROFILE> add <path> -t "Title" -c claude -g "group"` | Create new Claude session |
| `agent-deck -p <PROFILE> launch <path> -t "Title" -c claude -g "group" -m "prompt"` | Create + start + send initial prompt in one command (preferred for new task sessions) |
| `agent-deck -p <PROFILE> add <path> -t "Title" -c claude --worktree feature/branch -b` | Create session with new worktree |

### Session Resolution
Commands accept: **exact title**, **ID prefix** (e.g., first 4 chars), **path**, or **fuzzy match**.

## Session Status Values

| Status | Meaning | Your Action |
|--------|---------|-------------|
| `running` (green) | Claude is actively processing | Do nothing. Wait. |
| `waiting` (yellow) | Claude finished, needs input | Read output, decide: auto-respond or escalate |
| `idle` (gray) | Waiting, but user acknowledged | User knows about it. Skip unless asked. |
| `error` (red) | Session crashed or missing | Try `session restart`. If that fails, escalate. |

## Heartbeat Protocol

**Scope**: Only check sessions relevant to your role. Epic conductors should only monitor child sessions tracked in `state.json`, not all sessions in the profile. General-purpose conductors may scan all sessions.

Every N minutes, the bridge sends you a message like:

```
[HEARTBEAT] [<name>] Status: 2 waiting, 3 running, 1 idle, 0 error. Waiting sessions: frontend (project: ~/src/app), api-fix (project: ~/src/api). Check if any need auto-response or user attention.
```

**Your heartbeat response format:**

```
[STATUS] All clear.
```

or:

```
[STATUS] Auto-responded to 1 session. 1 needs your attention.

AUTO: frontend - told it to use the existing auth middleware
NEED: api-fix - asking whether to run integration tests against staging or prod
```

The bridge parses your response: if it contains `NEED:` lines, those get sent to the user via Telegram and/or Slack.

## State Management

Maintain `./state.json` for persistent context across compactions:

```json
{
  "sessions": {
    "session-id-here": {
      "title": "frontend",
      "project": "~/src/app",
      "summary": "Building auth flow with React Router v7",
      "last_auto_response": "2025-01-15T10:30:00Z",
      "escalated": false
    }
  },
  "last_heartbeat": "2025-01-15T10:30:00Z",
  "auto_responses_today": 5,
  "escalations_today": 2
}
```

Read state.json at the start of each interaction. Update it after taking action. Keep session summaries current based on what you observe in their output.

## Task Log

Append every action to `./task-log.md`:

```markdown
## 2025-01-15 10:30 - Heartbeat
- Scanned 5 sessions (2 waiting, 3 running)
- Auto-responded to frontend: "Use the existing AuthProvider component"
- Escalated api-fix: needs decision on test environment

## 2025-01-15 10:15 - User Message
- User asked: "What's the status of the api server?"
- Checked session 'api-server': running, working on endpoint validation
- Responded with summary
```

## Self-Improvement

Maintain `LEARNINGS.md` to track orchestration patterns. Two tiers exist:
- `../LEARNINGS.md` (shared): patterns that work across all conductors
- `./LEARNINGS.md` (per-conductor): patterns specific to your profile and sessions

### When to Log

| Situation | Entry Type |
|-----------|-----------|
| You auto-responded and user later said it was wrong | `auto_response_wrong` |
| You auto-responded and it worked well | `auto_response_ok` |
| You escalated but user said it was fine to auto-respond | `escalation_unnecessary` |
| You escalated and user confirmed it needed attention | `escalation_correct` |
| You notice a recurring session behavior | `session_behavior` |
| You discover a useful pattern | `pattern` |

### Promotion to Policy

When an entry reaches Recurrence 3+ and has proven reliable, promote it:
1. Distill into a concise rule
2. Add to `./POLICY.md` (create if needed) or request update to `../POLICY.md` (shared)
3. Set entry Status to `promoted`

### At Startup

Read both `./LEARNINGS.md` and `../LEARNINGS.md` before responding. Past patterns inform current decisions.

## Quick Commands

The bridge may forward these special commands from Telegram or Slack:

| Command | What to Do |
|---------|------------|
| `/status` | Run `agent-deck -p <PROFILE> status --json` and format a brief summary |
| `/sessions` | Run `agent-deck -p <PROFILE> list --json` and list active sessions with status |
| `/check <name>` | Run `agent-deck -p <PROFILE> session output <name> -q` and summarize what it's doing |
| `/send <name> <msg>` | Forward the message to that session via `agent-deck -p <PROFILE> session send` |
| `/help` | List available commands |

For any other text, treat it as a conversational message from the user. They might ask about session progress, give instructions for specific sessions, or ask you to create/manage sessions.

## Important Notes

- This project is `asheshgoplani/agent-deck` on GitHub. When referencing GitHub issues or PRs, always use owner `asheshgoplani` and repo `agent-deck`. Never use `anthropics` as the owner.
- You cannot directly access other sessions' files. Use `session output` to read their latest response.
- Prefer `launch ... -m "prompt"` over separate `add` + `session start` + `session send` when creating a new task session.
- Keep parent linkage for event routing; if you need a specific group, pass `-g <group>` explicitly (it overrides inherited parent group).
- Transition notifications are parent-linked. If `parent_session_id` is empty or points elsewhere, this conductor will not receive child completion events.
- `session send` waits up to ~80 seconds for the agent to be ready. If the session is running (busy), the send will wait.
- For periodic nudges/heartbeats where blocking is harmful, prefer `session send --no-wait -q`.
- The bridge sends with `session send --wait -q` and waits in a single CLI call. Reply promptly.
- Your own session can be restarted by the bridge if it detects you're in an error state.
- Keep state.json small (no large output dumps). Store summaries, not full text.
