#!/usr/bin/env bash
# pulse.sh — one-shot snapshot of all public distribution metrics.
#
# What it shows:
#   - npm downloads (pinnedai, pinnedai-mcp) — daily + cumulative
#   - GitHub stars / forks / watchers / open issues
#   - GitHub repo traffic (uniques + views, last 14d) — needs gh auth
#   - Open VSX downloads + extension version
#   - VS Code Marketplace install count + status
#   - Optional: delta vs last run (if `.pulse-log` exists)
#
# No customer telemetry. No phone-home. Only public APIs.
#
# Usage:
#   bash scripts/pulse.sh                # print snapshot
#   bash scripts/pulse.sh --log          # append snapshot to .pulse-log
#   bash scripts/pulse.sh --json         # emit JSON instead of human text
#
# Recommended: drop into a cron or `at` job once per day to build a
# growth log over time.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$ROOT_DIR/.pulse-log"
EMIT_LOG=false
EMIT_JSON=false
for arg in "$@"; do
  case "$arg" in
    --log) EMIT_LOG=true ;;
    --json) EMIT_JSON=true ;;
  esac
done

# Colors (skip when piped).
if [ -t 1 ]; then
  C_DIM="\033[2m"
  C_BOLD="\033[1m"
  C_ACCENT="\033[38;5;214m"
  C_GREEN="\033[38;5;42m"
  C_RESET="\033[0m"
else
  C_DIM=""; C_BOLD=""; C_ACCENT=""; C_GREEN=""; C_RESET=""
fi

NOW=$(date -u +"%Y-%m-%d %H:%M UTC")
DATE_TAG=$(date -u +"%Y-%m-%d")

# ─── 1. npm downloads ─────────────────────────────────────────
fetch_npm() {
  local pkg="$1"
  # Last 7 days
  local week=$(curl -sf "https://api.npmjs.org/downloads/point/last-week/$pkg" 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('downloads',0))" 2>/dev/null || echo 0)
  # Last 30 days
  local month=$(curl -sf "https://api.npmjs.org/downloads/point/last-month/$pkg" 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('downloads',0))" 2>/dev/null || echo 0)
  # Latest version
  local ver=$(npm view "$pkg" version 2>/dev/null || echo "?")
  echo "${pkg}|${ver}|${week}|${month}"
}

# ─── 2. GitHub repo metrics ───────────────────────────────────
fetch_github() {
  local repo="pinnedai/pinnedai"
  gh api "repos/$repo" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('|'.join([
  str(d.get('stargazers_count', 0)),
  str(d.get('forks_count', 0)),
  str(d.get('subscribers_count', 0)),
  str(d.get('open_issues_count', 0)),
  str(d.get('size', 0)),
]))
" 2>/dev/null || echo "0|0|0|0|0"
}

fetch_github_traffic() {
  local repo="pinnedai/pinnedai"
  # Traffic requires push access — auth via gh CLI works since user owns repo
  gh api "repos/$repo/traffic/views" 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(f\"{d.get('count', 0)}|{d.get('uniques', 0)}\")
except: print('?|?')
" 2>/dev/null || echo "?|?"
}

# ─── 3. Open VSX downloads ────────────────────────────────────
fetch_openvsx() {
  curl -sf "https://open-vsx.org/api/pinnedai/pinnedai-vscode" 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print('|'.join([
    str(d.get('downloadCount', 0)),
    d.get('version', '?'),
    str(d.get('verified', False)),
  ]))
except: print('0|?|False')
" 2>/dev/null || echo "0|?|False"
}

# ─── 4. VS Code Marketplace ──────────────────────────────────
fetch_vsmarket() {
  curl -sf -A "Mozilla/5.0" -X POST "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json;api-version=3.0-preview.1" \
    --data '{"filters":[{"criteria":[{"filterType":7,"value":"pinnedai.pinnedai-vscode"}]}],"flags":914}' 2>/dev/null | \
    python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  exts = d.get('results', [{}])[0].get('extensions', [])
  if not exts:
    print('not-indexed|0|0')
  else:
    e = exts[0]
    stats = {s.get('statisticName'): s.get('value') for s in e.get('statistics', [])}
    print('|'.join([
      'indexed',
      str(int(stats.get('install', 0))),
      str(int(stats.get('downloadCount', 0))),
    ]))
except Exception as ex:
  print(f'error: {ex}|0|0')
" 2>/dev/null || echo "not-indexed|0|0"
}

# ─── Pull everything in parallel-ish ──────────────────────────
echo -e "${C_DIM}fetching…${C_RESET}" >&2

NPM_CLI=$(fetch_npm pinnedai)
NPM_MCP=$(fetch_npm pinnedai-mcp)
GH=$(fetch_github)
GH_TRAFFIC=$(fetch_github_traffic)
OVSX=$(fetch_openvsx)
VSMARKET=$(fetch_vsmarket)

# Parse
IFS='|' read -r CLI_PKG CLI_VER CLI_WK CLI_MO <<< "$NPM_CLI"
IFS='|' read -r MCP_PKG MCP_VER MCP_WK MCP_MO <<< "$NPM_MCP"
IFS='|' read -r GH_STARS GH_FORKS GH_WATCHERS GH_ISSUES GH_SIZE_KB <<< "$GH"
IFS='|' read -r GH_VIEWS GH_UNIQUES <<< "$GH_TRAFFIC"
IFS='|' read -r OVSX_DLS OVSX_VER OVSX_VERIFIED <<< "$OVSX"
IFS='|' read -r VSMARKET_STATUS VSMARKET_INSTALLS VSMARKET_DLS <<< "$VSMARKET"

# ─── JSON mode (machine-readable) ────────────────────────────
if [ "$EMIT_JSON" = true ]; then
  cat <<JSON
{
  "timestamp": "$NOW",
  "npm": {
    "pinnedai": { "version": "$CLI_VER", "weekly": $CLI_WK, "monthly": $CLI_MO },
    "pinnedai-mcp": { "version": "$MCP_VER", "weekly": $MCP_WK, "monthly": $MCP_MO }
  },
  "github": {
    "stars": $GH_STARS,
    "forks": $GH_FORKS,
    "watchers": $GH_WATCHERS,
    "open_issues": $GH_ISSUES,
    "repo_size_kb": $GH_SIZE_KB,
    "views_14d": "${GH_VIEWS}",
    "uniques_14d": "${GH_UNIQUES}"
  },
  "open_vsx": {
    "version": "$OVSX_VER",
    "downloads": $OVSX_DLS,
    "verified_namespace": "$OVSX_VERIFIED"
  },
  "vs_code_marketplace": {
    "status": "$VSMARKET_STATUS",
    "installs": $VSMARKET_INSTALLS,
    "downloads": $VSMARKET_DLS
  }
}
JSON
  exit 0
fi

# ─── Compute deltas vs last log entry ────────────────────────
DELTA_STARS=""
DELTA_OVSX=""
DELTA_CLI_WK=""
if [ -f "$LOG_FILE" ]; then
  LAST=$(tail -1 "$LOG_FILE")
  IFS='|' read -r _ L_STARS L_OVSX L_CLI_WK _ <<< "$LAST"
  if [ -n "${L_STARS:-}" ]; then DELTA_STARS=$((GH_STARS - L_STARS)); fi
  if [ -n "${L_OVSX:-}" ]; then DELTA_OVSX=$((OVSX_DLS - L_OVSX)); fi
  if [ -n "${L_CLI_WK:-}" ]; then DELTA_CLI_WK=$((CLI_WK - L_CLI_WK)); fi
fi

fmt_delta() {
  local d="$1"
  [ -z "$d" ] && return
  if [ "$d" -gt 0 ]; then echo -e "${C_GREEN}(+$d)${C_RESET}"
  elif [ "$d" -lt 0 ]; then echo "($d)"
  else echo -e "${C_DIM}(=)${C_RESET}"; fi
}

# ─── Print human-readable snapshot ───────────────────────────
echo ""
echo -e "${C_ACCENT}◆${C_RESET} ${C_BOLD}pinnedai pulse${C_RESET} ${C_DIM}· $NOW${C_RESET}"
echo ""
echo -e "${C_BOLD}npm${C_RESET}"
echo -e "  pinnedai${C_DIM} @${CLI_VER}${C_RESET}      weekly: ${C_BOLD}$CLI_WK${C_RESET}  $(fmt_delta "$DELTA_CLI_WK")  monthly: $CLI_MO"
echo -e "  pinnedai-mcp${C_DIM} @${MCP_VER}${C_RESET}  weekly: ${C_BOLD}$MCP_WK${C_RESET}            monthly: $MCP_MO"
echo ""
echo -e "${C_BOLD}GitHub${C_RESET} ${C_DIM}(pinnedai/pinnedai)${C_RESET}"
echo -e "  stars: ${C_BOLD}$GH_STARS${C_RESET}  $(fmt_delta "$DELTA_STARS")   forks: $GH_FORKS   watchers: $GH_WATCHERS   open issues: $GH_ISSUES"
echo -e "  traffic ${C_DIM}(14d)${C_RESET}  uniques: ${C_BOLD}$GH_UNIQUES${C_RESET}   views: $GH_VIEWS"
echo ""
echo -e "${C_BOLD}Open VSX${C_RESET}"
VERIFIED_TXT="$OVSX_VERIFIED"
if [ "$OVSX_VERIFIED" = "True" ]; then VERIFIED_TXT="${C_GREEN}verified${C_RESET}"; else VERIFIED_TXT="${C_DIM}pending${C_RESET}"; fi
echo -e "  pinnedai-vscode${C_DIM} @${OVSX_VER}${C_RESET}  downloads: ${C_BOLD}$OVSX_DLS${C_RESET}  $(fmt_delta "$DELTA_OVSX")  namespace: $VERIFIED_TXT"
echo ""
echo -e "${C_BOLD}VS Code Marketplace${C_RESET}"
if [ "$VSMARKET_STATUS" = "indexed" ]; then
  echo -e "  pinnedai-vscode  installs: ${C_BOLD}$VSMARKET_INSTALLS${C_RESET}   downloads: $VSMARKET_DLS"
else
  echo -e "  pinnedai-vscode  ${C_DIM}$VSMARKET_STATUS${C_RESET}"
fi
echo ""
echo -e "${C_BOLD}Web${C_RESET}"
echo -e "  pinnedai.dev     ${C_DIM}see https://vercel.com/michaels-projects-0b2351fa/pinnedai-landing/analytics${C_RESET}"
echo ""

# ─── Optional log (one line per snapshot) ─────────────────────
if [ "$EMIT_LOG" = true ]; then
  # Pipe-delimited: timestamp | gh_stars | ovsx_dls | cli_wk | mcp_wk | gh_issues | ovsx_ver
  echo "$DATE_TAG|$GH_STARS|$OVSX_DLS|$CLI_WK|$MCP_WK|$GH_ISSUES|$OVSX_VER" >> "$LOG_FILE"
  echo -e "${C_DIM}snapshot appended to .pulse-log${C_RESET}"
fi
