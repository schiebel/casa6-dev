#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Find the extracted libsakura directory
LIBSAKURA_DIR=$(find src -maxdepth 1 -name "sakura-*" -type d | head -1)

if [[ -z "$LIBSAKURA_DIR" ]]; then
    echo "Error: libsakura source not found in src/"
    echo "Make sure LIBSAKURA_URL was set when running clone-repo"
    exit 1
fi

echo "Building libsakura in $LIBSAKURA_DIR/libsakura"

cd "$LIBSAKURA_DIR/libsakura"

###
### libsakura has build problems with pixi. The libsakura_VERSION_MAJOR and
### libsakura_VERSION_MINOR cmake variables are not defined when the
### src/CMakeLists.txt delegate is used.
###
TEMP_FILE=$(mktemp)
INSERT_FILE=$(mktemp)
# Ensure the temporary file is removed on script exit
trap 'rm -f "$TEMP_FILE" "$INSERT_FILE"' EXIT

grep -oP '^\s*set\s*\(libsakura_VERSION_(MAJOR|MINOR|PATCH)\s+\d+\)' "CMakeLists.txt" > "$TEMP_FILE"

if [[ ! -s "$TEMP_FILE" ]]; then
    echo "Could not determine libsakura version."
    exit 1
fi

echo "libsakura version info:"
cat "$TEMP_FILE"

# Check for existing version setup and insert any that are found into
# libsakura/src/CMakeLists.txt after the project() line. Build the multiline
# content for insertion, ensuring we don't insert duplicates.
UPDATE_FILE="src/CMakeLists.txt"

# Create the file for insertion of version setup.
while IFS= read -r line; do
    if ! grep -qF -- "$line" "$UPDATE_FILE"; then
        echo "Adding statement: $line"
        echo "$line" >> "$INSERT_FILE"
    else
        echo "Statement already exists, skipping: $line"
    fi
done < "$TEMP_FILE"

# Use sed's 'r' (read) command to insert the contents of the file
if [ -s "$INSERT_FILE" ]; then
    sed -i -E "/^\s*project\s*\(.*\)/r $INSERT_FILE" "$UPDATE_FILE"
    echo "Inserted version setup into $UPDATE_FILE after the project() line."
fi

echo "Completed update of $LIBSAKURA_DIR/libsakura/src/CMakeLists.txt"

# Build libsakura
mkdir -p build
cd build

echo "libsakura: cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INSTALL_PREFIX='$CONDA_PREFIX' -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_PREFIX_PATH='$CONDA_PREFIX' -DBUILD_DOC:BOOL=OFF -DPYTHON_BINDING:BOOL=OFF -DSIMD_ARCH=GENERIC -DENABLE_TEST:BOOL=OFF"

cmake .. \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    -DBUILD_DOC:BOOL=OFF \
    -DPYTHON_BINDING:BOOL=OFF \
    -DSIMD_ARCH=GENERIC \
    -DENABLE_TEST:BOOL=OFF

make
make install

echo "libsakura installed to $CONDA_PREFIX"
