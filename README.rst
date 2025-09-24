======================
Automated CASA6 Builds
======================

This directory contains the build artifacts for building
`CASA6 <casa.nrao.edu>`__ with `pixi <https://pixi.sh/latest/>`__, which is a
wrapper around a `conda installation <https://mamba.readthedocs.io/en/latest/>`__.
A ``pixi.toml`` file is created to configure package constraints in a declarative
manner. From this, `pixi <https://pixi.sh/latest/>`__ creates a ``pixi.lock`` file
which ensures that the build is reproducable.

To use this, you must install `pixi <https://pixi.sh/latest/>`__.

Useful pixi Commands
--------------------

This build process was created because I needed a build of
`CASA6 <casa.nrao.edu>`__ for an Intel MacBook because CASA
no longer supports Intel MacBooks [ *as of Tue Sep 23 16:29:10 EDT 2025* ]. For this
reason, Intel MacBooks are the only platform currently tested. Below are the 
useful `pixi <https://pixi.sh/latest/>`__ commands.

Build casatools and casatasks
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- ``VERBOSE=1 pixi run -e intel-mac build-all``
  This is the only command you need to execute to build ``casatools`` and ``casatasks``. The
  remaining examples are useful but not required for a simple *one shot* build.
  ( *VERBOSE can be useful but is usually not used* )

Fetch Source Code
~~~~~~~~~~~~~~~~~
- ``pixi run -e intel-mac clone-repo``
  Fetch all of the CASA6 source code

Test Build Environment
~~~~~~~~~~~~~~~~~~~~~~
- ``pixi install -e intel-mac``
  Install ``intel-mac`` environment.
- ``pixi list -e intel-mac``
  Check on what packages are installed
- ``pixi run -e intel-mac python -V``
  See which version of Python is actually being used. Substitute other commands to
  check things out.
- ``pixi run -e intel-mac python -c 'import numpy as np; print(np.get_include())'``
  See the path to NumPy ( *from the NumPy conda issue!* )

Build components in order
~~~~~~~~~~~~~~~~~~~~~~~~~
- ``pixi run -e intel-mac build-casacore``
- ``pixi run -e intel-mac build-casacpp``
- ``pixi run -e intel-mac build-casatools``
- ``pixi run -e intel-mac build-casatasks``

Run Very Simple Test
~~~~~~~~~~~~~~~~~~~~

- ``pixi run -e intel-mac test``
  This test is run by default as part of the ``build-all`` task, but it can also be
  run by itself

Environment Management
~~~~~~~~~~~~~~~~~~~~~~
- ``pixi clean``
  Remove installed environments
- ``pixi reinstall --environment intel-mac``
  Rebuild the environment from scratch. This was useful once when the ``NumPy``
  conda install seemed to be missing the NumPy header files.
- ``pixi update swig``
  The update command can be used to update individual packages. Be sure to also
  update ``pixi.toml`` if there are related constraints for the updated package.

Where Are The Wheels
--------------------

After the build completes **successfully**, the wheels should be found in:

- ``src/casa6/casatools/dist``
- ``src/casa6/casatasks/dist``

``casaconfig`` must *somehow* be installed or provided. I just unpack the
wheels with ``unzip`` and make sure the unziped directories along with
``casaconfig`` are available in my ``PYTHONPATH`` ( *or the current directory* ).

Other Details
~~~~~~~~~~~~~

``pixi clean`` does not delete the source code directory so if you really want
to start from scratch it doesn't hurt to remove the source code directory to
insure a clean build:

- ``rm -rf src``

The build uses ``ccache`` so this might currently be required for all builds.
The ccache directory in beneath the ``tmp`` directory.

The ``pixi.toml`` file provides the constraints that direct the creation of
``pixi.lock`` by `pixi <https://pixi.sh/latest/>`__. If you want to generate
a completely new environment resolution, delete ``pixi.lock``. This will
result in `pixi <https://pixi.sh/latest/>`__ generating a list of new
package versions which satisfy the constraints provide in ``pixi.toml``.

