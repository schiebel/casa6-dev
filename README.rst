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
`CASA6 <casa.nrao.edu>`__ for an Intel MacBook. CASA
no longer supports Intel MacBooks [*as of Tue Sep 23 16:29:10 EDT 2025*], and
*indeed*, Apple will also soon no longer support Intel MacBooks. However, this
unfortunately means that Intel MacBooks are the only platform with which this
build process has been tested. The version of casa6 that this was tested with was
`6.7.3.0 <https://open-bitbucket.nrao.edu/projects/CASA/repos/casa6/commits/6d3646c1b9c5296e4b63798ad8ba722e3fe137a4>`__.
Below are the `pixi <https://pixi.sh/latest/>`__ commands to build
``casatools`` and ``casatasks``. 

The `pixi <https://pixi.sh/latest/>`__ configuration is controled by the
the ``pixi.toml`` file. It provides the constraints that pixi uses to direct
the creation of ``pixi.lock`` file. If you want to generate a completely new
environment resolution, delete ``pixi.lock``. This will result in
`pixi <https://pixi.sh/latest/>`__ generating a list of new package versions
which satisfy the constraints provided in ``pixi.toml``.

All of these pixi commands build the **current origin state of a given branch**,
stashing any modifications and fetching the current state from the git ``origin``.
To keep local edits, add ``DEVELOPMENT_MODE=true`` to the beginning of all
``pixi run ...`` commands or ``export`` it as an environment variable. *Maybe
this will be made smarter in the future.*

Build casatools and casatasks
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- ``VERBOSE=1 pixi run -e intel-mac build-all``
  This is the only command you need to execute to build ``casatools`` and ``casatasks``. The
  remaining examples are useful but not required for a simple *one shot* build. To build a
  branch **other than the main branch** set ``CASA_BRANCH=<desired-branch>`` as an environment
  variable as ``VERBOSE`` is set here (*VERBOSE can be useful but is usually not used*)
  The ``CASA_BRANCH=...`` setting is sticky in the sense that future ``pixi run ...`` commands
  will not change the branch.

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
- ``pixi shell -e intel-mac``
  Start a bash shell to explore a particular environment.
- ``pixi info``
  Show info about all of the pixi environments.

ccache Management
~~~~~~~~~~~~~~~~~
The commands use ``ccache`` for all builds. The ccache directory in beneath the
``tmp`` directory.

- ``pixi run ccache-stats``
  Show ``ccache`` information. 
- ``pixi run ccache-cleanup``
  Deletes old and less recently used files to bring the cache back within the **default**
  size and file limits. It does not empty the entire cache.
- ``pixi run ccache-clean``
  Deletes everything in the cache, leaving it completely empty.

Build Directory Management
~~~~~~~~~~~~~~~~~~~~~~~~~~
These commands do not delete the source code directory so if you really want to
start from scratch it doesn't hurt to remove the source code directory to insure
a **complete** build from scratch ``rm -rf src``.

- ``pixi run clean``
  Remove the build directories.
- ``pixi run clean-all``
  Remove the build directories, the ``ccache`` cache and the casatools and casatasks wheels.


Where Are The Wheels
--------------------
After the build completes **successfully**, the wheels should be found in:

- ``src/casa6/casatools/dist``
- ``src/casa6/casatasks/dist``

``casaconfig`` must *somehow* be installed or provided. I just unpack the
wheels with ``unzip`` and make sure the unziped directories along with
``casaconfig`` are available in my ``PYTHONPATH`` ( *or the current directory* ).
