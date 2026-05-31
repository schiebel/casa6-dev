#!/bin/bash
set -euo pipefail

# Patch grpc/protobuf cmake files to fix target mismatches between
# grpcio-tools and the protobuf conda package.
#
# Root cause: grpcio-tools installs gRPCTargets.cmake built against a
# protobuf version where libupb is a separate cmake target. The protobuf
# conda package compiles libupb into libprotobuf and does not expose
# protobuf::libupb / protobuf::protoc-gen-upb / protobuf::protoc-gen-upbdefs
# as cmake targets. gRPCTargets.cmake calls set_target_properties() on
# gRPC targets whose INTERFACE_LINK_LIBRARIES reference these missing targets,
# causing cmake generation to fail.
#
# Fix: patch gRPCTargets.cmake to define the missing INTERFACE alias targets
# BEFORE the set_target_properties() calls that reference them. This is done
# by prepending the alias definitions right after the cmake_minimum_required
# line at the top of the file.
#
# Additionally patch protobuf-config.cmake to guard against double-inclusion
# when both find_package(Protobuf) and find_package(gRPC) are used.

CONDA="${CONDA_PREFIX}"

# ---- Patch 1: protobuf-config.cmake double-include guard -----------
CONFIG_FILE="${CONDA}/lib/cmake/protobuf/protobuf-config.cmake"

if [[ -f "${CONFIG_FILE}" ]]; then
    if grep -q "TARGET protobuf::libprotobuf" "${CONFIG_FILE}"; then
        echo "Patch 1: protobuf-config.cmake already patched — skipping"
    else
        echo "Patch 1: patching ${CONFIG_FILE}..."
        cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak"
        python3 - "${CONFIG_FILE}" << 'PYEOF'
import sys
path = sys.argv[1]
content = open(path).read()
old = 'include("${CMAKE_CURRENT_LIST_DIR}/protobuf-targets.cmake")'
new = ('# Guard: skip if already loaded (e.g. via gRPC find_dependency)\n'
       'if(NOT TARGET protobuf::libprotobuf)\n'
       '  include("${CMAKE_CURRENT_LIST_DIR}/protobuf-targets.cmake")\n'
       'endif()')
if old in content:
    open(path, 'w').write(content.replace(old, new))
    print("  Done")
else:
    print(f"  WARNING: expected line not found — skipping")
PYEOF
    fi
else
    echo "Warning: ${CONFIG_FILE} not found"
fi

# ---- Patch 2: gRPCTargets.cmake — inject missing alias targets -----
# Prepend INTERFACE alias targets for protobuf::libupb and friends
# at the TOP of gRPCTargets.cmake, before any set_target_properties()
# calls that reference them.
GRPC_TARGETS_FILE="${CONDA}/lib/cmake/grpc/gRPCTargets.cmake"

if [[ -f "${GRPC_TARGETS_FILE}" ]]; then
    if grep -q "protobuf::libupb INTERFACE IMPORTED" "${GRPC_TARGETS_FILE}"; then
        echo "Patch 2: gRPCTargets.cmake already patched — skipping"
    else
        echo "Patch 2: patching ${GRPC_TARGETS_FILE}..."
        cp "${GRPC_TARGETS_FILE}" "${GRPC_TARGETS_FILE}.bak"
        python3 - "${GRPC_TARGETS_FILE}" << 'PYEOF'
import sys
path = sys.argv[1]
content = open(path).read()

# Find the first non-comment, non-blank line to insert after the header
alias_block = '''
# Compatibility shim: this gRPCTargets.cmake was built against a protobuf
# version that exposes libupb as separate cmake targets. The installed
# protobuf package compiles libupb into libprotobuf directly. Define
# INTERFACE alias targets so gRPC link interfaces resolve correctly.
foreach(_upb_target
    protobuf::libupb
    protobuf::protoc-gen-upb
    protobuf::protoc-gen-upbdefs
    protobuf::protoc-gen-upb_minitable)
  if(NOT TARGET ${_upb_target})
    add_library(${_upb_target} INTERFACE IMPORTED)
    set_target_properties(${_upb_target} PROPERTIES
      INTERFACE_LINK_LIBRARIES "protobuf::libprotobuf")
  endif()
endforeach()

'''

# Insert after the last cmake_minimum_required or cmake_policy line at top,
# or after the first include() if present, otherwise after line 1.
lines = content.splitlines(keepends=True)
insert_at = 0
for i, line in enumerate(lines):
    stripped = line.strip().lower()
    if stripped.startswith('cmake_minimum_required') or \
       stripped.startswith('cmake_policy') or \
       stripped.startswith('#'):
        insert_at = i + 1
    else:
        break  # stop at first substantive line

lines.insert(insert_at, alias_block)
open(path, 'w').write(''.join(lines))
print(f"  Inserted alias block after line {insert_at}")
PYEOF
    fi
else
    echo "Warning: ${GRPC_TARGETS_FILE} not found"
fi

echo "================================================================"
echo "Protobuf/gRPC cmake compatibility patches complete"
echo "================================================================"
