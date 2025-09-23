#!/bin/bash
set -euo pipefail

echo "Applying local patches..."

# Simple function to apply patches with better error handling
apply_patch_simple() {
    local patch_file="$1"
    local description="$2"
    
    if [[ ! -f "../../patches/$patch_file" ]]; then
        echo "Patch file ../../patches/$patch_file not found, skipping"
        return
    fi
    
    echo "Applying $description..."
    
    # Try to apply the patch, capture both stdout and stderr
    if patch -p0 -N < "../../patches/$patch_file" 2>&1 | tee /tmp/patch_output.log; then
        echo "✓ $description applied successfully"
    else
        # Check if it failed because already applied
        if grep -q "Reversed.*already applied\|already applied" /tmp/patch_output.log; then
            echo "✓ $description already applied (skipping)"
        elif grep -q "FAILED\|reject" /tmp/patch_output.log; then
            echo "✗ $description failed to apply - conflicts detected"
            echo "Check the .rej files for details"
        else
            echo "? $description - unclear result, check manually"
        fi
    fi
    rm -f /tmp/patch_output.log
}

# Apply patches in order
#apply_patch_simple "cxx14-casacore.patch" "C++14 standard patch for casacore"
#apply_patch_simple "cxx14-casacpp.patch" "C++14 standard patch for casacpp"
apply_patch_simple "casacore-arraytransform-fix.patch" "casacore arrayTransform template fix"
apply_patch_simple "fix-unique-ptr-copy.patch" "unique_ptr copy fix"
apply_patch_simple "casacore-visibilityprocessing-not_fn.patch" "not_fn undefined fix"
apply_patch_simple "casatools-builddir-fix.patch" "fix casatools setup.py"
apply_patch_simple "casatools-wheel-libgcc-fix.patch" "fix casatool wheel bundling of libgcc"
apply_patch_simple "casatasks-copy-ignore-existing.patch" "fix copy commands so they do not fail for existing dest"

echo "All patch operations completed"
