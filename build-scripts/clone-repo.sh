#!/bin/bash
set -euo pipefail

echo "Cloning CASA6 repository..."

# Check for development mode flag
DEVELOPMENT_MODE=${CASA_DEVELOPMENT_MODE:-false}

# Check for branch/tag specification
if [[ -z "${CASA_BRANCH:-}" ]] && [[ -d "src/casa6/.git" ]]; then
    # Use current branch if no branch specified and repo exists
    CASA_BRANCH=$(cd src/casa6 && git branch --show-current 2>/dev/null || echo "master")
    echo "No CASA_BRANCH specified, staying on current branch: $CASA_BRANCH"
else
    CASA_BRANCH=${CASA_BRANCH:-master}
fi

if [ ! -d "src" ]; then
    mkdir -p src
fi

cd src

if [ ! -d "casa6" ]; then
    echo "Cloning fresh repository..."
    git clone https://open-bitbucket.nrao.edu/scm/casa/casa6.git
    cd casa6
    
    # Checkout specified branch/tag
    if [[ "$CASA_BRANCH" != "master" ]]; then
        echo "Checking out branch/tag: $CASA_BRANCH"
        git checkout "$CASA_BRANCH"
    fi

    echo "Initializing and updating git submodules..."
    git submodule init
    git submodule update --recursive
    
    # Apply local patches after initial clone
    if [[ -f "../../patches/apply-patches.sh" ]]; then
        echo "Applying local patches..."
        bash ../../patches/apply-patches.sh
    fi
else
    cd casa6
    
    if [[ "$DEVELOPMENT_MODE" == "true" ]]; then
        echo "Development mode: Skipping git update to preserve local changes"
        echo "Current git status:"
        git status --porcelain || echo "Not a git repository (local changes preserved)"
        
        # Still check submodules in development mode
        if [[ -d ".git" ]] && [[ ! -f "casatools/casacore/CMakeLists.txt" ]]; then
            echo "Submodules appear to be missing, updating them..."
            git submodule init
            git submodule update --recursive
        fi
    else
        if [[ -d ".git" ]]; then
            echo "Repository exists, updating..."
            # Stash any local changes
            if ! git diff-index --quiet HEAD --; then
                echo "Stashing local changes..."
                git stash push -m "Auto-stash before update $(date)"
            fi
            git fetch origin
            
            # Checkout and update to specified branch
            echo "Switching to branch/tag: $CASA_BRANCH"
            git checkout "$CASA_BRANCH"
            git reset --hard "origin/$CASA_BRANCH" 2>/dev/null || {
                echo "Could not reset to origin/$CASA_BRANCH, assuming it's a tag or local branch"
                git reset --hard "$CASA_BRANCH" 2>/dev/null || echo "Using current HEAD"
            }

            echo "Updating git submodules..."
            git submodule init
            git submodule update --recursive
            
            # Apply local patches after update
            if [[ -f "../../patches/apply-patches.sh" ]]; then
                echo "Applying local patches..."
                bash ../../patches/apply-patches.sh
            fi
        else
            echo "No .git directory found - assuming development mode"
            echo "Skipping git update to preserve local modifications"
            
            # Check if we need submodules
            if [[ ! -f "casatools/casacore/CMakeLists.txt" ]]; then
                echo "ERROR: casacore submodule is missing and we can't update it without git!"
                echo "You'll need to either:"
                echo "1. Restore the .git directory and run with git tracking"
                echo "2. Manually download and extract casacore to casatools/casacore/"
                echo "3. Use a fresh clone with 'pixi run clean-all && pixi run -e intel-mac clone-repo'"
                exit 1
            fi
        fi
    fi
fi

echo "CASA6 repository ready at: $(pwd)"
echo "Current branch/commit:"
if [[ -d ".git" ]]; then
    echo "  Branch: $(git branch --show-current)"
    echo "  Commit: $(git rev-parse HEAD)"
    echo "Submodule status:"
    git submodule status
else
    echo "Local development copy (no git tracking)"
fi

# Verify critical submodules are present
if [[ -f "casatools/casacore/CMakeLists.txt" ]]; then
    echo "✓ casacore submodule is present"
else
    echo "✗ casacore submodule is MISSING - build will fail"
    exit 1
fi
```# CASA6 Pixi Build Workflow

This workflow will help you build the latest unreleased versions of `casatools` and `casatasks` from the NRAO casa6 repository using pixi.

## Prerequisites

1. Install [pixi](https://pixi.sh/)
2. Ensure you have Git installed
3. Access to the NRAO casa6 repository

## Project Structure
