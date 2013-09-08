shotmap
=======

A Shotgun Metagenome Annotation Pipeline

Overview
--------

Shotmap is a software workflow that functionally annotates and compares shotgun metagenomes. Specifically, it will:

1.  Compared unassembled or assembled metagenomic sequences to a protein family database
2.  Calculate metagenome functional abundance and diversity
3.  Compare metagenomes using a variety of statistical and ecological tools
4.  Identify protein families that differentiate metagenomes

Shotmap manages the information and data associated with this workflow in a relational database and will 
handle the communication with and transfer of data between a database server and a distributed computer cluster (SGE).

Quickstart
__________

Once you have a configuration file built (see below), all you need to do to annotate your metagenome is:

     perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configutation_file>


Requirements & Dependencies
---------------------------


Installation
------------

You have to set your SHOTMAP_LOCAL environment variable.

    export SHOTMAP_LOCAL=/my/home/directory/shotmap       

Where this is your github-checked-out copy of shotmap

Now you need build a configuration file using build_conf_file.pl as follows:
   
    perl $SHOTMAP_LOCAL/scripts/build_conf_file.pl --conf-file=<path_to_configuration_file> [options]

NOTE: You may store your MySQL password in this file, which will be locked down with user-only read permissions.

You have to set up passphrase-less SSH to your computational cluster. In this example, the cluster should have a name like "compute.cluster.university.edu".
Follow the links at "https://www.google.com/search?q=passphraseless+ssh" in order to find some solutions for setting this up. It is quite easy!

Running Shotmap
---------------

You can run shotmap.pl as follows. 

    perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configuration_file>

Note that the FIRST TIME you run it, you need to build either a HMM (--hdb) or blast (--bdb) search database, and you have to STAGE (i.e. transfer) the files to the remote cluster with the --stage option. So your first run will look something like this:
     perl $SHOTMAP_LOCAL/scripts/shotmap.pl --bdb --stage 

On subsequent runs, you can omit "--hdb" and "--bdb" and "--stage". 

If desired, you override the configuration file settings at the command line when running shotmap:

   perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configuration_file> [options]

If you want to rerun or reprocess part of the workflow (say, with different options), you can jump to a particular step using the --goto option. This 
also requires setting the --pid (project_id) options so that shotmap knows which data set in the MySQL database it should reference. The command would
subsequently look like the following:

   perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configuration_file> --goto=<goto_value> --pid=<project_id>

For a full list of the values that the --goto option can accept, see the [options] documentation. To obtain a project identifier, either see previous
shotmap output, check your flat file data repository, or check your mysql database for the project identifier that corresponds to your data.

OPTIONS
-------

###CONFIGURATION FILE:

#####--conf-file=/PATH/TO/CONFIGURATION_FILE (optional, but RECOMMENDED, no default)
Location of the configuration file that shotmap should use. This file can be built using "${SHOTMAP_LOCAL}/scripts/build_conf_file.pl" and contains
a list of shotmap run-time arguments, as below, one per row. Configuration file options can be overridden when calling shotmap with run-time arguments. 
You may also copy and edit a configuration file, to streamline additional anlayses that vary in only a small number of settings.

When building a configuation file, you will be asked to enter your MySQL password. You are not required to put your password in this file, though it is
recommended as passing that argument to shotmap.pl at run time will place your password in your history. The configuation file is secured with user-only,
read-only permissions. Note that this is NOT a failsafe security method!

###METAGENOME DATA ARGUMENTS:

#####--projdir=/PATH/TO/PROJECT/DIR (or -i /PATH/TO/PROJECT/DIR)     (REQUIRED argument)
    Location of the metagenomic sequences to be processed. Each metagenomic samples should be in a single
    and seperate file with a unique file prefix (e.g., O2.UC-1_090112) and have .fa as the file suffix.
    Shotmap currently only accepts fasta formatted input sequence files.

    This directory can optionally contain a file that encodes sample metadata \(i.e., ecological conditions
    associated with the metagenomic sample\). This file should be named "sample_metadata.tab". See the 
    [details] section of the documentation or the sample data for more information on this file format. The
    contents of this file will be placed in the samples table and used to partition samples into groups 
    during statistical analysis and identify covariation between family abundance and metadata parameters.

    This directory can optionally contain a file that describes the project data \(e.g., "Healhy human gut
    microbiome samples"\). This file should be names "project_description.txt" and has no format. The 
    contents of this file will be placed in the project table of the database.

###SHOTMAP DATA REPOSITORY ARGUMENTS:

#####--ffdb=/PATH/TO/FLATFILES  (or -d /PATH/TO/FLATFILES)     (REQUIRED argument)
    local flat file database path

###DATABASE ARGUMENTS:

*--dbhost=YOUR.DATABASE.SERVER.COM           (REQUIRED argument)*
    The ip address or hostname of machine that hosts the remote MySQL database. 

    Note that you must have select, insert, and delete permissions in MySQL. Also, you must be able 
    to READ DATA INFILE from /tmp/ (typical default setting in MySQL).

**--dbuser=MYSQL_USERNAME                     (REQUIRED argument)**
    MySQL username for logging into mysql on the remote database server.

--dbpass=MYSQL_PASSWORD (in plain text)     (REQUIRED argument)
    The MySQL password for <dbuser>, on the remote database server.
    It is best to store this in a secure configuration file as calling this option on the command line will
    store your password in your terminal history.

--dbname=DATABASENAME (OPTIONAL argument: default is "ShotDB")
    The name of the MySQL database that will store the project data and all results.

--dbschema=SCHEMANAME (OPTIONAL argument: default is "Shotmap::Schema")
    The DBIx schema name. If modifications to the database schema are made and saved under a different DBIx library,
    then change this name. Most users will never need to worry about this option.

--bulk (Optional, default=ENABLED)
    When set, data is loaded into the MySQL using a LOAD DATA INFILE statement. This results in massive improvements
    when inserting a massive number of rows into a table. This requires having MySQL configured such that it can 
    read data from /tmp/ (this is a typical setting).

    You cannot set this option and --multi at the same time.

--bulk_count=INTEGER (Optional, default=10000)
    Determines how many rows should be simultaneously inserted into the MySQL database when using LOAD DATA INFILE.
    Only used if --bulk is invoked.

--multi (Optional, default=DISABLED)
    Invokes a multi-row INSERT statement via DBI. This is faster than using a single insert statement for each row,
    but slower than --bulk. Only recommended if your system cannot be configured such that you can use LOAD DATA
    INFILE statements in MySQL.

--multi_count=INTEGER (Optional, no default)
    Determines how many rows should be simultaneously inserted into the MySQL database when using --multi. Only 
    used if --multi is invoked.

###REFERENCE SEARCH DATABASE ARGUMENTS:

--refdb=/PATH/TO/REFERENCE/FLATFILES     (REQUIRED argument)
    Location of the protein family reference data.  Each family must have a HMM (if running HMMER tools) 
    or a set of protein sequences sequences that are members of the family (if running blast-like tools).

    Files in this directory should correspond to an individual family, with the prefix of the file being 
    the family identifier (e.g., IPR020405) and the suffix should either be .hmm (for HMMs) or .faa 
    (for protein sequences). These files can be placed in any subdirectory stucture within this upper 
    level directory, but subdirectories containing HMMs must have the characters "hmms" in the directory
    name, while subdirectories containing sequences must have "seqs" in the directory name.

--searchdb-prefix=STRING (REQUIRED argument)
    The prefix string that defines the name of the search database(s) (sequence and HMM) that shotmap will build.
    The use of additional arguments (see below) may result in additional strings being concattenated to this prefix.

--hdb (optional, default is to not build a database)
    Should we build a hmm db for a search using HMMER tools?

--hmmsplit=INTEGER (required if using --hdb, no default)
    Sets the number of hmms to put in each of the partitions of the HMM search database built by Shotmap. Only used
    when building the HMM search db (i.e., --hdb)

--bdb (optional, default is to not build a database)
    Should we build a protein sequence database for a search using blast-like tools (e.g., blast, last, rapsearch)?
    Also requires setting either --use_blast, --use_last, or --use_rapsearch so that shotmap knows how to format
    the database files (e.d., formatdb, lastdb, prerapsearch)

--blastsplit=INTEGER (required if using --bdb, no default)
    Sets the number of protein sequences to put in each of the partitions of the protein sequence search database 
    built by Shotmap. Only used when building the protein sequence search db (i.e., --bdb)

--nr (Optional, set off by default)
    When building a protein sequence (blast-like) search database, collapses identical sequences found within
    the same family (i.e., build a non-redundant database).

--db_suffix=STRING (required if using --bdb and --userapsearch, default "rsdb")
    When building a protein sequence (blast-like) database, appends this string to the end of binary formatted
    database files.

    Currently only used by RAPsearch.

--forcedb
    Force database to be built. Overwrites a previously built search database with the same name and settings!

###REMOTE COMPUTATIONAL CLUSTER ARGUMENTS:

--rhost=SOME.CLUSTER.HEAD.NODE.COM     (REQUIRED argument)
    The ip address or hostname of machine that manages the remote computational cluster. 
    Usually this is a cluster head node. 

    Note that this machine must currently run SGE!

--ruser=USERNAME                       (REQUIRED argument)
    Remote username for logging into the remote computational cluster / machine.
    Note that you have to set up passphrase-less SSH for this to work. Google it!

--rdir=/PATH/ON/REMOTE/SERVER          (REQUIRED argument)
    Remote path where we will store a temporary copy of the shotmap data repository on the remote machine and store results

--rpath=COLON_DELIMITED_STRING         (optional, default assumes that the executables will just be on your user path)
    Example: --rpath=/remote/exe/path/bin:/somewhere/else/bin:/another/place/bin
    The PATH on the remote computational server, where we find various executables like 'rapsearch'.
    COLONS delimit separate path locations, just like in the normal UNIX path variable.

--remote  (Default: ENABLED)
    (or --noremote to disable it)
    Use a remote compute cluster. Specify --noremote to run locally (note: local running has NOT BEEN DEBUGGED much!)

--stage  (Default: disabled (no staging))
    Causes the search database to be copied to the remote cluster. You should not have to do this except when you build a 
    new search database.

--wait=SECONDS (optional, default is 30 seconds)
    How long should we wait before checking the status of activity on the remote cluster?

--scratch (optional, default: DISABLED)
    Forces slave nodes to use local scratch space when running processes on the compute cluster

###TRANSLATION/GENE CALLING METHODS:

--trans-method=STRING (required, default: "transeq")
    Determines the algorithm that should be used to convert metagenomic reads into protein coding space. Currently, only 
    "transeq" is an accepted value, but future work will incorporate metagenomic gene calling tools.
--split-orfs (optional, default=ENABLED)
    (disable with --noslit-orfs)
    When set, translated orfs are split into sub-orfs on stop codons.

--min-orf-len=INTEGER (required, default=0)
    Removes translated reads (orfs) shorter than this length (in bp) from all subsequent analyses. Set to 0 if you want no filtering

###SEARCH METHOD ARGUMENTS (One or more MUST be set):

--use_hmmsearch (optional, default=DISABLED)
    Tells shotmap to compare metagenomic reads into families using hmmsearch (HMMER)
    
--use_hmmscan (optional, default=DISABLED)
    Tells shotmap to compare metagenomic reads into families using hmmscan (HMMER)

--use_blast (optional, default=DISABLED)
    Tells shotmap to compare metagenomic reads into families using blast.  Also tells Shotmap to configure the search database
    for blast using formatdb

--use_last (optional, default=DISABLED)
    Tells shotmap to compare metagenomic reads into families using last.  Also tells Shotmap to configure the search database
    for last using lastdb

--use_rapsearch (optional, default=DISABLED)
    Tells shotmap to compare metagenomic reads into families using RAPsearch. Also tells Shotmap to configure the search database
    for rapsearch using prerapsearch

--forcesearch (optional, default=DISABLED)
    Forces shotmap to research all orfs against all families. This will overwrite previous search results! Note that this 
    automatically forces shotmap to also reparse all search results. When run with --goto=P, forcesearch can be used to 
    explicilty reparse search results.

###SEARCH RESULT PARSING OPTIONS:

--parse-score=FLOAT (optional, no default)
    Sets the minimum bit score that must be reported for an alignment if it is to be retained in the searchresults MySQL table
    
--parse-coverage=FLOAT (optional, no default)
    Sets the minimum coverage (orf length / alignment length)  that must be reported for an alignment if it is to be retained
    in the searchresults MySQL table

--parse-evalue=FLOAT (optional, no default)
    Sets the maximum evalue that must be reported for an alignment if it is to be retained in the searchresults MySQL table

--small-transfer (optional, default=DISABLED)
    Only transfer the parsed search results, not the raw search results, from the remote cluster

###CLASSIFICATION THRESHOLDS

--class-score (optional, no default)
    Sets the minimum bit score that must be reported for an alignment if it is to be considered for classification into a family

--class-coverage (optional, no default)
    Sets the minimum coverage (orf length / alignment length) that must be reported for an alignment if it is to be considered 
    for classification into a family

--class-evalue (optional, no default)

--top-hit (optional, default=ENABLED)
    (disable with --notop-hit)
    When set, an orf or read is classified into the top scoring family that passes all classification thresholds. --top-hit is
    currently required and Shotmap will not run to completion when --notop-hit is set!

--hit-type=STRING (required, default="read")
    Determines the object that is being subject to classification. Currently only accepts "orf" or "read". When the value is "orf",
    each orf from a read can be classified into a family. When the value is "read", only the top scoring orf that passes all 
    classification thresholds is classifed into a family. All other orfs are discarded. This is recommended for short read data!

###ABUNDANCE CALCULATION ARGUMENTS

--abundance-type=STRING (required, default="coverage")
    Determines the type of abundance metric that shotmap will calculate. Currently accepts values "binary" and "coverage". When
    the value is "binary", each read/orf counts equally to the abundance calculation \(i.e., abundance is equal to the total number
    of reads that are classified into the family\). When the value is "coverage", abundance is weighted by orf/read to family 
    alignment length (i.e., abundance is equal to total number of base pairs that align to the family).

--normalization-type=STRING (required, default="target-length")

    Determines if estimates of abundance should be length corrected, which could be important if family length varies greatly within
    a metagenome. Currently accepts ("none", "family_length", "target_length").
 
    When set to "none", no length normalization takes place. When set to "family_length", family abundance is divided by the average 
    family length (or hmm length is using HMMER). When set to "target_length", each read/orfs contribution to abundance is individually
    normalized by the length of the protein sequence it aligns to. Note that these values also influence relative abundance corrections.

###GENERAL ARGUMENTS, NOT SET IN CONFIGURATION FILE:

--pid=INTEGER (optional, no default)

    The MySQL project identifier corresponding to data that you want to reprocess. Not used when analyzing data for the first time!

--goto=STRING

Go to a specific step in the workflow. Will complete all subsequent steps, but none of the prior ones. As a result, it requires
that the prior steps successfully completed.
Valid options are:
* 'T' or 'TRANSLATE'   - Read translation/coding sequence annotation
* 'O' or 'LOADORFS'    - Load translated reads (orfs) into mysql database
* 'B' or 'BUILD'       - Build search database
* 'R' or 'REMOTE'      - Stage search database on remote cluster
* 'S' or 'SCRIPT'      - Build script for conducting massively parallel search on remote cluster
* 'X' or 'SEARCH'      - Search all orfs against all protein families
* 'P' or 'PARSE'       - Parse the search results and prepare
* 'G' or 'GET'         - Transfer the results from the remote cluster
* 'L' or 'LOADRESULTS' - Load the results into the mysql database
* 'C' or 'CLASSIFY'    - Classify reads/orfs into protein families
* 'D' or 'DIVERSITY'   - Calculate intra- and inter-sample diversity and family abundances

  --reload (optional, default=DISABLED)

Normally, shotmap emits a warning when you attempt to analyze data that you have already processed at some level with shotmap.
It prefers that you use the --goto option and amend your settings, but you can completely start over using the --reload option.
!!!Note that this will remove your prior data from the MySQL database and the shotmap data repository!!!

--verbose (optional, default=DISABLED)

Verbose output is produced. Helpful for troubleshooting. Not currently implemented!


Details
-------
