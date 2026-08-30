#!/bin/bash
set -euo pipefail

# Patch casatools/src/tools/msmetadata/msmetadata_cmpt.cc to add
# operator== (and const-qualify the existing iterator methods) on the
# counting_iterator struct.
#
# clang 18+ enforces that iterator types used in range-based std::set
# construction must have operator== defined, and libc++'s
# __tree::__insert_range_unique() calls it through a const reference, so
# operator==/operator!=/operator* all need to be const as well.
#
# The struct (at line ~83) looks like:
#   template<class T> struct counting_iterator : ... {
#       bool operator!=(const counting_iterator &other) { return val != other.val; }
#       T operator*( ) { return val; }
#       ...
#   };
#
# This is the same fix as patches/casatools-msmetadata-counting-iterator.patch
# (applied via patches/apply-patches.sh), kept here as a separate,
# idempotent pixi task wired directly into build-casacpp/build-casatools'
# depends-on chain. That's deliberate, not redundant: clone-repo.sh only
# calls apply-patches.sh on a fresh clone or a non-dev git update --  the
# CASA_DEVELOPMENT_MODE=true path used by `clone-dev`/`build-dev` skips it
# entirely to preserve local changes, so relying on apply-patches.sh alone
# means this fix silently never lands in a dev-mode checkout. Running both
# is safe: whichever applies first wins, and the other is a no-op thanks to
# the idempotency check below.
#
# Idempotent: skips if operator== is already present.

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="${PROJECT_ROOT}/src/casa6/casatools/src/tools/msmetadata/msmetadata_cmpt.cc"

if [[ ! -f "${FILE}" ]]; then
    echo "Warning: ${FILE} not found — skipping counting_iterator patch"
    exit 0
fi

if grep -q "operator==" "${FILE}"; then
    echo "counting_iterator patch already applied — skipping"
    exit 0
fi

echo "Patching counting_iterator in msmetadata_cmpt.cc..."

python3 - "${FILE}" << 'PYEOF'
import sys

path = sys.argv[1]
content = open(path).read()

old = ('    bool operator!=(const counting_iterator &other) { return val != other.val; }\n'
       '    T operator*( ) { return val; }')
new = ('    bool operator==(const counting_iterator &other) const { return val == other.val; }\n'
       '    bool operator!=(const counting_iterator &other) const { return val != other.val; }\n'
       '    T operator*( ) const { return val; }')

if old not in content:
    print(f"ERROR: expected operator!=/operator* lines not found in {path}")
    print("The source may have changed — patch needs updating")
    sys.exit(1)

open(path, 'w').write(content.replace(old, new))
print("  operator== inserted; operator!=/operator* made const")
PYEOF

if grep -q "operator==" "${FILE}"; then
    echo "counting_iterator patch applied successfully"
else
    echo "Warning: patch verification failed — check ${FILE} manually"
fi
