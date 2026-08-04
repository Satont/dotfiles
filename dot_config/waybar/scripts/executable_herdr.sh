#!/usr/bin/env bash

json=$(herdr agent list)

text=$(
  jq -r '
    .result.agents
    | map(select(.agent_status == "working"))
    | map(
        . as $agent
        | .display_name = (
            ($agent.terminal_title_stripped // "")
            | if startswith("OC | ") then
                ltrimstr("OC | ")
              else
                ($agent.cwd | split("/")[-1])
              end
          )
      )
    | group_by(.display_name)
    | map("\(.[0].display_name) - \(length)")
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
