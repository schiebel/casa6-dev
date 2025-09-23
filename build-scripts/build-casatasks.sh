#!/bin/bash
set -euo pipefail

echo "Building casatasks..."

# Check that we're in a pixi/conda environment
if [[ -z "${CONDA_PREFIX:-}" ]]; then
    echo "Error: CONDA_PREFIX not set. Make sure you're running this within a pixi environment."
    echo "Try: pixi run -e intel-mac build-casatasks"
    exit 1
fi

# Set project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"
echo "Using conda environment: $CONDA_PREFIX"

cd src/casa6/casatasks

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build/ dist/ *.egg-info/

# ccache configuration - use project-wide ccache directory
export CCACHE_DIR="$PROJECT_ROOT/tmp/ccache"
export CCACHE_MAXSIZE="15G"
export CCACHE_COMPRESS=1

# Initialize ccache directory and show stats
echo "Setting up ccache..."
mkdir -p "$CCACHE_DIR"
ccache --max-size="$CCACHE_MAXSIZE"
ccache --set-config=compression=true
echo "ccache statistics before build:"
ccache --show-stats

echo "Build environment:"
echo "  CONDA_PREFIX=$CONDA_PREFIX"
echo "  CCACHE_DIR=$CCACHE_DIR"

# Check if casatools is installed
echo "Checking casatools installation..."
if ! python -c "import casatools; print(f'casatools version: {casatools.version()}')" 2>/dev/null; then
    echo "Warning: casatools not found or not working properly"
    echo "Make sure casatools was built and installed successfully"
fi

# Build casatasks
echo "Building casatasks..."
python setup.py build
python setup.py bdist_wheel

# Install with relaxed dependency checking
echo "Installing casatasks wheel..."
# First try normal install
if ! pip install dist/*.whl --force-reinstall; then
    echo "Normal install failed, trying with --no-deps..."
    # If that fails, install without dependency checking
    pip install dist/*.whl --force-reinstall --no-deps
    
    echo "Verifying installation..."
    if ! python -c "import casatasks; print('casatasks imported successfully')"; then
        echo "Installation verification failed!"
        exit 1
    fi
fi

echo "ccache statistics after build:"
ccache --show-stats 2>/dev/null || echo "ccache not available"

echo "casatasks build completed successfully!"

# Final verification
echo "Final verification:"
python -c "
try:
    import casatools
    import casatasks
    print(f'✓ casatools version: {casatools.version()}')
    print('✓ casatasks imported successfully')
    print('✓ Build completed successfully!')
except ImportError as e:
    print(f'✗ Import failed: {e}')
    exit(1)
"
