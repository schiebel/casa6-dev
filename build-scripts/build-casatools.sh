#!/bin/bash
set -euo pipefail

echo "Building casatools..."

# Check that we're in a pixi/conda environment
if [[ -z "${CONDA_PREFIX:-}" ]]; then
    echo "Error: CONDA_PREFIX not set. Make sure you're running this within a pixi environment."
    echo "Try: pixi run -e intel-mac build-casatools"
    exit 1
fi

# Set project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"
echo "Using conda environment: $CONDA_PREFIX"

cd src/casa6/casatools

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build/ dist/ *.egg-info/

# Set environment variables
export CASACPP_ROOT="$CONDA_PREFIX"
export CASA_BUILD_TYPE="Release"

# ccache configuration - use project-wide ccache directory
export CCACHE_DIR="$PROJECT_ROOT/tmp/ccache"
export CCACHE_MAXSIZE="15G"
export CCACHE_COMPRESS=1

NUMPY_INCLUDE=`python -c 'import numpy as np; print(np.get_include())'`
# Platform-specific compiler settings
if [[ "$OSTYPE" == "darwin"* ]]; then
    export CC="ccache clang"
    export CXX="ccache clang++"
    export CPPFLAGS="-I$CONDA_PREFIX/include -I$NUMPY_INCLUDE ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
    export CXXFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CXXFLAGS:-}"
    export CFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CFLAGS:-}"
else
    export CC="ccache gcc"
    export CXX="ccache g++"
    export CPPFLAGS="-I$CONDA_PREFIX/include -I$NUMPY_INCLUDE ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
fi

# Initialize ccache directory and show stats
echo "Setting up ccache..."
mkdir -p "$CCACHE_DIR"
ccache --max-size="$CCACHE_MAXSIZE"
ccache --set-config=compression=true
echo "ccache statistics before build:"
ccache --show-stats

echo "Build environment:"
echo "  CASACPP_ROOT=$CASACPP_ROOT"
echo "  CASA_BUILD_TYPE=$CASA_BUILD_TYPE"
echo "  CC=$CC"
echo "  CXX=$CXX"
echo "  CCACHE_DIR=$CCACHE_DIR"
echo "  CFLAGS=$CFLAGS"
echo "  CXXFLAGS=$CXXFLAGS"
echo "  CPPFLAGS=$CPPFLAGS"
echo "  LDFLAGS=$LDFLAGS"

# Try building with explicit build directory creation
echo "Building casatools with setuptools..."

# First, try the standard build process
python setup.py build_ext --inplace || {
    echo "Standard build failed, trying alternative approach..."
    
    # Create the expected build directory structure manually
    echo "Creating build directory structure manually..."
    mkdir -p build/lib.*/casatools
    
    # Try building again
    python setup.py build_ext --inplace || {
        echo "Build still failing, trying with different Python build approach..."
        
        # Try using pip build instead
        pip install -e . --no-deps || {
            echo "All build approaches failed. Manual intervention may be required."
            echo "Check the casatools setup.py configuration and build requirements."
            exit 1
        }
    }
}

# If we get here, one of the build approaches worked
echo "Building wheel..."
python setup.py bdist_wheel

# Install the wheel
echo "Installing casatools wheel..."
pip install dist/*.whl --force-reinstall --no-deps

echo "ccache statistics after build:"
ccache --show-stats

echo "casatools build completed successfully!"
