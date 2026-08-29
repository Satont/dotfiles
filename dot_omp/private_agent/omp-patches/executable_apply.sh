#!/usr/bin/env bash
# omp local patches — idempotent, safe to run before every omp launch.
#
# Applies/maintains:
#   1. dist/cli.js: remove "ctrl+p" from the reserved-shortcuts map
#      (lets pi-command-palette register ctrl+p).
#   2. dist/cli.js: drop slash commands duplicated by the Ctrl+P palette
#      (model/new/fork/resume/compact/session/tools) from the builtin registry.
#   3. ~/.omp/plugins/node_modules/pi-command-palette/index.ts:
#      sync fixed plugin source (Switch Model lists only connected models,
#      handle.focus optional-call fix).
#
# Exits 0 on success/already-applied, 1 when a patch anchor is missing
# (usually means omp updated and minified names changed — update this script).
set -u

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SRC="$KIT_DIR/pi-command-palette.index.ts"
PLUGIN_DST="$HOME/.omp/plugins/node_modules/pi-command-palette/index.ts"
FAILED=0

resolve_cli_js() {
	local bin
	bin="$(command -v omp 2>/dev/null)" || return 1
	bin="$(readlink -f "$bin" 2>/dev/null)" || return 1
	case "$bin" in
		*/dist/cli.js) printf '%s' "$bin" ;;
		*) # bin shim (e.g. bun run wrapper) — fall back to bun global layout
			local g="$HOME/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js"
			[ -f "$g" ] && printf '%s' "$g" || return 1
			;;
	esac
}

CLI_JS="$(resolve_cli_js)" || { echo "omp-patches: cli.js not found"; exit 1; }

need_patch() { ! grep -qF "$2" "$1" 2>/dev/null; }

# ---------- patch 1: unreserve ctrl+p ----------
# Reserved map begins with {"ctrl+c":!0,"ctrl+d":!0 ...}; strip "ctrl+p":!0 inside it.
if grep -qF '"ctrl+k":!0,"ctrl+p":!0,"ctrl+l":!0' "$CLI_JS"; then
	python3 - "$CLI_JS" <<'PYEOF'
import sys
p = sys.argv[1]
data = open(p, encoding='utf8').read()
anchor = '={"ctrl+c":!0,"ctrl+d":!0'
i = data.find(anchor)
if i == -1:
    sys.exit(3)
j = data.find('}', i)
seg = data[i:j]
if '"ctrl+p":!0' not in seg:
    sys.exit(0)  # already applied
seg = seg.replace('"ctrl+p":!0,', '').replace(',"ctrl+p":!0', '')
open(p, 'w', encoding='utf8').write(data[:i] + seg + data[j:])
PYEOF
	[ $? -eq 3 ] && { echo "omp-patches: FAIL reserved-map anchor missing (omp updated?)"; FAILED=1; }
elif ! grep -qF '={"ctrl+c":!0,"ctrl+d":!0' "$CLI_JS"; then
	echo "omp-patches: FAIL reserved map not found at all"; FAILED=1
fi

# ---------- patch 2: prune palette-duplicate slash commands ----------
if ! grep -qF 'filter((e)=>!["model","new","fork","resume","compact","session","tools"]' "$CLI_JS"; then
	python3 - "$CLI_JS" <<'PYEOF'
import sys
p = sys.argv[1]
data = open(p, encoding='utf8').read()
marker = '.filter((e)=>!["model","new","fork","resume","compact","session","tools"].includes(e.name))'
i = data.find('=new Map;for(let')
hit = -1
while i != -1:
    j = data.rfind('=[...', 0, i)
    k = data.find(']', j) if j != -1 else -1
    if k != -1 and 'name:e.name,aliases:e.aliases' in data[k:k+4000]:
        hit = k
        break
    i = data.find('=new Map;for(let', i + 1)
if hit == -1:
    sys.exit(3)
data = data[:hit+1] + marker + data[hit+1:]
open(p, 'w', encoding='utf8').write(data)
PYEOF
	case $? in
		3) echo "omp-patches: FAIL slash-registry anchor missing (omp updated?)"; FAILED=1 ;;
	esac
fi

# ---------- patch 3: plugin source sync ----------
if [ ! -f "$PLUGIN_DST" ] && [ -f "$HOME/.omp/plugins/package.json" ]; then
	(cd "$HOME/.omp/plugins" && bun install >/dev/null 2>&1)
fi
if [ -f "$PLUGIN_SRC" ] && [ -f "$PLUGIN_DST" ]; then
	cmp -s "$PLUGIN_SRC" "$PLUGIN_DST" || cp "$PLUGIN_SRC" "$PLUGIN_DST"
elif [ -f "$PLUGIN_SRC" ] && [ ! -f "$PLUGIN_DST" ]; then
	echo "omp-patches: plugin not installed (skip sync)"
fi

[ "$FAILED" -eq 0 ] || exit 1
exit 0
