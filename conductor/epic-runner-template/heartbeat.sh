#!/bin/bash
# Heartbeat for conductor: epic-runner-template (profile: epic-runner-template)
# Sends a check-in message to the conductor session (non-blocking)

SESSION="conductor-epic-runner-template"
PROFILE="epic-runner-template"

# Only send if the session is running
STATUS=$(agent-deck -p "$PROFILE" session show "$SESSION" --json 2>/dev/null | tr -d '\n' | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

if [ "$STATUS" = "idle" ] || [ "$STATUS" = "waiting" ]; then
    agent-deck -p "$PROFILE" session send "$SESSION" "Heartbeat: Check all sessions in the epic-runner-template profile. List any waiting sessions, auto-respond where safe, and report what needs my attention." --no-wait -q
fi
