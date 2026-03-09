# Conductor Learnings

Orchestration patterns learned from experience. Review at startup and before heartbeat responses.

## How to Use This File

- **Log** a new entry when: you auto-respond and later learn it was wrong, you escalate and user says it was unnecessary, you discover a pattern in session behavior, or a recurring situation emerges.
- **Promote** entries to POLICY.md when they recur 3+ times and prove reliable.
- **Delete** entries that turn out to be wrong or no longer relevant.

## Entry Format

### [YYYYMMDD-NNN] Short description
- **Type**: auto_response_ok | auto_response_wrong | escalation_unnecessary | escalation_correct | pattern | session_behavior
- **Sessions**: which session(s) this involved
- **Context**: what happened
- **Lesson**: what to do differently (or keep doing)
- **Recurrence**: N (increment when seen again)
- **Status**: active | promoted | retired

---

### [20260304-001] Don't interact with sessions that have a review pane open
- **Type**: auto_response_wrong
- **Sessions**: MOVE-14
- **Context**: Session had opsx review pane open ("Done, review pane is open."). I auto-responded twice telling it to proceed. User clarified: an open review pane means the user is reviewing it. Do not send messages.
- **Lesson**: If a session's output mentions a review pane is open, the user is actively reviewing. Do NOT auto-respond, do NOT escalate, do NOT interact. Treat it like an idle session the user is handling.
- **Recurrence**: 1
- **Status**: promoted

### [20260227-001] Don't tell sessions to commit when they already pushed
- **Type**: auto_response_wrong
- **Sessions**: Protocol Initiative
- **Context**: Session output said "Pushed to feat/oncall-skill-and-domain-docs." I told it to run /commit then gh pr create, but it had already committed and pushed. Sent redundant/wrong instruction twice.
- **Lesson**: If output says "Pushed to X", code is already committed and pushed. Only send `gh pr create` if a PR is needed, not /commit.
- **Recurrence**: 2
- **Status**: active
