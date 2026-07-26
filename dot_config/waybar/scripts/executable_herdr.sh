#!/usr/bin/env bash

json=$(herdr agent list)

text=$(
  jq -r '
    .result.agents
    | map(select(.agent_status == "working"))
    | group_by(.cwd | split("/")[-1])
    | map("\(.[0].cwd | split("/")[-1]) - \(length)")
    | join(" | ")
  ' <<<"$json"
)

if [ -z "$text" ] || [ "$text" = '""' ]; then
    echo '{"text":"🤖","tooltip":"Нет работающих агентов"}'
else
    jq -nc \
        --arg text "🤖 $text" \
        --arg tooltip "$text" \
        '{text:$text,tooltip:$tooltip}'
fi
