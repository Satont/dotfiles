#!/bin/bash

STATE=$(bluetoothctl show | grep "Powered: yes")

if [[ -n "$STATE" ]]; then
  ICON="󰂯"
else
  ICON="󰂲"
fi

echo $ICON
