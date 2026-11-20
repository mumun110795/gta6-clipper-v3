#!/usr/bin/env bash
# Build clip.mp4 — a ~25 s vertical (1080x1920) GTA 6 Short for the
# make.fun gta6-clipper-01 bounty, cut from Rockstar's official
# Grand Theft Auto VI Trailer 2 (YouTube VQRLujxTm3c, Rockstar Games).
#
# Edit decision list (all times are seconds in the trailer; crop-x values
# were set by measuring the subject position in full-res frames):
#   #  src start  dur   crop-x  moment / overlay
#   1    63.80    2.10    430   Lucia walks out of the prison gate toward
#                               the camera -> HOOK text "SHE'S FINALLY OUT /
#                               LUCIA WALKS FREE"
#   2    50.05    1.80   1000   the prison watchtower -> LEONIDA STATE PEN
#   3    66.30    2.40    936   Jason waiting for her in the lot ->
#                               HE WAITED FOR HER
#   4    11.30    2.00    470   Jason fixing the roof, ocean behind ->
#                               LIFE IN THE KEYS
#   5    34.60    3.00    656   first-person highway drive, airliner crossing
#                               overhead -> VICE CITY AHEAD
#   6    38.30    2.60    780   beach-gym bench press -> MUSCLE BEACH ENERGY
#   7    81.40    1.60    950   golden-hour marina, boat + couple on the dock
#                               -> mid-clip pitch band
#   8    83.00    1.90    656   sunset pier silhouette -> GOLDEN HOUR IN LEONIDA
#   9   121.00    1.60    656   night street, pickup pulling away in sparks ->
#                               THE CITY NEVER SLEEPS
#  10   158.20    6.10     —    VI logo card, letterboxed whole so the logo is
#                               never cropped -> end-card pitch lines (staggered)
# The mid-clip pitch band sits at ~56-62% of the runtime (segment 7).
# Audio is each segment's own trailer audio; the joined cut is loudness
# normalised to about -14 LUFS and faded out at the end.
#
# Usage: ./build_clip.sh            (expects trailer2.mp4 next to this script)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p work/segments work/overlays

SRC=trailer2.mp4
if [ ! -f "$SRC" ]; then
  # Guarded download step: fetch the official Trailer 2 from Rockstar Games.
  YTDLP="$(command -v yt-dlp || echo /tmp/yt-dlp)"
  "$YTDLP" --no-playlist -f 'bv*[height<=1080]+ba/b[height<=1080]' \
    --merge-output-format mp4 -o "$SRC" \
    'https://www.youtube.com/watch?v=VQRLujxTm3c'
fi

python3 make_overlays.py

OV=work/overlays
VENC="-c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r 30"
AENC="-c:a aac -b:a 160k -ar 48000"

# seg <n> <start> <dur> <cropx> <overlay-filter-chain...>
seg() {
  local n="$1" start="$2" dur="$3" cropx="$4"; shift 4
  local inputs=(-i "$SRC") chain="[0:v]crop=608:1080:${cropx}:0,scale=1080:1920:flags=lanczos,fps=30[v0]"
  local i=1 prev="v0"
  for spec in "$@"; do
    local png="${spec%%|*}" en="${spec#*|}"
    inputs+=(-i "$OV/$png")
    if [ "$en" = "full" ]; then
      chain+=";[${prev}][${i}:v]overlay=0:0[v${i}]"
    else
      chain+=";[${prev}][${i}:v]overlay=0:0:enable='${en}'[v${i}]"
    fi
    prev="v${i}"; i=$((i+1))
  done
  ffmpeg -v error -y -ss "$start" -t "$dur" "${inputs[@]}" \
    -filter_complex "$chain" -map "[${prev}]" -map 0:a $VENC $AENC \
    "work/segments/seg$(printf %02d "$n").mp4"
  echo "segment $n done"
}

seg 1  63.80 2.10  430 "ov_hook.png|full"
seg 2  50.05 1.80 1000 "ov_cap_tower.png|full"
seg 3  66.30 2.40  936 "ov_cap_wait.png|full"
seg 4  11.30 2.00  470 "ov_cap_roof.png|full"
seg 5  34.60 3.00  656 "ov_cap_highway.png|full"
seg 6  38.30 2.60  780 "ov_cap_gym.png|full"
seg 7  81.40 1.60  950 "ov_midpitch.png|full"
seg 8  83.00 1.90  656 "ov_cap_pier.png|full"
seg 9 121.00 1.60  656 "ov_cap_night.png|full"

# Segment 10: the VI logo card letterboxed whole (1080x608 centred), with
# the three pitch lines staggered into the black below it.
ffmpeg -v error -y -ss 158.20 -t 6.10 -i "$SRC" \
  -i "$OV/ov_end1.png" -i "$OV/ov_end2.png" -i "$OV/ov_end3.png" \
  -filter_complex "[0:v]scale=1080:608:flags=lanczos,pad=1080:1920:0:656:black,fps=30[v0];[v0][1:v]overlay=0:0:enable='between(t,0.40,6.10)'[v1];[v1][2:v]overlay=0:0:enable='between(t,2.20,6.10)'[v2];[v2][3:v]overlay=0:0:enable='between(t,4.00,6.10)'[v3]" \
  -map "[v3]" -map 0:a $VENC $AENC work/segments/seg10.mp4
echo "segment 10 done"

# Join the segments, normalise loudness to ~-14 LUFS, fade out, faststart.
LIST=work/segments/list.txt
: > "$LIST"
for f in work/segments/seg*.mp4; do echo "file '$(basename "$f")'" >> "$LIST"; done
ffmpeg -v error -y -f concat -safe 0 -i "$LIST" \
  -af "loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000,afade=t=out:st=24.3:d=0.8" \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 160k -movflags +faststart clip.mp4
echo "built clip.mp4"
