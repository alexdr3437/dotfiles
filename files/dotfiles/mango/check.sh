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
  (cd "$dir" && shellcheck -x -s sh -S warning ./*.sh ./hosts/*/env.sh) || rc=1   # -x: follow the lib.sh source
else
  echo "shellcheck not installed, skipping (nix shell nixpkgs#shellcheck -c $0)" >&2
fi

# ~/.config/mango-host → hosts/<host> (home/mango.nix). config.conf sources it with
# source_optional and lib.sh tolerates its absence, so a missing link is silent otherwise.
if [ ! -d "$host_dir" ]; then
  echo "$host_dir is missing: rebuild (home/mango.nix links it) or ln -s $dir/hosts/<host> $host_dir"; rc=1
else
  for f in mango.conf env.sh waybar.jsonc; do
    [ -r "$host_dir/$f" ] || { echo "$host_dir/$f is missing"; rc=1; }
  done
  # -p exits non-zero for errors in the file it is given but not for errors inside a
  # source'd file, so check the host file on its own as well
  if command -v mango >/dev/null; then
    for f in "$dir/config.conf" "$host_dir/mango.conf"; do
      mango -c "$f" -p >/dev/null 2>&1 || { echo "mango -c $f -p: does not parse"; rc=1; }
    done
  fi
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
