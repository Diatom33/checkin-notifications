---
name: checkin-notifications
description: Send persistent, snoozeable notifications via ntfy.sh for checking in later with the user. One such workflow using this is for accountability check-ins, but there are several other cases where it makes sense to message the user at a later time. Run the bash scripts in scripts/ to send notifications. Supports scheduled delivery, snooze buttons, and backup pings.
---

# Check-in Notifications via ntfy.sh

Send notifications to ntfy.sh topic `{{TOPIC}}`. **Run these scripts using the Bash tool.**

## Quick Start

**Schedule a check-in with backup pings:**
```bash
bash scripts/checkin_after.sh 45m
```

**Cancel backups when user arrives:**
```bash
bash scripts/cancel_backups.sh
```

## Primary Scripts

**checkin_after.sh** - Schedule a check-in after a delay (with automatic backup pings)
```bash
bash scripts/checkin_after.sh <delay> [message] [session_id]
# Examples:
bash scripts/checkin_after.sh 30m                          # Check-in in 30 minutes
bash scripts/checkin_after.sh 1h "How's the project?"      # Custom message
bash scripts/checkin_after.sh 45m "Break time" myproject   # Custom session ID
```
Automatically schedules:
- Primary notification at `<delay>` with snooze buttons
- Backup ping at `<delay> + 5m`
- Backup ping at `<delay> + 10m`

**cancel_backups.sh** - Cancel pending backup pings (call when user arrives)
```bash
bash scripts/cancel_backups.sh [session_id]
```

## Other Scripts

**start_checkin.sh** - Immediate notification + backup pings at +5m and +10m
```bash
bash scripts/start_checkin.sh <message> [session_id] [title]
```

**send_snooze.sh** - Send immediate notification with snooze buttons
```bash
bash scripts/send_snooze.sh <message> [title]
```

**schedule_snooze.sh** - Schedule notification with snooze buttons (no backups)
```bash
bash scripts/schedule_snooze.sh <delay> <message> [sequence_id] [title]
```

**send.sh** - Send immediate notification (no snooze)
```bash
bash scripts/send.sh <message> [title]
```

**schedule.sh** - Schedule notification (no snooze, no backups)
```bash
bash scripts/schedule.sh <delay> <message> [sequence_id] [title]
```

**cancel.sh** - Cancel a specific scheduled notification by ID
```bash
bash scripts/cancel.sh <sequence_id>
```

## Typical Workflow

1. User arrives after notification -> cancel pending backups:
   ```bash
   bash scripts/cancel_backups.sh
   ```

2. Conduct check-in conversation

3. Schedule next check-in:
   ```bash
   bash scripts/checkin_after.sh 45m
   ```

## Notes

- Delay format: 30m, 1h, 90s, etc.
- All scripts use Priority 4 (high) which causes prominent phone buzzing
- Backup pings use Priority 5 (max) for persistence
