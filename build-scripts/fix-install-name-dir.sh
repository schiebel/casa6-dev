#!/bin/bash
set -euo pipefail

# The CASA6 source tree hardcodes CMAKE_INSTALL_NAME_DIR to an absolute
# path in three CMakeLists.txt files:
#
#   casatools/casacore/CMakeLists.txt
#   casatools/src/tools/CMakeLists.txt
#   casatools/src/code/CMakeLists.txt
#
# e.g.:
#   set(CMAKE_INSTALL_NAME_DIR "${CMAKE_INSTALL_PREFIX}/lib")
#
# A plain set() (no CACHE keyword) inside a CMakeLists.txt shadows any
# -DCMAKE_INSTALL_NAME_DIR=... passed on the cmake command line for the
# rest of that directory scope and everything added beneath it via
# add_subdirectory(). That means the RPATH flags in build-casacpp.sh
# and build-casacore.sh are silently overridden the moment these lines
# run, regardless of what's passed in from outside.
#
# The practical symptom: every casacpp/casacore .dylib gets an absolute
# LC_ID_DYLIB baked in at build time (e.g.
# /Users/you/develop/casa/casa6-dev/.pixi/envs/default/lib/libcasacpp_flagging.6.dylib),
# so any other Python environment that ends up loading these libraries
# (for example via a symlinked casatools install) reaches back into this
# exact pixi checkout at runtime instead of resolving relative to itself.
# If that other environment has already loaded a different, ABI-
# incompatible build of a shared dependency (protobuf being the case that
# motivated this fix), you get a segfault rather than a clean failure.
#
# This script rewrites those three lines to use @rpath instead, so that
# targets declare themselves relocatable and the CMAKE_INSTALL_RPATH
# search-path entries set in build-casacpp.sh / build-casacore.sh can
# actually take effect. CMAKE_MACOSX_RPATH TRUE (set alongside these
# lines) is left untouched -- it was already correct.
#
# Idempotent: safe to run on every build, same as fix-protobuf-cmake.sh.

echo "Fixing hardcoded CMAKE_INSTALL_NAME_DIR in casacore/casatools CMakeLists.txt files..."

cd src/casa6

FILES=(
    "casatools/casacore/CMakeLists.txt"
    "casatools/src/tools/CMakeLists.txt"
    "casatools/src/code/CMakeLists.txt"
)

for f in "${FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "  Warning: $f not found, skipping"
        continue
    fi

    # sed only rewrites lines still matching the hardcoded-absolute-path
    # pattern; lines already at "@rpath" don't match it and are left
    # untouched, so it's safe to always run this rather than skip the whole
    # file just because SOME line in it is already patched (a file can have
    # more than one CMAKE_INSTALL_NAME_DIR set() call -- see casacore's
    # CMakeLists.txt, which has one guarded by if(APPLE) earlier in the
    # file and a second, later one that isn't).
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # BSD sed (macOS) requires an explicit (possibly empty) backup suffix.
        # [[:space:]]* after 'set' handles both 'set(...)' and 'set (...)'
        # -- both forms appear in this source tree. Match everything up to
        # the FIRST closing paren rather than assuming it sits directly
        # against the closing quote, since the actual source has a space
        # before it, e.g. set(CMAKE_INSTALL_NAME_DIR "${CMAKE_INSTALL_PREFIX}/lib" )
        sed -i '' -E \
            's#set[[:space:]]*\(CMAKE_INSTALL_NAME_DIR "\$\{CMAKE_INSTALL_PREFIX\}[^)]*\)#set(CMAKE_INSTALL_NAME_DIR "@rpath")#g' \
            "$f"
    else
        sed -i -E \
            's#set[[:space:]]*\(CMAKE_INSTALL_NAME_DIR "\$\{CMAKE_INSTALL_PREFIX\}[^)]*\)#set(CMAKE_INSTALL_NAME_DIR "@rpath")#g' \
            "$f"
    fi

    remaining=$(grep -cE 'CMAKE_INSTALL_NAME_DIR "\$\{CMAKE_INSTALL_PREFIX\}' "$f" || true)
    if [[ "$remaining" -eq 0 ]]; then
        echo "  $f: all CMAKE_INSTALL_NAME_DIR occurrences now @rpath"
    else
        echo "  Warning: $remaining unpatched CMAKE_INSTALL_NAME_DIR occurrence(s) remain in $f -- check manually, source layout may have changed"
        grep -n 'CMAKE_INSTALL_NAME_DIR "\$\{CMAKE_INSTALL_PREFIX\}' "$f" | sed 's/^/    /'
    fi
done

echo "CMAKE_INSTALL_NAME_DIR fix complete"
