#!/bin/bash
set -euo pipefail

echo "Building casacore with FFTPack support..."

# Check that we're in a pixi/conda environment
if [[ -z "${CONDA_PREFIX:-}" ]]; then
    echo "Error: CONDA_PREFIX not set. Make sure you're running this within a pixi environment."
    echo "Try: pixi run -e intel-mac build-casacore"
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"
echo "Using conda environment: $CONDA_PREFIX"

cd src/casa6/casatools/casacore

# Create build directory
mkdir -p build
cd build

# Platform-specific configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS specific settings
    export CC="ccache clang"
    export CXX="ccache clang++"
    export FC=gfortran
    
    # Set OpenMP flags for macOS
    export CPPFLAGS="-I$CONDA_PREFIX/include ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
    
    # macOS-specific compiler flags
    export CXXFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CXXFLAGS:-}"
    export CFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CFLAGS:-}"
    
    # Additional macOS CMake flags
    CMAKE_EXTRA_FLAGS="-DCMAKE_Fortran_COMPILER=gfortran -DOpenMP_ROOT=$CONDA_PREFIX"
    
else
    # Linux specific settings
    export CC="ccache gcc"
    export CXX="ccache g++"
    export FC=gfortran
    export CPPFLAGS="-I$CONDA_PREFIX/include ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
    
    CMAKE_EXTRA_FLAGS="-DCMAKE_Fortran_COMPILER=gfortran"
fi

# ccache configuration
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

echo "Compiler settings:"
echo "  CC=$CC"
echo "  CXX=$CXX"
echo "  FC=$FC"
echo "  CPPFLAGS=$CPPFLAGS"
echo "  LDFLAGS=$LDFLAGS"
echo "  CCACHE_DIR=$CCACHE_DIR"
echo "  CCACHE_MAXSIZE=$CCACHE_MAXSIZE"

# Configure casacore with CMake
echo "Configuring casacore with CMake..."
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=14 \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    -DCMAKE_FIND_ROOT_PATH="$CONDA_PREFIX" \
    -DBUILD_FFTPACK_DEPRECATED=YES \
    -DBUILD_PYTHON=OFF \
    -DBUILD_PYTHON3=OFF \
    -DUSE_OPENMP=ON \
    -DUSE_THREADS=ON \
    -DBoost_NO_BOOST_CMAKE=ON \
    $CMAKE_EXTRA_FLAGS

# Determine number of cores for parallel build
if command -v nproc &> /dev/null; then
    NCORES=$(nproc)
elif command -v sysctl &> /dev/null; then
    NCORES=$(sysctl -n hw.ncpu)
else
    NCORES=4
fi

echo "Building casacore with $NCORES parallel jobs..."

# Build
cmake --build . --parallel $NCORES

# Install
echo "Installing casacore..."
cmake --build . --target install

echo "casacore build completed successfully!"
echo "FFTPack should now be available for casacpp build."
