Configuration files
-------------------

If you would like you specifically configure shotmap, you can either append additional command line options at run time, or
set up a configuration file (see below). If you would like to use a configuration file, then there are some additional 
installation steps:

1. Now we need a configuration file that tells shotmap where to find the data you want to process it and how you want it to be analyzed. The following script builds a configuration file for you:

   perl scripts/build_conf_file.pl  --conf-file=<path_of_output_conf_file> [options]

Note that this script can receive via the command line any of shotmap's options. The simplest configuration file (running the analysis on a local machine without using a mysql database and using as many defaults as possible) would look like the following:

     perl scripts/build_conf_file.pl --conf-file=<path_of_output_conf_file> --nprocs=<number_of_processors> --rawdata=<directory_containing_metagenome> --refdb=<directory_containing_protein_families>

Note: if you elect to use a mysql database, this script will prompt you to store your password in the file and will lock the file down with user-only read permissions

4. Test your configuration file and installation using the following script:

   perl scripts/test_conf_file.pl --conf-file=<path_of_configuration_file>

This will validate your shotmap settings and verify that your installation and infrastructure is properly configured. Note that there are many edge cases and this script may not yet adequately check them all. Please contact the author if you find that this script fails to detect problems with your configuration.

5. Run shotmap:

   perl scripts/shotmap.pl --conf-file=<path_of_configuration_file> [options]

Note that you can override configuration file settings by invoking command line options. The first time you run shotmap, you'll need to format your search database. This can be invoked as follows:

     perl scripts/shotmap.pl --conf-file=<path_of_configuration_file> --build-searchdb

Once formatted, you do not need to reformat, unless you change search database related options (see below). Also, If you are using a cloud (i.e., --remote), you'll need to conduct a one-time transfer of your search database to the remote server using --stage:

     perl scripts/shotmap.pl --conf-file=<path_of_configuration_file> --build-searchdb --stage


