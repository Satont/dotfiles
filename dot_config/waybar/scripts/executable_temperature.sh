#!/usr/bin/env bash

set -u

warning=70
critical=85

temp="$(
  sensors 2>/dev/null | awk '
    /Tctl:/ {gsub(/\+|°C/, "", $2); print int($2); exit}
    /Tdie:/ {gsub(/\+|°C/, "", $2); print int($2); exit}
    /Package id 0:/ {gsub(/\+|°C/, "", $4); print int($4); exit}
  '
)"

if [[ -z "$temp" ]]; then
  printf '{"text":"","class":"missing","tooltip":"CPU sensor not found"}\n'
  exit 0
fi

class="normal"
if (( temp >= critical )); then
  class="critical"
elif (( temp >= warning )); then
  class="warning"
fi

printf '{"text":" %s°C","class":"%s","tooltip":"CPU: %s°C"}\n' "$temp" "$class" "$temp"
