#!/bin/bash
set -euo pipefail

echo "Building casacpp (C++ libraries)..."

# Check that we're in a pixi/conda environment
if [[ -z "${CONDA_PREFIX:-}" ]]; then
    echo "Error: CONDA_PREFIX not set. Make sure you're running this within a pixi environment."
    echo "Try: pixi run -e intel-mac build-casacpp"
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"
echo "Using conda environment: $CONDA_PREFIX"

cd src/casa6

# The C++ code is now built as part of casatools
# Let's look for the correct CMakeLists.txt location
if [[ -d "casatools/src/code" ]]; then
    CASACPP_SOURCE_DIR="casatools/src/code"
    echo "Found casacpp source in: $CASACPP_SOURCE_DIR"
elif [[ -d "casatools/src" ]]; then
    CASACPP_SOURCE_DIR="casatools/src"
    echo "Found casacpp source in: $CASACPP_SOURCE_DIR"
elif [[ -d "casatools" ]]; then
    CASACPP_SOURCE_DIR="casatools"
    echo "Found casacpp source in: $CASACPP_SOURCE_DIR"
else
    echo "Error: Cannot find casacpp source directory"
    echo "Available directories in src/casa6:"
    ls -la
    exit 1
fi

# Create build directory
mkdir -p build/casacpp
cd build/casacpp

# Platform-specific configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS specific settings
    export CC="ccache clang"
    export CXX="ccache clang++"
    export FC=gfortran  # Set Fortran compiler (ccache doesn't work well with gfortran)
    
    # Set OpenMP flags for macOS (handle unset variables properly)
    export CPPFLAGS="-I$CONDA_PREFIX/include -I$(pwd)/../../casatools ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
    
    # macOS-specific compiler flags to handle deprecation warnings
    export CXXFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CXXFLAGS:-}"
    export CFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CFLAGS:-}"
    
    # ccache configuration
    export CCACHE_DIR="$PROJECT_ROOT/tmp/ccache"
    export CCACHE_MAXSIZE="15G"
    export CCACHE_COMPRESS=1
    
    # Check if we're on ARM64 (where libsakura is not available)
    if [[ "$(uname -m)" == "arm64" ]]; then
        echo "Warning: Building on ARM64 Mac - libsakura not available"
        CMAKE_SAKURA_FLAGS="-DUSE_SAKURA=OFF"
    else
        echo "Building on Intel Mac with libsakura support"
        CMAKE_SAKURA_FLAGS="-DUSE_SAKURA=ON"
    fi
    
    # CMake flags - let CMake use environment variables for compilers
    CMAKE_EXTRA_FLAGS="-DCMAKE_Fortran_COMPILER=gfortran -DOpenMP_ROOT=$CONDA_PREFIX $CMAKE_SAKURA_FLAGS"
    
    # Add flags to handle warnings as warnings, not errors
    CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DCMAKE_CXX_FLAGS=-Wno-error=deprecated-declarations -DCMAKE_C_FLAGS=-Wno-error=deprecated-declarations"
    
else
    # Linux specific settings
    export CC="ccache gcc"
    export CXX="ccache g++"
    export FC=gfortran  # Fortran compiler (ccache doesn't work well with gfortran)
    export CPPFLAGS="-I$CONDA_PREFIX/include -I$(pwd)/../../casatools ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
    
    # ccache configuration
    export CCACHE_DIR="$PROJECT_ROOT/tmp/ccache"
    export CCACHE_MAXSIZE="15G"
    export CCACHE_COMPRESS=1
    
    CMAKE_EXTRA_FLAGS="-DCMAKE_Fortran_COMPILER=gfortran -DUSE_SAKURA=ON"
fi

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
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  CXXFLAGS=$CXXFLAGS"
    echo "  CFLAGS=$CFLAGS"
fi
echo "  Source directory: ../../$CASACPP_SOURCE_DIR"

# Configure with CMake
echo "Configuring with CMake..."
cmake ../../$CASACPP_SOURCE_DIR \
    -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_OPENMP=ON \
    -DUSE_THREADS=ON \
    -DCMAKE_CXX_STANDARD=14 \
    -DUseCrashReporter=OFF \
    -DBoost_NO_BOOST_CMAKE=ON \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    -DCMAKE_FIND_ROOT_PATH="$CONDA_PREFIX" \
    -DCMAKE_INCLUDE_PATH="$CONDA_PREFIX/include;$(pwd)/../../casatools" \
    $CMAKE_EXTRA_FLAGS

# Determine number of cores for parallel build
if command -v nproc &> /dev/null; then
    NCORES=$(nproc)
elif command -v sysctl &> /dev/null; then
    NCORES=$(sysctl -n hw.ncpu)
else
    NCORES=4
fi

echo "Building with $NCORES parallel jobs..."

# Build
cmake --build . --parallel $NCORES

# Install
echo "Installing casacpp..."
cmake --build . --target install

echo "ccache statistics after build:"
ccache --show-stats

echo "casacpp build completed successfully!"
