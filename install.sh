#!/bin/bash
# Night Run bar:
#   left/centre: ignition key (with engine sound), gearbox workspaces, police radio, rear-view mirror clock
#   right:       dashboard lights (WiFi / Bluetooth / mic), HEAT stars, CPU tachometer,
#                uptime odometer. The fuel gauge replaces the battery icon of Omarchy's own power
#                widget (patched modules/Panel.qml), so its panel keeps working.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
dest="$HOME/.config/omarchy/bar/modules"
sounds="$HOME/.config/omarchy/bar/sounds"
cfg="$HOME/.config/omarchy/shell.json"

command -v jq >/dev/null || { echo "jq is required (sudo pacman -S jq)"; exit 1; }

mkdir -p "$dest"
cp "$here"/modules/nfs-*.qml "$dest/"
echo "Modules copied to $dest"

mkdir -p "$sounds"
cp "$here"/sounds/*.wav "$sounds/"
echo "Sounds copied to $sounds"

# If you never customised the bar there is no shell.json yet: start from Omarchy's default.
if [[ ! -f $cfg ]]; then
  for d in "$HOME/.local/share/omarchy/config/omarchy/shell.json" /usr/share/omarchy/config/omarchy/shell.json; do
    if [[ -f $d ]]; then cp "$d" "$cfg"; break; fi
  done
fi
[[ -f $cfg ]] || { echo "No shell.json found. Run 'omarchy bar defaults' and try again."; exit 1; }

# ---- Patch Omarchy's own widgets so their bar icons are replaced in place ----
# Each widget's panel lives inside the widget, so the widget has to stay in the bar.
roots=${NR_SHARE_DIRS:-"$HOME/.local/share/omarchy /usr/share/omarchy"}

find_panel() {   # $1 = plugin folder name (power | network | bluetooth | audio | agents)
  local root f
  for root in $roots; do
    [[ -d $root ]] || continue
    while IFS= read -r f; do
      if [[ $1 == agents ]]; then
        # Not documented anywhere I could read: take the .qml of that plugin that holds the bar button
        grep -q 'BarIconButton' "$f" && { echo "$f"; return; }
      elif [[ $(basename "$f") == Panel.qml && -f $(dirname "$f")/Model.js ]]; then echo "$f"; return; fi
    done < <(find "$root" -path "*/$1/*.qml" 2>/dev/null | sort)
  done
}

install_panel() {   # $1 = destination Panel.qml, $2 = new file. Uses sudo when the file is root's.
  local dst="$1" new="$2" SUDO=""
  [[ -w $dst ]] || SUDO="sudo"
  [[ -z $SUDO ]] || echo "Patching $dst needs root (sudo will ask for your password)."
  if cmp -s "$new" "$dst"; then return 0; fi
  [[ -f $dst.orig-nightrun ]] || $SUDO cp "$dst" "$dst.orig-nightrun" || true
  $SUDO cp "$new" "$dst"
}

patched=no       # battery
patched_wifi=no
patched_bt=no
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Battery: the fuel gauge (modules/Panel.qml is a ready-made power widget)
panel_dst="$(find_panel power)"
if [[ -n $panel_dst ]]; then
  if install_panel "$panel_dst" "$here/modules/Panel.qml"; then
    patched=yes
    echo "Battery icon replaced in $panel_dst  (original: $panel_dst.orig-nightrun)"
  else
    echo "Could not write $panel_dst."
  fi
else
  echo "Omarchy's power widget (Panel.qml) was not found: using the standalone nfs-fuel module instead."
fi

# WiFi / Bluetooth / volume / agents: dashboard lamps, generated from your installed Panel.qml
if command -v python3 >/dev/null; then
  for kind in network bluetooth audio agents; do
    dst="$(find_panel "$kind")"
    if [[ -z $dst ]]; then echo "Omarchy's $kind widget not found: skipped."; continue; fi
    if python3 -I "$here/tools/patch_panel.py" "$kind" "$dst" "$tmp/$kind.qml" && install_panel "$dst" "$tmp/$kind.qml"; then
      echo "$kind icon replaced in $dst  (original: $dst.orig-nightrun)"
      if [[ $kind == network ]]; then patched_wifi=yes; else patched_bt=yes; fi
    else
      echo "$kind widget NOT patched (kept the original icon)."
    fi
  done
else
  echo "python3 not found: WiFi / Bluetooth icons left as they were."
fi
echo "(A system update of Omarchy may restore the original widgets: just run ./install.sh again.)"

# The dashboard keeps only the lights Omarchy does not draw by itself
l=()
[[ $patched_wifi == yes ]] || l+=('"wifi"')
[[ $patched_bt == yes ]] || l+=('"bt"')
l+=('"mic"')
lights="[$(IFS=,; echo "${l[*]}")]"

cp "$cfg" "$cfg.bak-nightrun"
jq --arg patched "$patched" --argjson lights "$lights" '
  def eid: if type == "object" then .id else . end;
  def mk($id): {id: $id, type: "qml"};
  def swap($old; $new): map(if eid == $old then mk($new) else . end);
  # Give a built-in widget its slot back (plain entry, no "type")
  def restore($old; $new): map(if eid == $old then {id: $new} else . end);
  def after($anchor; $new):
    map(select(eid != $new)) | [ .[] | ., (if eid == $anchor then mk($new) else empty end) ];
  # Append at the end unless it is already there (keeps any settings you added to the entry)
  def ensure($new): if any(.[]; eid == $new) then . else . + [mk($new)] end;
  def setlights: map(if eid == "nfs-dash" then (if type == "object" then . else {id: "nfs-dash", type: "qml"} end) + {lights: $lights} else . end);
  .version //= 1
  | (any(.bar.layout[]?; type == "array" and any(.[]; eid == "omarchy.power"))) as $hasPower
  | if (.bar.layout | type) == "object" then
      .bar.layout |= with_entries(.value |= (
        if type == "array" then
          # Re-running after an earlier install: drop the gauge appended at the end, it goes where the power module is
          (if $patched == "yes" then (if $hasPower then map(select(eid != "nfs-fuel")) else restore("nfs-fuel"; "omarchy.power") end)
           elif $hasPower then map(select(eid != "nfs-fuel")) else . end)
          | swap("omarchy.menu"; "nfs-ignition")
          | swap("omarchy.workspaces"; "nfs-gears")
          | swap("omarchy.clock"; "nfs-mirror")
          | (if $patched == "yes" then . else swap("omarchy.power"; "nfs-fuel") end)
          | after("nfs-gears"; "nfs-radio")
          | setlights
        else . end))
      # New instruments go at the end of the right-hand group
      | (if (.bar.layout | has("right")) then "right" else (.bar.layout | keys_unsorted | last) end) as $side
      | if (.bar.layout[$side] | type) == "array" then
          .bar.layout[$side] |= (
            ensure("nfs-dash") | ensure("nfs-heat") | ensure("nfs-tacho")
            | ensure("nfs-odometer"))
        # Standalone fallback only: if there was no power widget to replace, add the gauge at the end
        | (if $patched == "yes" or any(.bar.layout[]?; type == "array" and any(.[]; eid == "nfs-fuel")) then . else
            .bar.layout[$side] |= ensure("nfs-fuel") end)
        else . end
    else . end
' "$cfg.bak-nightrun" > "$cfg"

echo "Layout updated. Backup: $cfg.bak-nightrun"
echo "If the bar does not change by itself, log out and back in."
echo "To undo: cp \"$cfg.bak-nightrun\" \"$cfg\"   (or: omarchy bar defaults)"
