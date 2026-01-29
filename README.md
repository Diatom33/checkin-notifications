# Check-in Notifications

A Claude skill for sending persistent, snoozeable notifications via [ntfy.sh](https://ntfy.sh). Designed for accountability check-ins with snooze buttons and backup pings.

## Setup

1. Clone this repository

2. Create a `.channel` file with your ntfy.sh topic name:
   ```bash
   echo 'your-topic-name' > .channel
   ```

3. Generate the skill file:
   ```bash
   ./generate.sh
   ```

4. Install the generated `checkin-notifications.skill` in claude.ai or Claude Code

5. Subscribe to your topic in the ntfy app on your phone

## What's in the Skill

- **send.sh** - Send a basic notification
- **send_snooze.sh** - Send with snooze buttons (5m/15m/30m)
- **schedule.sh** - Schedule a notification for later
- **schedule_snooze.sh** - Schedule with snooze buttons (primary script)
- **cancel.sh** - Cancel a scheduled notification
- **start_checkin.sh** - Full check-in with backup pings
- **cancel_backups.sh** - Cancel pending backup pings

## Usage

The skill is designed for adaptive check-in workflows:

1. Claude schedules a check-in notification
2. You get a phone buzz with snooze buttons
3. Tap snooze or come back to chat
4. Claude cancels pending backups and schedules the next check-in

## Privacy

The `.channel` file and generated `.skill` file are gitignored. Your ntfy.sh topic name stays private.
