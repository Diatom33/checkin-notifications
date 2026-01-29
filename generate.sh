#!/bin/bash
# Generate checkin-notifications.skill from .channel config
# Usage: ./generate.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHANNEL_FILE="$SCRIPT_DIR/.channel"
OUTPUT_FILE="$SCRIPT_DIR/checkin-notifications.skill"

if [ ! -f "$CHANNEL_FILE" ]; then
    echo "Error: .channel file not found"
    echo "Create a .channel file with your ntfy.sh topic name:"
    echo "  echo 'your-topic-name' > .channel"
    exit 1
fi

TOPIC="$(cat "$CHANNEL_FILE" | tr -d '[:space:]')"

if [ -z "$TOPIC" ]; then
    echo "Error: .channel file is empty"
    exit 1
fi

echo "Generating skill for topic: $TOPIC"

# Create temp directory for skill contents
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

mkdir -p "$TEMP_DIR/scripts"

# --- send.sh ---
cat > "$TEMP_DIR/scripts/send.sh" << TEMPLATE
#!/bin/bash
# Send a basic notification with high priority
# Usage: send.sh <message> [title]

TOPIC="$TOPIC"
MESSAGE="\${1:?Usage: send.sh <message> [title]}"
TITLE="\${2:-}"

if [ -n "\$TITLE" ]; then
    curl -s -H "Priority: 4" -H "Title: \$TITLE" -d "\$MESSAGE" "ntfy.sh/\$TOPIC"
else
    curl -s -H "Priority: 4" -d "\$MESSAGE" "ntfy.sh/\$TOPIC"
fi
TEMPLATE

# --- send_snooze.sh ---
cat > "$TEMP_DIR/scripts/send_snooze.sh" << TEMPLATE
#!/bin/bash
# Send notification with snooze action buttons (5m, 15m, 30m)
# Usage: send_snooze.sh <message> [title]

TOPIC="$TOPIC"
MESSAGE="\${1:?Usage: send_snooze.sh <message> [title]}"
TITLE="\${2:-Check-in time}"

curl -s \\
  -H "Title: \$TITLE" \\
  -H "Priority: 4" \\
  -H "Actions: http, 5m, https://ntfy.sh/\$TOPIC, headers.In=5m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 5m); http, 15m, https://ntfy.sh/\$TOPIC, headers.In=15m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 15m); http, 30m, https://ntfy.sh/\$TOPIC, headers.In=30m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 30m)" \\
  -d "\$MESSAGE" \\
  "ntfy.sh/\$TOPIC"
TEMPLATE

# --- schedule.sh ---
cat > "$TEMP_DIR/scripts/schedule.sh" << TEMPLATE
#!/bin/bash
# Schedule a notification for later delivery
# Usage: schedule.sh <delay> <message> [sequence_id] [title]
# Delay format: 5m, 1h, 30s, etc.

TOPIC="$TOPIC"
DELAY="\${1:?Usage: schedule.sh <delay> <message> [sequence_id] [title]}"
MESSAGE="\${2:?Usage: schedule.sh <delay> <message> [sequence_id] [title]}"
SEQ_ID="\${3:-}"
TITLE="\${4:-}"

URL="ntfy.sh/\$TOPIC"
[ -n "\$SEQ_ID" ] && URL="\$URL/\$SEQ_ID"

HEADERS=(-H "In: \$DELAY" -H "Priority: 4")
[ -n "\$TITLE" ] && HEADERS+=(-H "Title: \$TITLE")

curl -s "\${HEADERS[@]}" -d "\$MESSAGE" "\$URL"
TEMPLATE

# --- schedule_snooze.sh ---
cat > "$TEMP_DIR/scripts/schedule_snooze.sh" << TEMPLATE
#!/bin/bash
# Schedule a notification for later WITH snooze action buttons
# This is the primary script for adaptive check-in scheduling
# Usage: schedule_snooze.sh <delay> <message> [sequence_id] [title]
# Delay format: 5m, 1h, 30s, etc.

TOPIC="$TOPIC"
DELAY="\${1:?Usage: schedule_snooze.sh <delay> <message> [sequence_id] [title]}"
MESSAGE="\${2:?Usage: schedule_snooze.sh <delay> <message> [sequence_id] [title]}"
SEQ_ID="\${3:-}"
TITLE="\${4:-Check-in time}"

URL="ntfy.sh/\$TOPIC"
[ -n "\$SEQ_ID" ] && URL="\$URL/\$SEQ_ID"

curl -s \\
  -H "In: \$DELAY" \\
  -H "Title: \$TITLE" \\
  -H "Priority: 4" \\
  -H "Actions: http, 5m, https://ntfy.sh/\$TOPIC, headers.In=5m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 5m); http, 15m, https://ntfy.sh/\$TOPIC, headers.In=15m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 15m); http, 30m, https://ntfy.sh/\$TOPIC, headers.In=30m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 30m)" \\
  -d "\$MESSAGE" \\
  "\$URL"
TEMPLATE

# --- cancel.sh ---
cat > "$TEMP_DIR/scripts/cancel.sh" << TEMPLATE
#!/bin/bash
# Cancel a scheduled notification by sequence ID
# Usage: cancel.sh <sequence_id>

TOPIC="$TOPIC"
SEQ_ID="\${1:?Usage: cancel.sh <sequence_id>}"

curl -s -X DELETE "ntfy.sh/\$TOPIC/\$SEQ_ID"
TEMPLATE

# --- start_checkin.sh ---
cat > "$TEMP_DIR/scripts/start_checkin.sh" << TEMPLATE
#!/bin/bash
# Start a full check-in: primary notification with snooze buttons + backup pings
# Backups are scheduled at +5m and +10m with sequence IDs for cancellation
# Usage: start_checkin.sh <message> [session_id] [title]
# Session ID is used to create unique sequence IDs (default: "checkin")

TOPIC="$TOPIC"
MESSAGE="\${1:?Usage: start_checkin.sh <message> [session_id] [title]}"
SESSION="\${2:-checkin}"
TITLE="\${3:-Check-in time}"

# Primary notification with snooze buttons
curl -s \\
  -H "Title: \$TITLE" \\
  -H "Priority: 4" \\
  -H "Actions: http, 5m, https://ntfy.sh/\$TOPIC, headers.In=5m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 5m); http, 15m, https://ntfy.sh/\$TOPIC, headers.In=15m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 15m); http, 30m, https://ntfy.sh/\$TOPIC, headers.In=30m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 30m)" \\
  -d "\$MESSAGE" \\
  "ntfy.sh/\$TOPIC/\${SESSION}-primary"

# Backup pings at +5m and +10m
curl -s -H "In: 5m" -H "Priority: 4" -H "Title: Still there?" \\
  -d "Backup: \$MESSAGE" "ntfy.sh/\$TOPIC/\${SESSION}-backup1"

curl -s -H "In: 10m" -H "Priority: 5" -H "Title: Persistent ping" \\
  -d "Backup #2: \$MESSAGE" "ntfy.sh/\$TOPIC/\${SESSION}-backup2"

echo ""
echo "Check-in started. Session: \$SESSION"
echo "Backup sequence IDs: \${SESSION}-backup1, \${SESSION}-backup2"
TEMPLATE

# --- cancel_backups.sh ---
cat > "$TEMP_DIR/scripts/cancel_backups.sh" << TEMPLATE
#!/bin/bash
# Cancel backup pings for a check-in session
# Usage: cancel_backups.sh [session_id]
# Session ID must match what was used in start_checkin.sh (default: "checkin")

TOPIC="$TOPIC"
SESSION="\${1:-checkin}"

# Sleep to avoid race condition (in case this is called right after scheduling)
sleep 2

curl -s -X DELETE "ntfy.sh/\$TOPIC/\${SESSION}-backup1"
curl -s -X DELETE "ntfy.sh/\$TOPIC/\${SESSION}-backup2"

echo ""
echo "Canceled backups for session: \$SESSION"
TEMPLATE

# Make all scripts executable
chmod +x "$TEMP_DIR/scripts/"*.sh

# --- SKILL.md ---
cat > "$TEMP_DIR/SKILL.md" << TEMPLATE
---
name: checkin-notifications
description: Send persistent, snoozeable notifications via ntfy.sh for accountability check-ins. Use when scheduling check-in reminders, sending notifications with snooze options, or managing delayed/scheduled notifications. Supports staggered delivery for persistence and action buttons for snooze-from-phone.
---

# Check-in Notifications via ntfy.sh

Send notifications to topic \`$TOPIC\` with persistence and snooze capabilities.

## Scripts

All scripts use Priority 4 (high) by default for prominent phone buzzing.

### send.sh - Basic notification
\`\`\`bash
scripts/send.sh <message> [title]
\`\`\`

### send_snooze.sh - Notification with snooze buttons (5m/15m/30m)
\`\`\`bash
scripts/send_snooze.sh <message> [title]
\`\`\`

### schedule.sh - Schedule basic notification for later
\`\`\`bash
scripts/schedule.sh <delay> <message> [sequence_id] [title]
# Delay format: 5m, 1h, 30s, etc.
\`\`\`

### schedule_snooze.sh - Schedule notification with snooze buttons
**This is the primary script for adaptive check-in scheduling.**
\`\`\`bash
scripts/schedule_snooze.sh <delay> <message> [sequence_id] [title]
# Delay format: 5m, 1h, 30s, etc.
# Example: scripts/schedule_snooze.sh 45m "Time for a check-in!" "next-checkin"
\`\`\`

### cancel.sh - Cancel scheduled notification
\`\`\`bash
scripts/cancel.sh <sequence_id>
\`\`\`

### start_checkin.sh - Full check-in flow (immediate)
Sends primary notification with snooze buttons + backup pings at +5m and +10m.
\`\`\`bash
scripts/start_checkin.sh <message> [session_id] [title]
# Session ID creates unique sequence IDs (default: "checkin")
# Creates: {session}-primary, {session}-backup1, {session}-backup2
\`\`\`

### cancel_backups.sh - Cancel backup pings
Call when user arrives to cancel pending backups. Includes 2s sleep for race condition.
\`\`\`bash
scripts/cancel_backups.sh [session_id]
\`\`\`

## Typical Adaptive Check-in Workflow

1. User arrives after notification -> cancel any pending backups:
   \`\`\`bash
   scripts/cancel_backups.sh "session-id"
   \`\`\`

2. Conduct check-in conversation

3. Schedule next check-in with snooze buttons:
   \`\`\`bash
   scripts/schedule_snooze.sh 45m "How's it going?" "next-checkin" "Check-in time"
   \`\`\`

## For Immediate Check-ins

Use \`start_checkin.sh\` when you need to ping right now with backup persistence:
\`\`\`bash
scripts/start_checkin.sh "How's it going?" "afternoon-checkin"
\`\`\`

## Scheduling for Absolute Time

Use \`At:\` header directly for absolute times:
\`\`\`bash
curl -s -H "At: 3:30pm" -H "Priority: 4" -d "Check-in!" ntfy.sh/$TOPIC
\`\`\`

## Race Condition Warning

If scheduling and canceling in the same bash invocation, add \`sleep 2\` between them. The scheduler needs time to index messages before DELETE works. The \`cancel_backups.sh\` script handles this automatically.

## Priority Levels

1 (min), 2 (low), 3 (default), 4 (high), 5 (urgent/bypasses DND)

Always use Priority 4+ for real check-ins.
TEMPLATE

# Create .skill file (zip archive)
rm -f "$OUTPUT_FILE"
(cd "$TEMP_DIR" && zip -rq "$OUTPUT_FILE" SKILL.md scripts/)

echo "Generated: $OUTPUT_FILE"
