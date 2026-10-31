#!/usr/bin/env sh
# Command palette (Super+Shift+p): every bind in config.conf plus a few unbound mango actions,
# in a fuzzy rofi menu. Rows show "label · description · keys"; matching also covers the raw
# action name, so typing `togglefloating` or `float` both find "float window".
#   palette.sh pick    → open the menu and run the choice (spawn → detached shell, else mmsg dispatch)
#   palette.sh list    → the command table (kind, command, label, description, keys), for tests
# Descriptions live in describe() below; an action without one still gets a row.
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"
conf="$dir/config.conf"
tab="$(printf '\t')"

dir() { case "$1" in +0,-*) echo up ;; +0,+*) echo down ;; -*,+0) echo left ;; *) echo right ;; esac; }   # "dx,dy" → direction

# action [args] → "label|description"
describe() {
  a=$1; arg=${2%%,*}   # first argument; movewin/resizewin read both
  case "$a" in
    view) echo "go to tag $arg|show tag $arg on this monitor" ;;
    tag) echo "move window to tag $arg|send the focused window to tag $arg and follow it" ;;
    tagsilent) echo "move window to tag $arg, stay|send the focused window to tag $arg without following" ;;
    viewtoleft) echo "previous tag|go one tag left, empty tags included" ;;
    viewtoright) echo "next tag|go one tag right, empty tags included" ;;
    viewtoleft_have_client) echo "previous tag with windows|go left to the nearest tag that has windows" ;;
    viewtoright_have_client) echo "next tag with windows|go right to the nearest tag that has windows" ;;
    tagtoleft) echo "move window to previous tag|send the focused window one tag left and follow" ;;
    tagtoright) echo "move window to next tag|send the focused window one tag right and follow" ;;
    focusdir) echo "focus $arg|focus the window in that direction" ;;
    focusstack) echo "focus $arg window|cycle focus through the stack" ;;
    focuslast) echo "focus last window|jump back to the previously focused window" ;;
    focusmon) echo "focus monitor $arg|move focus to the monitor in that direction" ;;
    move_client) echo "move window $arg|swap the focused window with its $arg neighbour" ;;
    tagmon) echo "move window to monitor $arg|send the focused window to the monitor in that direction" ;;
    movewin) echo "nudge floating window $(dir "$2")|move a floating window by 50px" ;;
    resizewin) echo "$(case $(dir "$2") in up|left) echo shrink;; *) echo grow;; esac) floating window $(dir "$2")|resize a floating window by 50px" ;;
    centerwin) echo "centre window|centre the focused floating window" ;;
    zoom) echo "make window master|swap the focused window into the master slot" ;;
    incnmaster) echo "$([ "${arg#-}" = "$arg" ] && echo "one more master" || echo "one less master")|change how many windows share the master area" ;;
    setmfact) echo "$([ "${arg#-}" = "$arg" ] && echo "master wider" || echo "master narrower")|resize the master area by 5%" ;;
    togglefloating) echo "float window|toggle the focused window between tiled and floating" ;;
    toggle_all_floating) echo "float all windows|toggle every window on this tag between tiled and floating" ;;
    togglefullscreen) echo "fullscreen|toggle real fullscreen for the focused window" ;;
    togglefakefullscreen) echo "fake fullscreen|fullscreen for the app, but kept inside the layout" ;;
    togglemaximizescreen) echo "maximize|toggle filling the whole tag area with the focused window" ;;
    toggleglobal) echo "pin to all tags|toggle showing the focused window on every tag" ;;
    toggleoverlay) echo "overlay|toggle keeping the focused window floating above everything" ;;
    togglejump) echo "jump to window|show a hint on each window, press its key to focus it" ;;
    minimized) echo "minimize window|hide the focused window; click it in the taskbar or restore to bring it back" ;;
    restore_minimized) echo "restore minimized window|bring back the most recently minimized window, tiled" ;;
    toggle_scratchpad) echo "scratchpad|hide the focused window, or show the hidden one again, floating" ;;
    killclient) echo "close window|close the focused window" ;;
    switch_layout) echo "next layout|cycle to the next layout on this tag" ;;
    setlayout) echo "layout: $arg|set this tag's layout to $arg" ;;
    enteroverview) echo "overview|show every window on this monitor at once" ;;
    toggleoverview) echo "overview|toggle showing every window on this monitor at once" ;;
    set_proportion) echo "scroller: full width|make the focused column fill the screen" ;;
    switch_proportion_preset) echo "scroller: cycle width|cycle the focused column through the width presets" ;;
    scroller_stack) echo "scroller: stack $arg|stack the focused window into the $arg column" ;;
    dwindle_toggle_split_direction) echo "dwindle: flip split|flip the split direction for the next window" ;;
    incgaps) echo "$([ "${arg#-}" = "$arg" ] && echo "gaps bigger" || echo "gaps smaller")|change the gap between windows by 1px" ;;
    togglegaps) echo "toggle gaps|turn the gaps between windows on or off" ;;
    reload_config) echo "reload mango config|re-read config.conf now" ;;
    exchange_client) echo "swap window $arg|exchange the focused window with the one in that direction" ;;
    toggle_render_border) echo "toggle borders|turn window borders on or off" ;;
    *) echo "$a${arg:+ $arg}|" ;;
  esac
}

# spawn command → "label|description"
describe_spawn() {
  case "$1" in
    *rofi*drun*) echo "launch app|rofi app launcher" ;;
    ghostty) echo "terminal|open a new ghostty window" ;;
    */lock.sh*) echo "lock screen|lock now" ;;
    */vol.sh\ up) echo "volume up|" ;;
    */vol.sh\ down) echo "volume down|" ;;
    */vol.sh\ mute) echo "mute|toggle speaker mute" ;;
    *DEFAULT_AUDIO_SOURCE*) echo "mute microphone|toggle microphone mute" ;;
    */media.sh\ playpause*) echo "play / pause|media player" ;;
    */media.sh\ next*) echo "next track|media player" ;;
    */media.sh\ prev*) echo "previous track|media player" ;;
    *brightnessctl*5%+*) echo "brightness up|" ;;
    *brightnessctl*5%-*) echo "brightness down|" ;;
    */popup.sh\ close*) echo "close popups|close any open bar popup" ;;
    */layout.sh\ pick*) echo "pick layout…|fuzzy menu of every layout for this tag" ;;
    */palette.sh*) return 1 ;;   # not itself
    *) echo "run: $(basename "${1%% *}")|$1" ;;
  esac
}

keys() {   # "SUPER+SHIFT,Tab" → "Super+Shift+Tab"
  printf '%s+%s' "$1" "$2" | sed -e 's/^NONE+//I' -e 's/^none+//' \
    -e 's/SUPER/Super/Ig; s/SHIFT/Shift/Ig; s/CTRL/Ctrl/Ig; s/ALT/Alt/Ig' \
    -e 's/Return/Enter/; s/backslash/\\/; s/XF86//; s/Audio//; s/Mon//'
}

# kind TAB command TAB label TAB description TAB keys   (binds in config order, then extras)
commands() {
  sed -n 's/^bind=//p' "$conf" | sed 's/[[:space:]]*#.*$//' | while IFS=, read -r mods key action rest; do
    rest=${rest%%,}                              # `toggleglobal,` has an empty trailing arg
    k=$(keys "$mods" "$key")
    if [ "$action" = spawn ]; then
      ld=$(describe_spawn "$rest") || continue
      printf 'spawn\t%s\t%s\t%s\t%s\n' "$rest" "${ld%%|*}" "${ld#*|}" "$k"
    else
      ld=$(describe "$action" "$rest")
      printf 'dispatch\t%s\t%s\t%s\t%s\n' "$action${rest:+,$rest}" "${ld%%|*}" "${ld#*|}" "$k"
    fi
  done
  for extra in zoom focuslast centerwin enteroverview toggle_all_floating toggle_render_border \
               incnmaster,1 incnmaster,-1 setmfact,+0.05 setmfact,-0.05 \
               exchange_client,left exchange_client,right exchange_client,up exchange_client,down; do
    action=${extra%%,*}; arg=${extra#"$action"}; arg=${arg#,}
    ld=$(describe "$action" "$arg")
    printf 'dispatch\t%s\t%s\t%s\t\n' "$extra" "${ld%%|*}" "${ld#*|}"
  done
}

esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

# rofi rows: shown column = "label  desc  keys" (markup), hidden column = raw command for matching
rows() {
  commands | while IFS="$tab" read -r kind cmd label desc k; do
    printf '<b>%s</b>%s%s\t%s\n' "$(printf '%s' "$label" | esc)" \
      "${desc:+  <span alpha=\"55%\">$(printf '%s' "$desc" | esc)</span>}" \
      "${k:+  <span alpha=\"40%\">$k</span>}" "$cmd"
  done
}

pick() {
  idx=$(rows | rofi -dmenu -i -matching fuzzy -sort -sorting-method fzf -markup-rows -p "run" -format i \
          -display-columns 1 -display-column-separator "$tab" -theme "$dir/rofi.rasi" \
          -theme-str 'listview { lines: 14; } window { width: 1000px; } element-text { font: "FiraCode Nerd Font 13"; }') || exit 0
  line=$(commands | sed -n "$((idx + 1))p"); [ -n "$line" ] || exit 0
  kind=${line%%"$tab"*}; cmd=${line#*"$tab"}; cmd=${cmd%%"$tab"*}
  case "$kind" in
    spawn) setsid -f sh -c "$cmd" >/dev/null 2>&1 </dev/null ;;
    dispatch) mmsg dispatch "$cmd" >/dev/null ;;
  esac
}

case "$1" in
  pick) pick ;;
  list) commands ;;
  rows) rows ;;
  *) usage "pick|list|rows" ;;
esac
