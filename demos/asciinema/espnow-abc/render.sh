#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

CAST="$ROOT/demos/asciinema/espnow-abc/espnow-abc.cast"
OUTDIR="$ROOT/demos/asciinema/espnow-abc/render"
mkdir -p "$OUTDIR"

THEME="${THEME:-dracula}"
FPS_CAP="${FPS_CAP:-30}"
FPS_OUT="${FPS_OUT:-30}"

if ! command -v agg >/dev/null 2>&1; then
  echo "agg is required (https://docs.asciinema.org/manual/agg/usage/)"
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required to generate mp4 outputs"
  exit 1
fi

echo "cast: $CAST"
echo "theme: $THEME"
echo "fps cap: $FPS_CAP"
echo "fps out: $FPS_OUT"

# agg's --last-frame-duration sets the last frame duration (it does not add).
# To hit exact target lengths we compute the "base without last frame" duration
# once using a calibration render.
CAL_GIF="$(mktemp --suffix=.gif)"
CAL_LAST=1.000
agg --theme "$THEME" --fps-cap "$FPS_CAP" --idle-time-limit 1 --last-frame-duration "$CAL_LAST" "$CAST" "$CAL_GIF" >/dev/null
CAL_TOTAL="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$CAL_GIF")"
rm -f "$CAL_GIF"

BASE_NO_LAST="$(python3 - <<PY
total=float("$CAL_TOTAL")
last=float("$CAL_LAST")
print(f"{max(0.0, total-last):.3f}")
PY
)"

echo "base without last frame: ${BASE_NO_LAST}s"

render_one() {
  local target="$1"
  local last
  last="$(python3 - <<PY
base=float("$BASE_NO_LAST")
target=float("$target")
last=max(0.1, target-base)
print(f"{last:.3f}")
PY
)"

  local gif="$OUTDIR/espnow-abc-${target}s-${THEME}.gif"
  local mp4="$OUTDIR/espnow-abc-${target}s-${THEME}.mp4"

  echo "== render ${target}s (last frame ${last}s) =="
  agg \
    --theme "$THEME" \
    --fps-cap "$FPS_CAP" \
    --idle-time-limit 1 \
    --last-frame-duration "$last" \
    "$CAST" \
    "$gif"

  # MP4 generation:
  # - render an "animated intro" segment (short, readable)
  # - then append a "still hold" segment (portable long-duration video without huge encode cost)
  local intro
  intro="$(python3 - <<PY
target=float("$target")
intro=min(10.0, target)
print(f"{intro:.3f}")
PY
)"
  local hold
  hold="$(python3 - <<PY
target=float("$target")
intro=float("$intro")
hold=max(0.0, target-intro)
print(f"{hold:.3f}")
PY
)"

  local still_png="$OUTDIR/.last-${target}s.png"
  local intro_mp4="$OUTDIR/.intro-${target}s.mp4"
  local hold_mp4="$OUTDIR/.hold-${target}s.mp4"

  # Extract last frame (for the hold segment).
  frames="$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nk=1:nw=1 "$gif")"
  last_idx="$((frames-1))"
  ffmpeg -y -hide_banner -loglevel error \
    -i "$gif" \
    -vf "select=eq(n\\,${last_idx})" \
    -vsync 0 \
    -frames:v 1 \
    "$still_png"

  # Intro: re-time to constant FPS for portability; duration is clamped to $intro.
  ffmpeg -y -hide_banner -loglevel error \
    -i "$gif" \
    -t "$intro" \
    -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=${FPS_OUT}" \
    -an \
    -c:v libx264 -preset veryfast -crf 23 \
    -pix_fmt yuv420p \
    "$intro_mp4"

  # Hold: loop a single frame for $hold seconds; use lower FPS for very long holds unless overridden.
  local hold_fps="$FPS_OUT"
  if python3 - <<PY | grep -q true
hold=float("$hold")
print(str(hold > 60.0).lower())
PY
  then
    if [ -z "${FPS_OUT_OVERRIDE:-}" ]; then
      hold_fps=15
    fi
  fi

  if python3 - <<PY | grep -q true
hold=float("$hold")
print(str(hold > 0.0).lower())
PY
  then
    ffmpeg -y -hide_banner -loglevel error \
      -loop 1 -i "$still_png" \
      -t "$hold" \
      -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=${hold_fps}" \
      -an \
      -c:v libx264 -preset ultrafast -crf 28 \
      -pix_fmt yuv420p \
      "$hold_mp4"

    ffmpeg -y -hide_banner -loglevel error \
      -i "$intro_mp4" -i "$hold_mp4" \
      -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p[v]" \
      -map "[v]" \
      -movflags +faststart \
      -c:v libx264 -preset veryfast -crf 23 \
      "$mp4"
  else
    mv "$intro_mp4" "$mp4"
  fi

  rm -f "$still_png" "$intro_mp4" "$hold_mp4"

  echo "wrote: $gif"
  echo "wrote: $mp4"
  echo "gif duration: $(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$gif")"
  echo "mp4 duration: $(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$mp4")"
}

render_one 15
render_one 30
render_one 60
render_one 300

ls -lh "$OUTDIR" | sed -n '1,200p'
