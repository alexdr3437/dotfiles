#!/usr/bin/env sh
# Lint for this directory. Run it after editing anything:   ~/.config/mango/check.sh
#   1. shellcheck (warning level) on every script
#   2. every defpoll/deflisten `:initial` in eww/eww.yuck has the same top-level keys as the
#      live output of its script: a field added to one but not the other breaks the popup
#      silently while the first poll is pending
# Exit status is non-zero if anything is off.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
rc=0

if command -v shellcheck >/dev/null; then
  (cd "$dir" && shellcheck -x -s sh -S warning ./*.sh) || rc=1   # -x: follow the lib.sh source
else
  echo "shellcheck not installed, skipping (nix shell nixpkgs#shellcheck -c $0)" >&2
fi

# (defpoll NAME ... :initial 'JSON' "~/.config/mango/X.sh status")
drift=$(grep -E '^\(def(poll|listen) ' "$dir/eww/eww.yuck" | while IFS= read -r line; do
  name=$(printf '%s' "$line" | awk '{print $2}')
  initial=$(printf '%s' "$line" | sed -n "s/.*:initial '\([^']*\)'.*/\1/p")
  cmd=$(printf '%s' "$line" | sed -n 's/.*"\([^"]*\)")[[:space:]]*$/\1/p' | sed "s|^~|$HOME|")
  case "$cmd" in *" stream") cmd="${cmd% stream} status" ;; esac   # deflisten → its one-shot form
  want=$(printf '%s' "$initial" | jq -c 'if type == "object" then keys else type end')
  got=$(sh -c "$cmd" 2>/dev/null | jq -c 'if type == "object" then keys else type end')
  [ "$want" = "[]" ] && continue   # initial '{}': keys are dynamic (taskbar)
  [ "$want" = "$got" ] || echo "eww.yuck: $name :initial has $want but \`$cmd\` gives $got"
done)
[ -z "$drift" ] || { echo "$drift"; rc=1; }

[ $rc -eq 0 ] && echo "ok"
exit $rc
