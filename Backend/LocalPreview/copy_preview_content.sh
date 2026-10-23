#!/bin/sh
set -eu

preview_destination="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/LocalPreviewContent"

if [ "${CONFIGURATION:-}" != "Debug" ]; then
    rm -rf "$preview_destination"
    exit 0
fi

preview_source="$PROJECT_DIR/Design/LevelGeneration/LocalPreview"
preview_build="$DERIVED_FILE_DIR/PictarrowLocalPreview"

python3 "$PROJECT_DIR/Backend/Firebase/prepare_content.py" \
    --project-root "$PROJECT_DIR" \
    --level-root "$preview_source" \
    --output "$preview_build" \
    --content-version 9001 \
    --package-version 1

rm -rf "$preview_destination"
mkdir -p "$preview_destination"
ditto "$preview_build" "$preview_destination"
