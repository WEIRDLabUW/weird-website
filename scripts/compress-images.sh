#!/bin/bash
# Image compression script for website
# Requires: ImageMagick (convert command)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES_DIR="${SCRIPT_DIR}/../images"

# Default settings
PROFILE_SIZE=400
PHOTO_SIZE=1920
QUALITY=85

usage() {
    echo "Usage: $0 [options] <file|directory>"
    echo ""
    echo "Options:"
    echo "  -p, --profile    Compress as profile photo (${PROFILE_SIZE}px max, converts PNG to JPG)"
    echo "  -l, --large      Compress as large photo (${PHOTO_SIZE}px max, e.g., lab photos)"
    echo "  -q, --quality N  Set JPEG quality (default: ${QUALITY})"
    echo "  -h, --help       Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --profile images/people/newperson.png"
    echo "  $0 --large images/lab_photo.PNG"
    echo "  $0 --profile images/people/          # Compress all in directory"
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

    local dir=$(dirname "$input")
    local filename=$(basename "$input")
    local name="${filename%.*}"
    local ext="${filename##*.}"
    local ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    # Determine output format (convert PNG to JPG for smaller size)
    local output_ext="jpg"
    if [[ "$ext_lower" == "jpg" || "$ext_lower" == "jpeg" ]]; then
        output_ext="$ext_lower"
    fi

    local output="${dir}/${name}.${output_ext}"
    local temp="${dir}/${name}_temp.${output_ext}"

    # Get original size
    local orig_size=$(stat -c%s "$input" 2>/dev/null || stat -f%z "$input")

    # Compress
    convert "$input" -resize "${max_size}x${max_size}>" -quality "$quality" "$temp"

    # Get new size
    local new_size=$(stat -c%s "$temp" 2>/dev/null || stat -f%z "$temp")

    # Calculate reduction
    local reduction=$((100 - (new_size * 100 / orig_size)))

    # Replace original or create new file
    if [[ "$input" != "$output" ]]; then
        mv "$temp" "$output"
        rm -f "$input"
        echo "Compressed: $filename -> $(basename "$output") ($(numfmt --to=iec $orig_size) -> $(numfmt --to=iec $new_size), ${reduction}% smaller)"
    else
        mv "$temp" "$output"
        echo "Compressed: $filename ($(numfmt --to=iec $orig_size) -> $(numfmt --to=iec $new_size), ${reduction}% smaller)"
    fi
}

# Parse arguments
MODE=""
while [[ $# -gt 0 ]]; do
    case $1 in
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
MAX_SIZE=$([[ "$MODE" == "profile" ]] && echo "$PROFILE_SIZE" || echo "$PHOTO_SIZE")

if [[ -d "$TARGET" ]]; then
    # Process all images in directory
    find "$TARGET" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | while read -r img; do
        compress_image "$img" "$MAX_SIZE" "$QUALITY"
    done
elif [[ -f "$TARGET" ]]; then
    compress_image "$TARGET" "$MAX_SIZE" "$QUALITY"
else
    echo "Error: $TARGET not found"
    exit 1
fi

echo "Done!"
