#!/bin/bash
# Heartbeat for conductor: work (profile: default)
# Sends a check-in message to the conductor session (non-blocking)

SESSION="conductor-work"
PROFILE="default"

# Only send if the session is running
STATUS=$(agent-deck session show "$SESSION" --json 2>/dev/null | tr -d '\n' | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

if [ "$STATUS" = "idle" ] || [ "$STATUS" = "waiting" ]; then
    agent-deck session send "$SESSION" "Heartbeat: Check all sessions in the default profile. List any waiting sessions, auto-respond where safe, and report what needs my attention." --no-wait -q
fi
