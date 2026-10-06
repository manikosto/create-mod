# Shared settings for the create-mod scripts. Sourced, not run.
#   CLAUDE_MODS_DIR   where mods live (default ~/claude-mods); each mod is a folder in it
#   MODS_OWNER        the GitHub account mods are published under (default: the gh login, else git user.name)
#   CREATE_MOD_NO_REGISTER=1   do not touch Claude Code's plugin settings (tests)
MODS="${CLAUDE_MODS_DIR:-$HOME/claude-mods}"
MODS="${MODS%/}"
owner() {
  if [ -n "${MODS_OWNER:-}" ]; then echo "$MODS_OWNER"; return; fi
  o=$(gh api user -q .login 2>/dev/null || true)
  [ -n "$o" ] || o=$(git config --global user.name 2>/dev/null | tr -d ' ' || true)
  [ -n "$o" ] || o=$(whoami)
  echo "$o"
}
# The local marketplace every mod is installed from while you work on it: edits apply on /reload-plugins.
ensure_marketplace() {
  mkdir -p "$MODS/.claude-plugin"
  m="$MODS/.claude-plugin/marketplace.json"
  if [ ! -f "$m" ]; then
    jq -n --arg o "$(owner)" '{name:"claude-mods", owner:{name:$o}, description:"My Claude Code mods", plugins:[]}' > "$m"
    if [ -z "${CREATE_MOD_NO_REGISTER:-}" ]; then claude plugin marketplace add "$MODS" >/dev/null 2>&1 || true; fi
  fi
}
find_types() {
  for t in $(ls -t "${TMPDIR:-/tmp}"/claude-*/bundled-skills/*/*/plugin-authoring/types/claude-code.d.ts \
                 /private/tmp/claude-*/bundled-skills/*/*/plugin-authoring/types/claude-code.d.ts \
                 /tmp/claude-*/bundled-skills/*/*/plugin-authoring/types/claude-code.d.ts 2>/dev/null); do
    echo "$t"; return
  done
  [ -f "$1/.claude-plugin/types/claude-code/index.d.ts" ] && echo "$1/.claude-plugin/types/claude-code/index.d.ts"
}
