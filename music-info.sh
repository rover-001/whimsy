#!/usr/bin/env sh
# whimsy music-info helper.
# Resolves the first MPRIS player on the session bus and prints TSV:
#   title\tartist\tplaying(0/1)\tposition_sec\tduration_sec
# Safe to run at any time (no player => zeroed row).

player="$(
  gdbus call --session --dest org.freedesktop.DBus \
    --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.ListNames 2>/dev/null \
  | tr ',' '\n' | sed -n 's/.*\(org\.mpris\.MediaPlayer2[^'"'"',]*\).*/\1/p' \
  | head -n1
)"

out_title=""
out_artist=""
out_playing="0"
out_pos="0"
out_len="0"

if [ -n "$player" ]; then
  meta="$(
    gdbus call --session --dest "$player" \
      --object-path /org/mpris/MediaPlayer2 \
      --method org.freedesktop.DBus.Properties.Get \
      org.mpris.MediaPlayer2.Player Metadata 2>/dev/null
  )"
  status="$(
    gdbus call --session --dest "$player" \
      --object-path /org/mpris/MediaPlayer2 \
      --method org.freedesktop.DBus.Properties.Get \
      org.mpris.MediaPlayer2.Player PlaybackStatus 2>/dev/null
  )"
  position="$(
    gdbus call --session --dest "$player" \
      --object-path /org/mpris/MediaPlayer2 \
      --method org.freedesktop.DBus.Properties.Get \
      org.mpris.MediaPlayer2.Player Position 2>/dev/null
  )"

  out_title=$(printf '%s' "$meta" | sed -n "s/.*'xesam:title': <'\([^']*\)'>.*/\1/p")
  out_artist=$(printf '%s' "$meta" | sed -n "s/.*'xesam:artist': <\['\([^']*\)'\].*/\1/p")
  [ -z "$out_artist" ] \
    && out_artist=$(printf '%s' "$meta" | sed -n "s/.*'xesam:artist': <'\([^']*\)'>.*/\1/p")

  len=$(printf '%s' "$meta" | sed -n "s/.*'mpris:length': <int64 \([0-9]*\)>.*/\1/p")

  pos=$(printf '%s' "$position" | sed -n "s/.*int64 \([0-9]*\).*/\1/p")

  [ -n "$len" ] && out_len=$(awk -v v="$len" 'BEGIN { printf "%.0f", v / 1000000 }')
  [ -n "$pos" ] && out_pos=$(awk -v v="$pos" 'BEGIN { printf "%.0f", v / 1000000 }')
  case "$status" in
    *"'Playing'"*) out_playing="1" ;;
    *) out_playing="0" ;;
  esac
fi

printf '%s\t%s\t%s\t%s\t%s\n' \
  "$out_title" "$out_artist" "$out_playing" "$out_pos" "$out_len"