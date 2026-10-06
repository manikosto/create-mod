#!/bin/sh
# Checks a mod: the engine's validator, then tsc against this build's API types.
# Usage: check.sh <name>   (pure-logic Node tests and Client harnesses are run separately)
set -u
name=${1:?usage: check.sh <name>}
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
dir="$MODS/$name"
[ -d "$dir" ] || { echo "no mod at $dir"; exit 1; }
echo "1. claude plugin validate"
claude plugin validate "$dir" 2>&1 | grep -E '✔|✘|❯ (modules|\./register|\./[a-z]+\.tsx) ' | cut -c1-240
types=$(find_types "$dir")
echo "2. tsc"
if [ -z "$types" ]; then echo "   skipped: no API types found (load the plugin-authoring skill once, or /reload-plugins with the mod installed)"; exit 0; fi
w=$(mktemp -d)
cp "$types" "$w/claude-code.d.ts"
cat > "$w/tsconfig.json" <<EOF
{ "compilerOptions": { "target": "es2023", "lib": ["es2023"], "types": [], "module": "esnext", "moduleResolution": "bundler",
  "allowImportingTsExtensions": true, "strict": true, "noUncheckedIndexedAccess": true, "noEmit": true, "skipLibCheck": true,
  "jsx": "react", "jsxFactory": "h", "jsxFragmentFactory": "Fragment" },
  "include": ["$w/claude-code.d.ts", "$dir/hooks", "$dir/types"] }
EOF
if command -v tsc >/dev/null; then tsc -p "$w/tsconfig.json" 2>&1 | sed "s#.*/$name/##" | head -20; else npx -y -p typescript@5 tsc -p "$w/tsconfig.json" 2>&1 | sed "s#.*/$name/##" | head -20; fi
echo "   tsc done"
rm -rf "$w"
echo "3. remember: a variable named h, on or \$ breaks the mod; functions taking \$ must be top-level"
grep -nE '\b(const|let|var) (h|on)\b|\(h\)|\bh =>' "$dir"/hooks/*.tsx 2>/dev/null | sed 's/^/   WARN /' || true
