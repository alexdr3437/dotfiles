#!/usr/bin/env sh
# Removable drives: the "Mount and open" notification Plasma's device notifier had.
#   drives.sh watch             → daemon (autostart.sh): every udev block "add" event runs `added`
#   drives.sh added NAME        → if /dev/NAME is a removable / hotplug filesystem that is not
#                                 mounted, notify with two buttons: "Mount and open", "Mount"
#   drives.sh mount NAME [open] → mount /dev/NAME through udisks (polkit decides whether to ask;
#                                 removable media needs no password), print the mount point,
#                                 with `open` show it in Dolphin
# Nothing auto-mounts: the notification is the prompt. Dolphin's Places panel is the other
# way in, and the way out (eject). udisks picks the mount point (/run/media/$USER/<label>).
# shellcheck source=lib.sh
. "$HOME/.config/mango/lib.sh"

notify() { notify-send -a drives -i drive-removable-media "$@"; }

# mount NAME [open]
mount_dev() {
  out=$(run udisksctl mount -b "/dev/$1" 2>&1) || { notify "Could not mount /dev/$1" "$out"; exit 1; }
  mp=$(lsblk -no MOUNTPOINT "/dev/$1" | head -1)
  echo "$mp"
  [ "$2" = open ] && [ -n "$mp" ] && "$dir/async.sh" dolphin "$mp"
}

# added NAME: decide whether /dev/NAME is worth a notification, then wait for the answer
added() {
  j=$(lsblk -J -o FSTYPE,LABEL,SIZE,RM,HOTPLUG,MOUNTPOINT "/dev/$1" 2>/dev/null | jq -c '.blockdevices[0] // empty')
  [ -n "$j" ] || exit 0
  eval "$(printf '%s' "$j" | jq -r '@sh "fstype=\(.fstype // "") label=\(.label // "") size=\(.size // "") rm=\(.rm | tostring) hotplug=\(.hotplug | tostring) mp=\(.mountpoint // "")"')"
  [ -z "$mp" ] || exit 0                                   # fstab or something else mounted it
  [ "$rm" = true ] || [ "$hotplug" = true ] || exit 0      # internal disks are never "plugged in"
  case "$fstype" in ""|swap|*_member|crypto_LUKS) exit 0 ;; esac   # no filesystem to mount
  title="${label:-Removable drive} ($size)"
  # -A implies --wait: notify-send prints the chosen button's name when the user clicks one
  case $(notify -A open="Mount and open" -A mount="Mount" "$title" "$fstype on /dev/$1") in
    open) mount_dev "$1" open ;;
    mount) mount_dev "$1" ;;
  esac
}

# watch: one `added` per udev add event, in the background so a pending notification
# never blocks the next drive. Lines look like:  UDEV  [123.456] add  /devices/…/sdb1 (block)
watch() {
  udevadm monitor --udev -s block | while read -r _ _ action devpath _; do
    [ "$action" = add ] || continue
    "$dir/drives.sh" added "$(basename "$devpath")" &
  done
}

case "$1" in
  watch) watch ;;
  added) [ -n "$2" ] || usage "added NAME"; added "$2" ;;
  mount) [ -n "$2" ] || usage "mount NAME [open]"; mount_dev "$2" "$3" ;;
  *) usage "watch | added NAME | mount NAME [open]" ;;
esac
