#!/bin/bash
# setup-intel-mac-ld.sh — Source this file (don't execute it) to install
# the ld wrapper that strips -lto_library from clang's linker invocations.
#
# Usage in build scripts (PROJECT_ROOT must be defined first):
#   source "${PROJECT_ROOT}/build-scripts/setup-intel-mac-ld.sh"
#
# Background: conda-forge clang 18 on osx-64 unconditionally passes
#   -lto_library /path/to/libLTO.dylib
# to the system ld via its linker driver. Xcode 16+ ld rejects this flag
# unless the filename is literally 'libLTO.dylib' (not a full path).
# The wrapper intercepts the ld call and strips the offending argument.
#
# Safe to source on all platforms — the wrapper is only installed on
# osx-64 (Intel Mac). On ARM Mac and Linux this is a no-op.

if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "x86_64" ]]; then
    _LD_WRAPPER_DIR=$(mktemp -d)

    # Register cleanup. Use a function to avoid clobbering any existing trap.
    _cleanup_ld_wrapper() {
        rm -rf "$_LD_WRAPPER_DIR"
    }
    trap '_cleanup_ld_wrapper' EXIT

    cat > "${_LD_WRAPPER_DIR}/ld" << 'LDWRAP'
#!/bin/bash
# Strip -lto_library <arg> pairs before calling the real system ld.
REAL_LD=$(xcrun -f ld 2>/dev/null || echo /usr/bin/ld)
args=()
skip_next=0
for arg in "$@"; do
    if [[ $skip_next -eq 1 ]]; then
        skip_next=0
        continue
    fi
    if [[ "$arg" == "-lto_library" ]]; then
        skip_next=1
        continue
    fi
    args+=("$arg")
done
exec "$REAL_LD" "${args[@]}"
LDWRAP

    chmod +x "${_LD_WRAPPER_DIR}/ld"
    export PATH="${_LD_WRAPPER_DIR}:${PATH}"
    echo "Intel Mac: ld wrapper installed (strips -lto_library for Xcode 16 / conda clang 18 compatibility)"
fi
