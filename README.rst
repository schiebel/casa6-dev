======================
Automated CASA6 builds
======================

This directory contains the build artifacts for building
`CASA6 <https://casa.nrao.edu>`__ with `pixi <https://pixi.sh/latest/>`__, which is a
wrapper around a `conda installation <https://mamba.readthedocs.io/en/latest/>`__.
A ``pixi.toml`` file is created to configure package constraints in a declarative
manner. From this, `pixi <https://pixi.sh/latest/>`__ creates a ``pixi.lock`` file
which ensures that the build is reproducible.

To use this, you must install `pixi <https://pixi.sh/latest/>`__.

History
=======
**May 31, 2026**
    Python versions were stuck at Python 3.11 because
    `conda-forge <https://conda-forge.org/>`__ seems to have stopped updating
    `grpc-cpp <https://anaconda.org/channels/conda-forge/packages/grpc-cpp/overview>`__.
    To avoid this, the build switched from using Conda packages to using a pip
    wheel which Google pre-builds.

Background
==========
This build process was originally created to build `CASA6 <https://casa.nrao.edu>`__
on an Intel MacBook after CASA dropped official Intel Mac support
[*as of Tue Sep 23 16:29:10 EDT 2025*]. It has since been extended to support
ARM macOS and Linux, and to target Python 3.12+.

**Platform support:**

+---------------+----------+---------------------------------------------------+
| Platform      | Default  | Notes                                             |
|               | Python   |                                                   |
+===============+==========+===================================================+
| Linux         | 3.12     | Full support; 3.11, 3.13 also available           |
+---------------+----------+---------------------------------------------------+
| ARM macOS     | 3.12     | Full support; 3.11 also available                 |
+---------------+----------+---------------------------------------------------+
| Intel macOS   | 3.11     | 3.12 available but less tested                    |
+---------------+----------+---------------------------------------------------+

**Python version defaults** are controlled by the ``py3xx`` features in
``pixi.toml``. To change the default for all platforms, find the comment
``DEFAULT_PYTHON_VERSION`` in ``pixi.toml`` and update the environment
references from ``py312`` to your desired version.

Known constraints
-----------------
- ``grpc-cpp`` on conda-forge is frozen at v1.51.1 (Feb 2023) and is
  incompatible with Python 3.12+. This build instead uses ``grpcio-tools``
  from conda-forge, which ships a pre-built ``grpc_cpp_plugin`` binary that
  CASA's cmake ``find_program()`` locates automatically.

- The ``protobuf`` and ``grpcio`` cmake config files installed by conda-forge
  have a target mismatch (``protobuf::libupb`` defined in gRPC's cmake but not
  in protobuf's). The ``fix-protobuf-cmake`` task patches these files
  automatically before each build. The patch is idempotent and is wired into
  the ``build-all`` dependency chain.

- If you switch Python versions or wipe the conda environment, run
  ``pixi run clean-protobuf`` before rebuilding to discard stale protobuf-generated
  C++ files (``*.pb.cc``/``*.pb.h``). These files embed a version check that
  will fail if the ``protoc`` version that generated them differs from the
  runtime protobuf headers.

Complete build
==============
This is the only command needed for a full build of ``casatools`` and
``casatasks``. It runs all steps in the correct order.

- ``pixi run build-all``
  Build using the default Python version for the current platform.

- ``pixi run -e arm-312 build-all``
  Build explicitly for ARM macOS with Python 3.12.

- ``pixi run -e linux-313 build-all``
  Build explicitly for Linux with Python 3.13.

To build a branch other than ``master``, set ``CASA_BRANCH=<branch>`` as an
environment variable. This setting is sticky — subsequent ``pixi run`` commands
will not change the branch unless you set it again.

To keep local edits rather than resetting to origin, prefix commands with
``CASA_DEVELOPMENT_MODE=true`` or export it as an environment variable.

Individual build steps
======================

Fetch source code
-----------------
- ``pixi run clone-repo``
  Fetch all CASA6 source code and apply patches.

Build components in order
-------------------------
Steps are run automatically by ``build-all``, but can be run individually.
Substitute ``-e arm-mac``, ``-e linux-dev``, or ``-e intel-mac`` as needed.

1. ``pixi run build-casacore``
2. ``pixi run build-casacpp``
   (Runs ``fix-protobuf-cmake`` automatically as a dependency.)
3. ``pixi run build-casatools``
   (Runs ``fix-protobuf-cmake`` automatically as a dependency.)
4. ``pixi run build-casatasks``

Optional: build libsakura from source
-------------------------------------
``libsakura`` is installed automatically via Conda Forge. To compile it locally from source instead:
- ``pixi run build-libsakura``

Run tests
=========
- ``pixi run test``
  Run the test suite. This is also run automatically as part of ``build-all``.

Environment management
======================
- ``pixi install``
  Install/update all environments from ``pixi.lock``.
- ``pixi shell -e arm-mac``
  Start a bash shell in a particular environment.
- ``pixi info``
  Show info about all pixi environments.
- ``pixi update swig``
  Update an individual package. Also update any related constraints in
  ``pixi.toml`` if necessary.
- ``pixi list -e arm-mac``
  Check what packages are installed in an environment.
- ``pixi run -e arm-mac python -V``
  Verify which Python version is active in an environment.
- ``pixi run -e arm-mac python -c 'import numpy as np; print(np.get_include())'``
  Verify the NumPy include path.

If an environment gets into a bad state (e.g. after a ``pip install`` that
downgrades conda-managed packages), delete it and reinstall cleanly::

  rm -rf .pixi/envs/default
  pixi install

To reset all environments and re-solve from scratch::

  rm -rf .pixi pixi.lock
  pixi install

ccache management
=================
All builds use ``ccache``, stored under the ``tmp/`` directory. A warm cache
makes incremental rebuilds very fast.

- ``pixi run ccache-stats``
  Show ccache statistics (hit rate, cache size, etc.).
- ``pixi run ccache-cleanup``
  Remove old/less-recently-used files to bring the cache within size limits.
  Does not empty the cache entirely.
- ``pixi run ccache-clear``
  Empty the cache completely.

Build directory management
==========================
These commands do not delete the source code. To force a truly clean checkout,
remove the source directory manually: ``rm -rf src``.

- ``pixi run clean-protobuf``
  Remove only the protobuf-generated C++ files (``*.pb.cc``/``*.pb.h``).
  Use this when switching Python or protobuf versions without doing a full
  rebuild. Much faster than ``clean`` when only the protobuf gencode is stale.

- ``pixi run clean``
  Remove all CASA build directories (casacpp, casatools, casatasks, casacore).
  Protobuf-generated files are removed as part of their parent build directories.

- ``pixi run clean-all``
  Remove build directories, the ccache cache, and the casatools/casatasks
  wheels. Does not remove source code or the pixi environments.

When to use each:

+---------------------+----------------------------------------------------------+
| Situation           | Command                                                  |
+=====================+==========================================================+
| Switched Python /   | ``pixi run clean-protobuf && pixi run build-casacpp``    |
| protobuf version    |                                                          |
+---------------------+----------------------------------------------------------+
| Normal clean build  | ``pixi run clean && pixi run build-all``                 |
+---------------------+----------------------------------------------------------+
| Wiped conda env     | ``rm -rf .pixi/envs/default && pixi install &&``         |
|                     | ``pixi run build-all``                                   |
|                     | (``fix-protobuf-cmake`` runs automatically)               |
+---------------------+----------------------------------------------------------+
| Full nuclear reset  | ``rm -rf .pixi pixi.lock && pixi install &&``            |
|                     | ``pixi run build-all``                                   |
+---------------------+----------------------------------------------------------+

Where are the wheels
====================
After a successful build, wheels are found in:

- ``src/casa6/casatools/dist/``
- ``src/casa6/casatasks/dist/``

The wheel filename encodes the Python version, e.g.
``casatools-6.7.6.6-cp312-cp312-macosx_15_0_arm64.whl`` for Python 3.12 on
ARM macOS.

``casaconfig`` must also be installed or provided. The simplest approach is
to unpack the wheels with ``unzip`` and ensure the unpacked directories along
with ``casaconfig`` are on your ``PYTHONPATH`` (or in the current directory).
