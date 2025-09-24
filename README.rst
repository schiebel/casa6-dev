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

The version of `SWIG <https://www.swig.org/>`__ is pinned to ``>=3.0,<4`` because
I don't know if version four is currently supported by ``casatools`` this is
problematic for ARM versions of macos because conda does not have an ARM version
of SWIG 3, so I need to investigate this problem.

Useful pixi Commands
--------------------

These are the useful `pixi <https://pixi.sh/latest/>`__ for building
`CASA6 <casa.nrao.edu>`__. This build process was created because I needed a
build of `CASA6 <casa.nrao.edu>`__ for an Intel MacBook and CASA no longer
supports Intel MacBooks [ *Tue Sep 23 16:29:10 EDT 2025* ], and for this
reason, Intel MacBooks are the only platform tested.

Primary Commands
~~~~~~~~~~~~~~~~
- ``pixi run -e intel-mac clone-repo``
  Fetch all of the CASA6 source code
- ``VERBOSE=1 pixi run -e intel-mac build-all``
  Build ``casatools`` and ``casatasks``
  ( *VERBOSE can be useful but is usually not used* )
- ``pixi reinstall --environment intel-mac``
  Rebuild the environment from scratch. This was useful once when the ``NumPy`` conda install seemed to be missing the NumPy header files.
- ``pixi run -e intel-mac python -c 'import numpy as np; print(np.get_include())'``
  See the path to NumPy ( *from the ``NumPy`` conda issue!* )
- ``pixi run -e intel-mac python -V``
  See which version of Python is actually being used

Build components in order
~~~~~~~~~~~~~~~~~~~~~~~~~
- ``pixi run -e intel-mac build-casacore``
- ``pixi run -e intel-mac build-casacpp``
- ``pixi run -e intel-mac build-casatools``
- ``pixi run -e intel-mac build-casatasks``

Run Very Simple Test
~~~~~~~~~~~~~~~~~~~~
While this test is run by default as part of the ``build-all`` task, it can also be run by itself

- ``pixi run -e intel-mac test``


Where Are The Wheels
--------------------

After the build completes **successfully**, the wheels should be found in:

- ``src/casa6/casatools/dist``
- ``src/casa6/casatasks/dist``

``casaconfig`` most *somehow* be installed or provided. I just unpack the
wheels with ``unzip`` and make sure the unziped directories along with
``casaconfig`` are available in my ``PYTHONPATH`` ( *or the current directory* ).

