#!/bin/bash
# Image compression script for website
# Requires: ImageMagick

set -e

# Default settings
PROFILE_SIZE=400
PHOTO_SIZE=1920
QUALITY=85

# Find ImageMagick (supports both IM6 and IM7)
if command -v magick >/dev/null 2>&1; then
    IM_CMD=(magick)
elif command -v convert >/dev/null 2>&1; then
    IM_CMD=(convert)
else
    echo "Error: ImageMagick not found."
    exit 1
fi

# Human-readable file sizes (works on Linux and macOS)
human_size() {
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec "$1"
    else
        awk -v size="$1" '
        BEGIN {
            split("B KB MB GB TB", u)
            i=1
            while (size>=1024 && i<5) {
                size/=1024
                i++
            }
            printf("%.1f%s", size, u[i])
        }'
    fi
}

usage() {
    echo "Usage: $0 [options] <file|directory>"
    echo
    echo "Options:"
    echo "  -p, --profile    Compress as profile photo (${PROFILE_SIZE}px max, converts PNG to JPG)"
    echo "  -l, --large      Compress as large photo (${PHOTO_SIZE}px max)"
    echo "  -q, --quality N  Set JPEG quality (default: ${QUALITY})"
    echo "  -h, --help       Show this help"
    echo
    echo "Examples:"
    echo "  $0 --profile images/people/newperson.png"
    echo "  $0 --large images/lab_photo.png"
    echo "  $0 --profile images/people/"
    exit 1
}

compress_image() {
    local input="$1"
    local max_size="$2"
    local quality="$3"

    if [[ ! -f "$input" ]]; then
        echo "File not found: $input"
        return 1
    fi

    local dir
    dir=$(dirname "$input")

    local filename
    filename=$(basename "$input")

    local name="${filename%.*}"
    local ext="${filename##*.}"
    local ext_lower
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    # Convert PNGs to JPG, keep JPG/JPEG as-is
    local output_ext="jpg"
    if [[ "$ext_lower" == "jpg" || "$ext_lower" == "jpeg" ]]; then
        output_ext="$ext_lower"
    fi

    local output="${dir}/${name}.${output_ext}"
    local temp="${dir}/${name}_temp.${output_ext}"

    # File sizes (Linux/macOS compatible)
    local orig_size
    orig_size=$(stat -c%s "$input" 2>/dev/null || stat -f%z "$input")

    # Compress
    "${IM_CMD[@]}" "$input" \
        -resize "${max_size}x${max_size}>" \
        -quality "$quality" \
        "$temp"

    local new_size
    new_size=$(stat -c%s "$temp" 2>/dev/null || stat -f%z "$temp")

    local reduction=$((100 - (new_size * 100 / orig_size)))

    if [[ "$ext_lower" == "png" ]]; then
        # PNG -> JPG
        mv "$temp" "$output"
        rm -f "$input"
        echo "Compressed: $filename -> $(basename "$output") ($(human_size "$orig_size") -> $(human_size "$new_size"), ${reduction}% smaller)"
    else
        # JPG/JPEG -> overwrite original
        mv "$temp" "$input"
        echo "Compressed: $filename ($(human_size "$orig_size") -> $(human_size "$new_size"), ${reduction}% smaller)"
    fi
}

# Parse arguments
MODE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--profile)
            MODE="profile"
            shift
            ;;
        -l|--large)
            MODE="large"
            shift
            ;;
        -q|--quality)
            QUALITY="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            break
            ;;
    esac
done

if [[ -z "$MODE" || -z "$1" ]]; then
    usage
fi

TARGET="$1"

if [[ "$MODE" == "profile" ]]; then
    MAX_SIZE=$PROFILE_SIZE
else
    MAX_SIZE=$PHOTO_SIZE
fi

if [[ -d "$TARGET" ]]; then
    find "$TARGET" -maxdepth 1 -type f \
        \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) |
    while IFS= read -r img; do
        compress_image "$img" "$MAX_SIZE" "$QUALITY"
    done
elif [[ -f "$TARGET" ]]; then
    compress_image "$TARGET" "$MAX_SIZE" "$QUALITY"
else
    echo "Error: $TARGET not found"
    exit 1
fi

echo "Done!"
