install.pl
==========

Usage:
------
    
    perl install.pl
     
Description: 
------------

This script attempts to install all of the dependencies needed to run ShotMAP. A more detailed description of the 
installation process, which this script automates, can be found [here](installation_guide.md).

Examples:
---------

Most users will only ever need to use the default settings:

    perl install.pl

If you only want to install R libraries

    perl install.pl --rpacks

If you only want to download the source code of the software dependencies (to later build by hand)

    perl install.pl --get 

Options:
--------

* **--perlmods** (OPTIONAL) DEFAULT: ENABLED

    Should the perl module dependencies be installed? Disable with --noperlmods.

* **--rpacks** (OPTIONAL) DEFAULT: ENABLED

    Should the R package dependencies be installed? Disable with --norpacks.

* **--algs** (OPTIONAL) DEFAULT: ENABLED

    Should the external algorithms used by shotmap (e.g., gene prediction, homology search tools) 
    be installed? Disable with --noalgs.

* **--clean** (OPTIONAL) DEFAULT: ENABLED

    Should we wipe any previously installed external algorithms? Disable with --noclean.

* **--get** (OPTIONAL) DEFAULT: ENABLED
  
    Should we download source code for the external algorithms? Disable with --noget. Note that this
    assumes the machine has an internet connection.

* **--build** (OPTIONAL) DEFAULT: ENABLED

    Should we attempt to build the source code for the external algorithms? Disable with --nobuild.
    Note that some machines may have architectures that prevent this option from succeeding for all
    programs. Building by hand may be needed. For most dependencies, we try to use precompiled x86
    binaries, which mitigates the amount of building actually needed. See --source for attempts involving
    non-x86 binaries.

* **--test** (OPTIONAL) DEFAULT: ENABLED

  Should we execute tests or checks for the external algorithms being installed? Disable with --notest

* **--source** (OPTIONAL) DEFAULT: DISABLED

  Should we build from source code, even when there are precompiled x86 binaries available? You probably
  want to try this if the default option failed or if you are running on a system architecture where x86
  binaries are incompatible.

* **--db** (OPTIONAL) DEFAULT: DISABLED

  Should we attempt to install the dependencies for interfacing with a MySQL library? Advanced users only.
