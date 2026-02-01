#!/usr/bin/env bash
set -e

IN_PLACE=false

# Parse arguments
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --in-place)
      IN_PLACE=true
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL[@]}"

INPUT_DIR="$1"
OUTPUT_DIR="$2"

# Check input
if [[ -z "$INPUT_DIR" ]]; then
  echo "Usage: $0 [--in-place] <input_dir> [output_dir]"
  exit 1
fi

# Output dir logic
if [[ "$IN_PLACE" == true ]]; then
  OUTPUT_DIR="$INPUT_DIR"
elif [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$INPUT_DIR/normalized"
fi

mkdir -p "$OUTPUT_DIR"

shopt -s nullglob

for INPUT_FILE in "$INPUT_DIR"/*.ogg; do
  FILENAME=$(basename "$INPUT_FILE")
  BASENAME="${FILENAME%.ogg}"

  if [[ "$IN_PLACE" == true ]]; then
    # Temp file lives next to the original file
    TMP_FILE="$INPUT_DIR/${BASENAME}_normalized_temp.ogg"
    OUTPUT_FILE="$INPUT_FILE"
  else
    OUTPUT_FILE="$OUTPUT_DIR/$FILENAME"
    TMP_FILE="$OUTPUT_FILE"
  fi

  echo "----------------------------------------"
  echo "Normalizing: $FILENAME"

  # Pass 1: detect peak after DC removal
  PEAK=$(ffmpeg -i "$INPUT_FILE" \
    -af "dcshift=0,volumedetect" \
    -f null - 2>&1 \
    | grep "max_volume" \
    | awk '{print $5}')

  if [[ -z "$PEAK" ]]; then
    echo "Failed to detect peak for $FILENAME"
    continue
  fi

  # Calculate gain to reach -1.0 dB
  GAIN=$(awk "BEGIN { print -1.0 - ($PEAK) }")

  echo "Detected peak: $PEAK dB"
  echo "Applying gain: $GAIN dB"

  # Pass 2: apply DC removal + gain into temp/output
  ffmpeg -y -i "$INPUT_FILE" \
    -af "dcshift=0,volume=${GAIN}dB" \
    "$TMP_FILE"

  # Replace original if in-place
  if [[ "$IN_PLACE" == true ]]; then
    rm -f "$OUTPUT_FILE"
    mv "$TMP_FILE" "$OUTPUT_FILE"
  fi

  echo "Done: $OUTPUT_FILE"
done

echo "========================================"
echo "All files normalized"
