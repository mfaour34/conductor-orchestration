# Conductor: Multi-Agent Orchestration for Claude Code

A system for orchestrating multiple Claude Code sessions using [agent-deck](https://github.com/asheshgoplani/agent-deck). A "conductor" is a Claude Code session that manages other sessions: monitoring their status, auto-responding to simple questions, escalating important decisions, and (for epics) driving a DAG of tickets from spec to merge.

## Architecture

```
                    ┌─────────────────────┐
                    │   Slack/Telegram     │
                    │   (user on phone)    │
                    └──────────┬──────────┘
                               │ bridge
                    ┌──────────▼──────────┐
                    │     Conductor       │
                    │  (Claude session)   │
                    │                     │
                    │  - reads state.json │
                    │  - heartbeat loop   │
                    │  - auto-responds    │
                    │  - escalates        │
                    └──┬─────┬─────┬─────┘
                       │     │     │  agent-deck session send/output
                 ┌─────▼─┐ ┌▼────┐ ┌▼─────┐
                 │Session │ │Sess.│ │Sess. │
                 │  #1    │ │ #2  │ │ #3   │
                 └────────┘ └─────┘ └──────┘
```

## Two Conductor Types

### 1. Work Conductor (general-purpose monitor)

Watches all sessions in a profile. Reports changes, auto-responds to safe questions, escalates dangerous ones. Think of it as a supervisor that keeps your sessions moving while you're away.

**Use case**: You have 5-10 Claude Code sessions working on different tasks. The work conductor monitors them, answers simple "Should I proceed?" questions, and pings you on Slack when a session needs a real decision.

### 2. Epic Runner (DAG-driven orchestrator)

Drives an entire epic (set of dependent Jira tickets) from start to finish. Manages a dependency DAG, spawns child agents for tickets, monitors PRs, auto-merges when approved, and unblocks downstream tickets.

**Use case**: You have an epic with 15 tickets and complex dependencies. The epic runner spawns agents for tickets whose dependencies are met, tells them to create specs, notifies you when specs need review, monitors PRs, and auto-merges approved ones.

## Prerequisites

- [agent-deck](https://github.com/asheshgoplani/agent-deck) (`brew install asheshgoplani/tap/agent-deck`)
- Claude Code CLI (`claude`)
- GitHub CLI (`gh`) for PR monitoring (epic runner)

## Setup

### 1. Create the conductor directory

```bash
agent-deck conductor setup work --description "Monitors all sessions"
```

This creates `~/.agent-deck/conductor/work/` with a tmux session.

### 2. Place the configuration files

Copy these files into the conductor directory (`~/.agent-deck/conductor/<name>/`):

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Identity and startup instructions for the conductor |
| `POLICY.md` | Auto-response rules, escalation guidelines, reporting style |
| `LEARNINGS.md` | Self-improvement log (the conductor learns from mistakes) |
| `heartbeat.sh` | Periodic check-in script (runs via launchd or cron) |
| `state.json` | Persistent state across context compactions |
| `task-log.md` | Append-only action log |

The shared `CLAUDE.md` goes in the parent `~/.agent-deck/conductor/CLAUDE.md` and contains the CLI reference, protocols, and formats used by all conductors.

### 3. Set up the heartbeat

The heartbeat script sends periodic check-in messages to the conductor session. Set it up with launchd (macOS) or cron:

```xml
<!-- ~/Library/LaunchAgents/com.example.conductor-heartbeat.plist -->
<plist version="1.0">
<dict>
    <key>Label</key><string>com.example.conductor-heartbeat</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/heartbeat.sh</string>
    </array>
    <key>StartInterval</key><integer>300</integer>
</dict>
</plist>
```

### 4. (Optional) Set up Slack notifications

The conductor posts updates to Slack via a bot token. Set `SLACK_BRAIZIO_TOKEN` (or your own bot token env var) and update `POLICY.md` with your Slack user ID for DM delivery.

## Epic Runner: DAG Management

The epic runner uses `epic-dag`, a Python script that owns all mutations to `state.json`. The conductor reads state for information but always writes through `epic-dag`.

### Ticket Lifecycle

```
pending -> speccing -> awaiting_user -> in_progress -> pr_open -> done
                                                                   ^
                         (any state) ---- skipped -----------------┘
```

### epic-dag Commands

```bash
# What tickets are ready to work on? (deps resolved, under concurrency cap)
epic-dag next <conductor-dir>

# Move a ticket to a new state
epic-dag transition <conductor-dir> <TICKET-ID> <state>

# Set metadata on a ticket (child_session, pr_number, branch, worktree_path, merge_blocked)
epic-dag set <conductor-dir> <TICKET-ID> <field> <value>

# Skip a ticket (treated as resolved for dependency purposes)
epic-dag skip <conductor-dir> <TICKET-ID>

# Check if epic is complete (exit 0 if all done/skipped)
epic-dag complete <conductor-dir>

# Print human-readable or JSON status
epic-dag status <conductor-dir> [--json]
```

### State Format (state.json)

```json
{
  "epic_id": "PROJ-42",
  "epic_title": "Payment Refactor",
  "concurrency_cap": 3,
  "paused": false,
  "tickets": {
    "PROJ-100": {
      "title": "Create payment gateway adapter",
      "project_key": "PROJ",
      "repo_path": "/path/to/repo",
      "state": "pending",
      "depends_on": [],
      "blocks": ["PROJ-101", "PROJ-102"],
      "child_session": null,
      "pr_number": null,
      "branch": null,
      "worktree_path": null,
      "merge_blocked": false
    }
  }
}
```

### How the Epic Runner Spawns Agents

When `epic-dag next` returns a ticket:

```bash
# 1. Transition to speccing
epic-dag transition . PROJ-100 speccing

# 2. Launch a child Claude session with a git worktree
agent-deck launch /path/to/repo -w "feat/PROJ-100-payment-gateway" -b \
  -t "PROJ-100 Create payment gateway adapter" -c claude -g "epic-PROJ-42" \
  -m "Work on PROJ-100: Create payment gateway adapter. Start with /opsx:new then /opsx:ff."

# 3. Record session metadata
epic-dag set . PROJ-100 child_session <session-id>
epic-dag set . PROJ-100 branch feat/PROJ-100-payment-gateway
```

### User Commands (via Slack/Telegram bridge)

| Command | Action |
|---------|--------|
| `PROJ-100 approved` | Transition from awaiting_user to in_progress |
| `skip PROJ-100` | Skip the ticket |
| `hold PROJ-100` | Block auto-merge |
| `pause` / `resume` | Stop/resume spawning new tickets |
| `status` | Post DAG summary |
| `PROJ-100: <instruction>` | Forward instruction to child session |

## Self-Improvement System

Conductors maintain a `LEARNINGS.md` file where they log orchestration patterns:

- **auto_response_wrong**: Auto-responded and it was the wrong call
- **auto_response_ok**: Auto-responded correctly
- **escalation_unnecessary**: Escalated but user said it was fine
- **pattern**: Discovered a useful pattern

When an entry reaches 3+ recurrences and proves reliable, the conductor promotes it to `POLICY.md` as a permanent rule. This creates a feedback loop where the conductor gets better over time.

## PR Monitoring & CI Integration

The conductor ecosystem includes scripts for monitoring PRs and CI across all sessions.

### pr-poller

Runs every 120s via launchd. For each agent-deck session on a feature branch:

1. Queries GitHub GraphQL API for PR status (draft, open, in review, approved, merged, etc.)
2. Checks CI rollup state, merge conflicts, and unresolved review threads
3. Writes a JSON cache file per session (used by the statusline for rendering)
4. **Auto-injects CI failure context** into idle Claude sessions, so agents fix their own CI without you having to tell them
5. Updates agent-deck session titles with status emoji prefixes (e.g., `[✅ #1234] My Feature`)

Example session titles:
- `[🆕 #1234] Add payment gateway` (PR open, no reviews)
- `[✅ #1234 🔥] Add payment gateway` (approved but CI failing)
- `[🔍 #1234 💬2] Add payment gateway` (in review, 2 unresolved threads)
- `[🚧] Add payment gateway` (no PR yet)

### ci-failures

Utility script that fetches CI failure details for a branch:

```bash
ci-failures [branch] [repo-path]
# Output: "Failed: lint, test-integration\nRun: https://github.com/..."
```

Used by `pr-poller` to generate failure context that gets injected into sessions.

### Setup

Add the PR poller as a launchd agent:

```xml
<!-- ~/Library/LaunchAgents/com.example.pr-poller.plist -->
<plist version="1.0">
<dict>
    <key>Label</key><string>com.example.pr-poller</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/tools/pr-poller</string>
    </array>
    <key>StartInterval</key><integer>120</integer>
    <key>StandardOutPath</key><string>/tmp/pr-poller.log</string>
    <key>StandardErrorPath</key><string>/tmp/pr-poller.log</string>
</dict>
</plist>
```

## File Reference

```
~/.agent-deck/conductor/
├── CLAUDE.md                    # Shared CLI reference & protocols
├── LEARNINGS.md                 # Shared learnings across all conductors
├── work/                        # Work conductor
│   ├── CLAUDE.md                # Identity & startup
│   ├── POLICY.md                # Auto-response & escalation rules
│   ├── LEARNINGS.md             # Work-specific learnings
│   ├── heartbeat.sh             # Periodic check-in
│   ├── state.json               # Persistent state
│   └── task-log.md              # Action log
└── epic-<name>/                 # Epic runner conductor
    ├── CLAUDE.md                # Epic runner identity & lifecycle
    ├── POLICY.md                # Epic-specific rules
    ├── LEARNINGS.md             # Epic-specific learnings
    ├── heartbeat.sh             # Periodic check-in
    ├── state.json               # DAG state (tickets, deps, states)
    └── task-log.md              # Action log

~/tools/
├── epic-dag                     # DAG mutation script (Python)
├── pr-poller                    # GitHub PR/CI poller (runs via launchd)
└── ci-failures                  # CI failure summary fetcher

```
