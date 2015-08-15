Configuration files
-------------------

If you would like you specifically configure shotmap, you can either append additional command line options at run time, or
set up a configuration file (see below). A configuration file is simply a text file that contains command line options you want 
shotmap to invoke, one option per line. Configuration files simplify the command you use to run shotmap and make repeated processing with 
custom parameters trivial. Most users won't need to bother with setting up a configuration file.

An example configuration file can be found [here](../data/config/sample_config_file.txt).

To build a configuration file, follow these steps:

1. Now we need a configuration file that tells shotmap where to find the data you want to process it and how you want it to be analyzed. The script [build_conf_file.pl](build_conf_file.pl.md) builds a configuration file for you:

        perl scripts/build_conf_file.pl  --conf-file=<path_of_output_conf_file> [options]

    Note that this script can receive via the command line any of shotmap's options. The simplest configuration file (running the analysis on a local machine without using a mysql database and using as many defaults as possible) would look like the following:

        perl scripts/build_conf_file.pl --conf-file=<path_of_output_conf_file> --nprocs=<number_of_processors> --rawdata=<directory_containing_metagenome> --refdb=<directory_containing_protein_families>

    Note: if you elect to use a mysql database (Advanced users only!), this script will prompt you to store your password in the file and will lock the file down with user-only read permissions

2. Test your configuration file and installation using the following script:

        perl scripts/test_conf_file.pl --conf-file=<path_of_configuration_file>

    This will validate your shotmap settings and verify that your installation and infrastructure is properly configured. Note that there are many edge cases and this script may not yet adequately check them all. Please contact the author if you find that this script fails to detect problems with your configuration.

3. Run shotmap:

        perl scripts/shotmap.pl --conf-file=<path_of_configuration_file> [options]

    Note that you can override configuration file settings by invoking command line options. In the following example, we override the --trans-method value in our configuration file with the command line option so that shotmap.pl invokes the 6FT value for the --trans-method parameter.

        perl scripts/shotmap.pl --conf-file=<path_of_configuration_file> --trans-method=6FT



