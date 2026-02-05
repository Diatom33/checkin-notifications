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
    curl -s -H "Priority: 4" -H "Title: \$TITLE" -d "\$MESSAGE" "https://ntfy.sh/\$TOPIC"
else
    curl -s -H "Priority: 4" -d "\$MESSAGE" "https://ntfy.sh/\$TOPIC"
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
  "https://ntfy.sh/\$TOPIC"
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

HEADERS=(-H "In: \$DELAY" -H "Priority: 4")
[ -n "\$SEQ_ID" ] && HEADERS+=(-H "X-ID: \$SEQ_ID")
[ -n "\$TITLE" ] && HEADERS+=(-H "Title: \$TITLE")

curl -s "\${HEADERS[@]}" -d "\$MESSAGE" "https://ntfy.sh/\$TOPIC"
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

HEADERS=(-H "In: \$DELAY" -H "Title: \$TITLE" -H "Priority: 4")
[ -n "\$SEQ_ID" ] && HEADERS+=(-H "X-ID: \$SEQ_ID")

curl -s "\${HEADERS[@]}" \\
  -H "Actions: http, 5m, https://ntfy.sh/\$TOPIC, headers.In=5m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 5m); http, 15m, https://ntfy.sh/\$TOPIC, headers.In=15m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 15m); http, 30m, https://ntfy.sh/\$TOPIC, headers.In=30m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 30m)" \\
  -d "\$MESSAGE" \\
  "https://ntfy.sh/\$TOPIC"
TEMPLATE

# --- cancel.sh ---
cat > "$TEMP_DIR/scripts/cancel.sh" << TEMPLATE
#!/bin/bash
# Cancel a scheduled notification by sequence ID
# Usage: cancel.sh <sequence_id>

TOPIC="$TOPIC"
SEQ_ID="\${1:?Usage: cancel.sh <sequence_id>}"

curl -s -X DELETE "https://ntfy.sh/\$TOPIC/\$SEQ_ID"
TEMPLATE

# --- start_checkin.sh ---
cat > "$TEMP_DIR/scripts/start_checkin.sh" << TEMPLATE
#!/bin/bash
# Start a full check-in: immediate notification with snooze buttons + backup pings
# Backups are scheduled at +5m and +10m with message IDs for cancellation
# Usage: start_checkin.sh <message> [session_id] [title]

TOPIC="$TOPIC"
MESSAGE="\${1:?Usage: start_checkin.sh <message> [session_id] [title]}"
SESSION="\${2:-checkin}"
TITLE="\${3:-Check-in time}"

# Primary notification with snooze buttons (immediate)
curl -s \\
  -H "X-ID: \${SESSION}-primary" \\
  -H "Title: \$TITLE" \\
  -H "Priority: 4" \\
  -H "Actions: http, 5m, https://ntfy.sh/\$TOPIC, headers.In=5m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 5m); http, 15m, https://ntfy.sh/\$TOPIC, headers.In=15m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 15m); http, 30m, https://ntfy.sh/\$TOPIC, headers.In=30m, headers.Title=Snoozed, body=⏰ \$MESSAGE (snoozed 30m)" \\
  -d "\$MESSAGE" \\
  "https://ntfy.sh/\$TOPIC"

# Backup ping at +5m
curl -s \\
  -H "X-ID: \${SESSION}-backup1" \\
  -H "In: 5m" \\
  -H "Priority: 4" \\
  -H "Title: Still there?" \\
  -d "Backup: \$MESSAGE" \\
  "https://ntfy.sh/\$TOPIC"

# Backup ping at +10m
curl -s \\
  -H "X-ID: \${SESSION}-backup2" \\
  -H "In: 10m" \\
  -H "Priority: 5" \\
  -H "Title: Persistent ping" \\
  -d "Backup #2: \$MESSAGE" \\
  "https://ntfy.sh/\$TOPIC"

echo "Check-in started. Session: \$SESSION"
echo "Backups scheduled: +5m (\${SESSION}-backup1), +10m (\${SESSION}-backup2)"
TEMPLATE

# --- cancel_backups.sh ---
cat > "$TEMP_DIR/scripts/cancel_backups.sh" << TEMPLATE
#!/bin/bash
# Cancel backup pings for a check-in session
# Usage: cancel_backups.sh [session_id]

TOPIC="$TOPIC"
SESSION="\${1:-checkin}"

# Sleep to avoid race condition (ntfy needs time to register scheduled messages)
sleep 2

curl -s -X DELETE "https://ntfy.sh/\$TOPIC/\${SESSION}-backup1"
curl -s -X DELETE "https://ntfy.sh/\$TOPIC/\${SESSION}-backup2"

echo "Canceled backups for session: \$SESSION"
TEMPLATE

# --- checkin_after.sh ---
cat > "$TEMP_DIR/scripts/checkin_after.sh" << 'TEMPLATE'
#!/bin/bash
# Schedule a check-in after a delay, with automatic backup pings
# This is the recommended script for Claude to schedule check-ins
# Usage: checkin_after.sh <delay> [message] [session_id]
# Delay format: 30m, 1h, 45m, 90s, etc.

TOPIC="TOPIC_PLACEHOLDER"
DELAY="${1:?Usage: checkin_after.sh <delay> [message] [session_id]}"
MESSAGE="${2:-Time for a check-in!}"
SESSION="${3:-checkin}"

# Parse delay into seconds
parse_delay() {
    local val="${1%[smhSMH]}"
    local unit="${1: -1}"
    case "$unit" in
        s|S) echo "$val" ;;
        m|M) echo $((val * 60)) ;;
        h|H) echo $((val * 3600)) ;;
        *) echo "$1" ;;  # assume seconds if no unit
    esac
}

# Convert seconds back to ntfy format (use minutes for readability)
secs_to_delay() {
    local secs="$1"
    if (( secs >= 3600 && secs % 3600 == 0 )); then
        echo "$((secs / 3600))h"
    elif (( secs >= 60 )); then
        echo "$((secs / 60))m"
    else
        echo "${secs}s"
    fi
}

BASE_SECS=$(parse_delay "$DELAY")
BACKUP1_SECS=$((BASE_SECS + 300))   # +5 minutes
BACKUP2_SECS=$((BASE_SECS + 600))   # +10 minutes

BACKUP1_DELAY=$(secs_to_delay $BACKUP1_SECS)
BACKUP2_DELAY=$(secs_to_delay $BACKUP2_SECS)

# Primary notification with snooze buttons
curl -s \
  -H "X-ID: ${SESSION}-primary" \
  -H "In: $DELAY" \
  -H "Title: Check-in time" \
  -H "Priority: 4" \
  -H "Actions: http, 5m, https://ntfy.sh/$TOPIC, headers.In=5m, headers.Title=Snoozed, body=⏰ $MESSAGE (snoozed 5m); http, 15m, https://ntfy.sh/$TOPIC, headers.In=15m, headers.Title=Snoozed, body=⏰ $MESSAGE (snoozed 15m); http, 30m, https://ntfy.sh/$TOPIC, headers.In=30m, headers.Title=Snoozed, body=⏰ $MESSAGE (snoozed 30m)" \
  -d "$MESSAGE" \
  "https://ntfy.sh/$TOPIC"

# Backup ping at delay+5m
curl -s \
  -H "X-ID: ${SESSION}-backup1" \
  -H "In: $BACKUP1_DELAY" \
  -H "Priority: 4" \
  -H "Title: Still there?" \
  -d "Backup: $MESSAGE" \
  "https://ntfy.sh/$TOPIC"

# Backup ping at delay+10m
curl -s \
  -H "X-ID: ${SESSION}-backup2" \
  -H "In: $BACKUP2_DELAY" \
  -H "Priority: 5" \
  -H "Title: Persistent ping" \
  -d "Backup #2: $MESSAGE" \
  "https://ntfy.sh/$TOPIC"

echo "Scheduled check-in in $DELAY (backups at $BACKUP1_DELAY, $BACKUP2_DELAY)"
echo "Session: $SESSION"
TEMPLATE

# Replace placeholder with actual topic (can't use $TOPIC directly in single-quoted heredoc)
sed -i "s/TOPIC_PLACEHOLDER/$TOPIC/" "$TEMP_DIR/scripts/checkin_after.sh"

# Make all scripts executable
chmod +x "$TEMP_DIR/scripts/"*.sh

# --- SKILL.md ---
cat > "$TEMP_DIR/SKILL.md" << TEMPLATE
---
name: checkin-notifications
description: Send persistent, snoozeable notifications via ntfy.sh for accountability check-ins. Run the bash scripts in scripts/ to send notifications. Supports scheduled delivery, snooze buttons, and backup pings.
---

# Check-in Notifications via ntfy.sh

Send notifications to ntfy.sh topic \`$TOPIC\`. **Run these scripts using the Bash tool.**

## Quick Start

**Schedule a check-in with backup pings:**
\`\`\`bash
bash scripts/checkin_after.sh 45m
\`\`\`

**Cancel backups when user arrives:**
\`\`\`bash
bash scripts/cancel_backups.sh
\`\`\`

## Primary Scripts

**checkin_after.sh** - Schedule a check-in after a delay (with automatic backup pings)
\`\`\`bash
bash scripts/checkin_after.sh <delay> [message] [session_id]
# Examples:
bash scripts/checkin_after.sh 30m                          # Check-in in 30 minutes
bash scripts/checkin_after.sh 1h "How's the project?"      # Custom message
bash scripts/checkin_after.sh 45m "Break time" myproject   # Custom session ID
\`\`\`
Automatically schedules:
- Primary notification at \`<delay>\` with snooze buttons
- Backup ping at \`<delay> + 5m\`
- Backup ping at \`<delay> + 10m\`

**cancel_backups.sh** - Cancel pending backup pings (call when user arrives)
\`\`\`bash
bash scripts/cancel_backups.sh [session_id]
\`\`\`

## Other Scripts

**start_checkin.sh** - Immediate notification + backup pings at +5m and +10m
\`\`\`bash
bash scripts/start_checkin.sh <message> [session_id] [title]
\`\`\`

**send_snooze.sh** - Send immediate notification with snooze buttons
\`\`\`bash
bash scripts/send_snooze.sh <message> [title]
\`\`\`

**schedule_snooze.sh** - Schedule notification with snooze buttons (no backups)
\`\`\`bash
bash scripts/schedule_snooze.sh <delay> <message> [sequence_id] [title]
\`\`\`

**send.sh** - Send immediate notification (no snooze)
\`\`\`bash
bash scripts/send.sh <message> [title]
\`\`\`

**schedule.sh** - Schedule notification (no snooze, no backups)
\`\`\`bash
bash scripts/schedule.sh <delay> <message> [sequence_id] [title]
\`\`\`

**cancel.sh** - Cancel a specific scheduled notification by ID
\`\`\`bash
bash scripts/cancel.sh <sequence_id>
\`\`\`

## Typical Workflow

1. User arrives after notification → cancel pending backups:
   \`\`\`bash
   bash scripts/cancel_backups.sh
   \`\`\`

2. Conduct check-in conversation

3. Schedule next check-in:
   \`\`\`bash
   bash scripts/checkin_after.sh 45m
   \`\`\`

## Notes

- Delay format: 30m, 1h, 90s, etc.
- All scripts use Priority 4 (high) which causes prominent phone buzzing
- Backup pings use Priority 5 (max) for persistence
TEMPLATE

# Create .skill file (zip archive)
rm -f "$OUTPUT_FILE"
(cd "$TEMP_DIR" && zip -rq "$OUTPUT_FILE" SKILL.md scripts/)

echo "Generated: $OUTPUT_FILE"
