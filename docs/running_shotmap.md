Running Shotmap
---------------

At its simplest level, you can run shotmap.pl as follows. The following command invokes all default values in shotmap. 

    perl $SHOTMAP_LOCAL/scripts/shotmap.pl -i <path_to_input_data> -d <path_to_search_database>

Note that -d points to the path of the ShotMAP formatted search database, not the reference database. For more information,
please see section [Building a ShotMAP Search Database](search_databases.md).

As there are many ways to tune shotmap through the variety of options it provides, it may be simplest to specify your parameters 
through the use of a configuration file, which is simply a text file that contains a list of the command line parameters you want
shotmap to invoke (see section [Configuration Files] for more information). Generally, most users will NOT need to bother building 
a configuration file.

    perl scripts/build_conf_file.pl        --conf-file=<path_to_configuration_file> [options]
    perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configuration_file>

If desired, you override the configuration file settings at the command line when running shotmap:

    perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configuration_file> [options]

If you want to rerun or reprocess part of the workflow (say, with different options), you can jump to a particular step using the 
--goto option. The command would subsequently look like the following:

    perl $SHOTMAP_LOCAL/scripts/shotmap.pl -i <path_to_input_data> -d <path_to_search_database> -o <path_to_output_ffdb> --goto=<goto_value>

For a full list of the values that the --goto option can accept, see the [options] documentation. To obtain a project identifier, either see previous
shotmap output, check your flat file data repository, or check your mysql database for the project identifier that corresponds to your data.