#!/bin/sh
# Publishes a mod: git init (if needed), commit everything, create the public GitHub repo <owner>/<name>
# (if missing) and push. Needs the GitHub CLI (gh) logged in. Usage: publish.sh <name> ["commit message"]
set -eu
name=${1:?usage: publish.sh <name> ["message"]}
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
dir="$MODS/$name"
[ -d "$dir" ] || { echo "no mod at $dir"; exit 1; }
command -v gh >/dev/null || { echo "install and log in to the GitHub CLI first: brew install gh && gh auth login"; exit 1; }
who=$(owner)
cd "$dir"
v=$(jq -r .version .claude-plugin/plugin.json)
msg=${2:-"$name $v"}
# commits carry your git identity; without one, your GitHub login and its noreply address
if [ -z "$(git config user.email 2>/dev/null || true)" ]; then
  export GIT_AUTHOR_NAME="$who" GIT_COMMITTER_NAME="$who"
  export GIT_AUTHOR_EMAIL="$who@users.noreply.github.com" GIT_COMMITTER_EMAIL="$who@users.noreply.github.com"
fi
[ -d .git ] || git init -q -b main
git add -A
if git diff --cached --name-only | grep -Ei 'types/claude-code|node_modules|\.env|secret'; then echo "refusing: generated or secret files staged"; exit 1; fi
git diff --cached --quiet || git commit -q -m "$msg"
if gh repo view "$who/$name" >/dev/null 2>&1; then
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$who/$name.git"
  git push -q -u origin main
else
  gh repo create "$who/$name" --public --description "$(jq -r .description .claude-plugin/plugin.json | cut -c1-300)" --source . --remote origin --push
fi
echo "https://github.com/$who/$name  ($v)"
echo "install: claude plugin marketplace add $who/$name && claude plugin install $name@$name"
