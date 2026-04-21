#!/bin/bash
# Toggle OpenCode float window on special scratchpad workspace

WINDOW_TITLE="OpenCode Float"

# Check if window already exists
if hyprctl clients -j | jq -e ".[] | select(.initialTitle == \"$WINDOW_TITLE\")" > /dev/null 2>&1; then
    hyprctl dispatch togglespecialworkspace opencode
else
    ghostty --title="$WINDOW_TITLE" -e /home/satont/.opencode/bin/opencode
fi
