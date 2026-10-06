#!/bin/sh
# Scaffolds a mod in $CLAUDE_MODS_DIR/<name> (default ~/claude-mods): a pane opened by /<name>, with the house style
# (accent, header with meta, an empty state, width share, re-ask on tab front), and registers it in the
# local claude-mods marketplace. Usage: scaffold.sh <name> "<one-line description>" [accent-hex]
set -eu
name=${1:?usage: scaffold.sh <name> "<description>" [accent]}
desc=${2:?a one-line description}
accent=${3:-#4fd6be}
case "$name" in *[!a-z0-9-]*|'') echo "name: lowercase letters, digits and dashes"; exit 1;; esac
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/scripts/env.sh"
root="$MODS"
dir="$root/$name"
[ -e "$dir" ] && { echo "$dir exists"; exit 1; }
ensure_marketplace
who=$(owner)
mkdir -p "$dir/.claude-plugin" "$dir/hooks" "$dir/types"
title=$(printf '%s' "$name" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')

jq -n --arg n "$name" --arg d "$desc" '{name:$n, version:"0.1.0", description:$d, types:"./types/index.d.ts",
  userConfig:{widthPercent:{type:"number", title:"Pane width (%)", description:"Share of the terminal the docked pane asks for", default:40}}}' > "$dir/.claude-plugin/plugin.json"
jq -n --arg n "$name" --arg d "$desc" --arg o "$who" '{name:$n, owner:{name:$o, url:("https://github.com/" + $o)}, description:$d,
  plugins:[{name:$n, description:$d, source:"./", category:"productivity", tags:["mod"]}]}' > "$dir/.claude-plugin/marketplace.json"
echo '{ "modules": ["./register.tsx"] }' > "$dir/hooks/hooks.json"

cat > "$dir/types/index.d.ts" <<EOF
export type ${title}Item = { id: number; text: string; at: number }

declare module 'claude-code' {
  interface PluginState {
    '$name': {
      items: ${title}Item[]
      busy: boolean
    }
  }
}
EOF

sed -e "s/__NAME__/$name/g" -e "s/__TITLE__/$title/g" -e "s/__ACCENT__/$accent/g" -e "s/__DESC__/$(printf '%s' "$desc" | sed 's/[\/&]/\\&/g')/g" \
  "$here/scripts/template-register.tsx" > "$dir/hooks/register.tsx"

sed -e "s/__YEAR__/$(date +%Y)/" -e "s/__OWNER__/$who/" "$here/scripts/LICENSE.template" > "$dir/LICENSE"
printf 'node_modules/\n.claude-plugin/types/\n.DS_Store\n' > "$dir/.gitignore"
cat > "$dir/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "target": "es2023", "lib": ["es2023"], "types": [],
    "module": "esnext", "moduleResolution": "bundler", "allowImportingTsExtensions": true,
    "strict": true, "noUncheckedIndexedAccess": true, "noEmit": true, "skipLibCheck": true,
    "jsx": "react", "jsxFactory": "h", "jsxFragmentFactory": "Fragment"
  },
  "include": [".claude-plugin/types", "hooks", "types", "tests"]
}
EOF
cat > "$dir/README.md" <<EOF
# $name

$desc

\`\`\`text
/$name   open or close the pane
\`\`\`

## Install

\`\`\`sh
claude plugin marketplace add $who/$name
claude plugin install $name@$name
\`\`\`

Needs Claude Code 2.1.289 or later.

## License

MIT
EOF

m="$root/.claude-plugin/marketplace.json"
jq --arg n "$name" --arg d "$desc" '.plugins = ([.plugins[] | select(.name != $n)] + [{name:$n, source:("./" + $n), description:$d}])' "$m" > "$m.tmp" && mv "$m.tmp" "$m"
if [ -z "${CREATE_MOD_NO_REGISTER:-}" ]; then
  claude plugin marketplace update claude-mods >/dev/null 2>&1 || true
  claude plugin install "$name@claude-mods" >/dev/null 2>&1 && echo "installed $name@claude-mods: run /reload-plugins in Claude Code"
fi
echo "scaffolded $dir"
echo "next: design the UI (mockup), write hooks/register.tsx, then: $here/scripts/check.sh $name"
