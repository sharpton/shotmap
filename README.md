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
----------

Once you have a configuration file built (see below), all you need to do to annotate your metagenome is:
     
     perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configutation_file>


Requirements & Dependencies
---------------------------

###Perl Modules

####Non-standard Libraries (you probably have to install these)

* DBIx::Class
* DBIx::BulkLoader::Mysql
* IPC::System::Simple
* IO::Uncompress::Gunzip
* IO::Compress::Gzip
* Bio::SeqIO 
* Carp
* File::Util
* File::Cat
* Unicode::UTF8
* XML::DOM
* XML::Tidy
* Math::Random
* Parallel::ForkManager

####Standard Libraries (you probably don't have to install these)

* DBI
* DBD::mysql
* File::Basename
* File::Copy
* File::Path
* File::Spec
* Getopt::Long

###MySQL


###R Packages

* vegan
* ggplot2
* multtest
* reshape (still?)

###Translation/Gene Annotation Tools

* transeq

###Homology Detection Tools

* HMMER (v3)
* BLAST
* LAST
* RAPsearch (v2)

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

Note that the FIRST TIME you run it, you need to build either a search database. Also, if you are using a remote computing cluster, you will have to STAGE 
(i.e. transfer) the files to the remote cluster with the --stage option. So your first run will look something like this:

    perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configuration_file> --build-searchdb --stage

On subsequent runs, you can omit "--build-searchdb" and "--stage". 

If desired, you override the configuration file settings at the command line when running shotmap:

    perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configuration_file> [options]

If you want to rerun or reprocess part of the workflow (say, with different options), you can jump to a particular step using the --goto option. This 
also requires setting the --pid (project_id) option so that shotmap knows which data set in the MySQL/flat file databases it should reference. The command would
subsequently look like the following:

    perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configuration_file> --goto=<goto_value> --pid=<project_id>

For a full list of the values that the --goto option can accept, see the [options] documentation. To obtain a project identifier, either see previous
shotmap output, check your flat file data repository, or check your mysql database for the project identifier that corresponds to your data.

OPTIONS
-------

###CONFIGURATION FILE:

* **--conf-file=/PATH/TO/CONFIGURATION_FILE** (optional, but RECOMMENDED) NO DEFAULT VALUE

  Location of the configuration file that shotmap should use. This file can be built using "${SHOTMAP_LOCAL}/scripts/build_conf_file.pl" and contains
  a list of shotmap options, one per row. Configuration file options can be overridden when calling shotmap with run-time arguments. 
  You may also copy and edit a configuration file, to streamline additional anlayses that vary in only a small number of settings.

  When building a configuation file, you will be asked to enter your MySQL password if you are using a relational database to manage your results. 
  You are not required to put your password in this file, though it is
  recommended as passing that argument to shotmap.pl at run time will place your password in your history. The configuation file is secured with user-only,
  read-only permissions. Note that this is NOT a failsafe security method!

###METAGENOME DATA ARGUMENTS:

* **--rawdir=/PATH/TO/PROJECT/DIR** (REQUIRED argument) NO DEFAULT VALUE

  Location of the metagenomic sequences to be processed. Each metagenomic sample should be in a single
  and seperate file with a unique file prefix (e.g., O2.UC-1_090112) and have .fa or .fa.gz (if a gzipped compressed file) as the file suffix.
  Shotmap currently only accepts fasta formatted input sequence files.

  This directory can optionally contain a file that encodes sample metadata \(i.e., ecological conditions
  associated with the metagenomic sample\). This file should be named "sample_metadata.tab". See the 
  [details] section of the documentation or the sample data for more information on this file format. The
  contents of this file will be placed in the samples table and used to partition samples into groups 
  during statistical analysis and identify covariation between family abundance and metadata parameters.

  This directory can optionally contain a file that describes the project data \(e.g., "Healhy human gut
  microbiome samples"\). This file should be names "project_description.txt" and has no format. The 
  contents of this file will be placed in the project table of the database if using a mysql database.

* **--seq-split-size=INTEGER** (REQUIRED argument) DEFAULT --seq-split-size=100000

  Tells shotmap to partition each sample's raw sequence file into subsets with INTEGER number of sequences in each set. Tuning this parameter
  can improve parallelization and throughput. 

  Note that once this value has been set, it cannot be amended in subsequent reanalyses of a sample (i.e., when using --goto).			     

###SHOTMAP DATA REPOSITORY ARGUMENTS:

* **--ffdb=/PATH/TO/FLATFILES** (REQUIRED argument) NO DEFAULT VALUE
  
    Location of the flat file shotmap data repository. Shotmap creates this location and stores both
    the search database and the reads, orfs, search results, and statistical output. Multiple projects
    can be stored in the same data repository. See details for more information about the structure of
    this directory.


###REFERENCE SEARCH DATABASE ARGUMENTS:

* **--refdb=/PATH/TO/REFERENCE/FLATFILES**  (REQUIRED argument) NO DEFAULT VALUE

    Location of the protein family reference data.  Each family must have a HMM (if running HMMER tools) 
    or a set of protein sequences sequences, in fasta format, that are members of the family (if running blast-like tools).

    Files in this directory should correspond to an individual family, with the prefix of the file being 
    the family identifier (e.g., IPR020405) and the suffix should either be .hmm (for HMMs) or .fa
    (for protein sequences). These files can be placed in any subdirectory stucture within this upper 
    level directory; shotmap will recurse through all subdirectories and append all appropriate .hmm or .fa files to the list
    of families that will be incorporated into the search database.

* **--build-searchdb** (REQUIRED IF SEARCH DATABASE HAS NOT BEEN CONSTRUCTED) DEFAULT: DISABLED

    Tell shotmap to build a search database using the reference sequences identified by --refdb.

    This option must be run at least one time for each search database you elect to use with shotmap. 

* **--searchdb-name=STRING** (REQUIRED argument) NO DEFAULT VALUE

    The name of the search database(s) (sequence and HMM) that shotmap will build. 
    The use of additional arguments (see below) may result in additional strings being concattenated to this prefix. For example,
    if --searchdb-name=KEGG and --nr is invoked, the search database name will be KEGG_nr

* **--searchdb-split-size=INTEGER** (OPTIONAL argument) NO DEFAULT VALUE

    Split the search database into subsets with INTEGER number of hmms/sequences in each subset. This can improve parallelization and optimization
    of the remote compute cluster (i.e., smaller search database files are transferred to /scratch on slave nodes).

    Most users will not set this option, which results in a single, large search database, and will instead only change --seq-split-size.

* **--nr** (Optional argument) DEFAULT: ENABLED

    Build a non-redundant protein sequence search database.  	  

    When building a protein sequence (blast-like) search database, collapses identical sequences found within
    the same family. This option has no affect on hmm-based searches.

* **--db-suffix=STRING** (OPTIONAL argument) DEFAULT: --db_suffix=rsdb

    When building a protein sequence (blast-like) database, appends this string to the end of binary formatted
    database files.

    Currently only invoked when --search-method=rapsearch. Most users will never need to worry about this option.

* **--force-searchdb** (OPTIONAL argument) DEFAULT: DISABLED

    Force a search database to be built. Overwrites a previously built search database with the same name and settings!

* **--family-subset=PATH/TO/SUBSET_FILE** (OPTIONAL argument) NO DEFAULT

    Tell shotmap to build a search database for only a subset of the families found in --refdb. The value of this option
    must point to a file that contains family identifiers, one per line, to include in the search database.

###MYSQL DATABASE ARGUMENTS:

* **--db=none|full|slim** (REQIRED argument) DEFAULT: --db=none

  Sets whether a mysql database should be used in this analysis and, if so, whether all data (--db=full) or
  only essential data (--db=slim) should be stored. 

  To turn off the use of mysql, set --db=none. Note that we observe large improvements in analytical throughput
  when a database is not invoked, though there are data organizational and management benefits in using a database.

* **--dbhost=YOUR.DATABASE.SERVER.COM** (REQUIRED IF --db=slim or --db=full) DEFAULT: --db=none

  The ip address or hostname of machine that hosts the remote MySQL database. For most users, this parameter will
  not be set (i.e., --db=none) or --dbhost=localhost

  Note that you must have select, insert, and delete permissions in MySQL. Also, you must be able 
  to READ DATA INFILE from /tmp/ (typical default setting in MySQL).

* **--dbuser=MYSQL_USERNAME** (REQUIRED IF --db=slim or --db=full) NO DEFAULT VALUE

  MySQL username for logging into mysql on the database server.

* **--dbpass=MYSQL_PASSWORD** (REQUIRED IF --db=slim or --db=full) NO DEFAULT VALUE

  The MySQL password for <dbuser>, on the remote database server.
  It is best to store this in a secure configuration file as calling this option on the command line will
  store your password in your terminal history.
  
* **--dbname=DATABASENAME** (REQUIRED IF --db=slim or --db=full) NO DEFAULT VALUE

    The name of the MySQL database that will store the project data and all results.

* **--dbschema=SCHEMANAME**  (REQUIRED IF --db=slim or --db=full) DEFAULT: --dbschma=Shotmap
  
    The DBIx schema name Shotmap should use. If modifications to the database schema are made and saved under a different DBIx library,
    then change this name. Most users will never need to worry about this option.

* **--bulk** (Optional) DEFAULT: --bulk ENABLED

    When set, data is loaded into the MySQL using a LOAD DATA INFILE statement. This results in massive improvements
    when inserting a massive number of rows into a table. This requires having MySQL configured such that it can 
    read data from /tmp/ (this is a typical setting).

    This option is set by default and most users will never need to worry about it. Note that it is irrevelent if --db=none.

* **--bulk-count=INTEGER** (Optional) DEFAULT: --bulk-count=10000

    Determines how many rows should be simultaneously inserted into the MySQL database when using LOAD DATA INFILE.
    Only used if --bulk is invoked. Most users will never need to worry about this option. Note that it is irrevelent if --db=none.

###LOCAL COMPUTE ARGUMENTS:

* **--nproc=INTEGER** (REQUIRED if not using --remote) NO DEFAULT

   Sets the number of processors that should be used by shotmap when running on a multiprocessor or multicore machine.

   Cannot use both --nproc and --remote.

###REMOTE COMPUTATIONAL CLUSTER ARGUMENTS:

* **--remote** (REQUIRED if using a remote compute cluster) DEFAULT: DISABLED

   Sets whether a remote compute cluster should be used by shotmap for parallelizable analytical tasks (e.g., gene prediction,
   similarity search, classification).

* **--rhost=SOME.CLUSTER.HEAD.NODE.COM** (REQUIRED IF --remote) DEFAULT: DISABLED

    The ip address or hostname of machine that manages the remote computational cluster. 
    Usually this is a cluster head node. 

    Note that this machine must currently run SGE (i.e., qsub).

* **--ruser=USERNAME** (REQUIRED IF --remote)

    Your username for logging into the remote computational cluster / machine.
    Note that you have to set up passphrase-less SSH for this to work.

* **--rdir=/PATH/ON/REMOTE/SERVER** (REQUIRED IF --remote)

    The directory path on the remote cluster where we will store a temporary copy of the shotmap flatfile database

* **--rpath=COLON_DELIMITED_STRING**  (Optional argument) NO DEFAULT

    Example: --rpath=/remote/exe/path/bin:/somewhere/else/bin:/another/place/bin
    The PATH on the remote computational server, where we find various executables like 'rapsearch'.
    COLONS delimit separate path locations, just like in the normal UNIX path variable.

    If this variable is not defined, shotmap will assume that the executables will just be in your $PATH on the remote cluster. Most users
    will not need to worry about this option.

* **--stage** (Optional argument) DEFAULT: DISABLED

    Causes the search database to be copied to the remote cluster. You should not have to do this except when you build a 
    new search database.

* **--wait=SECONDS** (Optional argument) DEFAULT: --wait=30

    How long, in seconds, should we wait before checking the status of activity on the remote cluster? Most users won't need to worry about
    this option.   

* **--scratch** (Optional) DEFAULT: ENABLED

    Forces slave nodes to use local scratch space (i.e., /scratch) when running processes on the compute cluster. When disabled, all distributed shotmap tasks
    will read/write using --rdir, which may create I/O bottlenecks on the cluster. Talk to your system administrator before disabling!
    
###TRANSLATION/GENE CALLING METHODS:

* **--trans-method=STRING** (REQUIRED) DEFAULT: --trans-method=transeq

    Determines the algorithm that should be used to convert metagenomic reads into protein coding space. Currently, only 
    "transeq" is an accepted value, but future work will incorporate metagenomic gene calling tools.

* **--split-orfs** (Optional) DEFAULT: ENABLED

    (disable with --noslit-orfs)
    When set, translated orfs are split into sub-orfs on stop codons. Only works in conjunction with --trans-method=transeq

* **--orf-filter-len=INTEGER** (REQUIRED) DEFAULT=14

    Removes translated reads (orfs) shorter than or equal to this length (in bp) from all subsequent analyses. Set to 0 if you want no filtering.

###SEARCH METHOD ARGUMENTS (One or more MUST be set):

* **--search-method=rapsearch|last|blast|hmmscan|hmmersearch** (REQUIRED) DEFAULT: --search-method=rapsearch

   Determines which algorithm shotmap should use to compare orfs to protein families.

   Shotmap can currently accepts the following options
   rapsearch - RAPsearch v 2.19 or greater
   last      - lastal
   blast     - blastall
   hmmsearch - HMMER v 3
   hmmscan   - HMMER v 2

   Note that different tools may require that different search database indexing procedures are implemented. As a result, you may need to 
   invoke --stage (if --remote) the first time you use an algorithm to compare sequences against your search database.

   Please contact the authors with requests for incorporation of additional algorithms in shotmap.

* **--forcesearch** (Optional) DEFAULT: DISABLED 

    Forces shotmap to research all orfs against all families. This will overwrite previous search results! Note that this 
    automatically forces shotmap to also reparse all search results. When run with --goto=P, forcesearch can be used to 
    explicilty reparse search results.

###SEARCH RESULT PARSING OPTIONS:

* **--parse-score=FLOAT** (Optional) DEFAULT: --parse-score=28

    Sets the minimum bit score that must be reported for an alignment if it is to be retained in the searchresults MySQL table
    
* **--parse-coverage=FLOAT** (Optional) NO DEFAULT

    Sets the minimum coverage (orf length / alignment length)  that must be reported for an alignment if it is to be retained
    in the searchresults MySQL table

* **--parse-evalue=FLOAT** (Optional) NO DEFAULT

    Sets the maximum evalue that must be reported for an alignment if it is to be retained in the searchresults MySQL table

* **--small-transfer** (Optional) DEFAULT: DISABLED

    Only transfer the parsed search results, not the raw search results, from the remote cluster. While this decreases the 
    amount of data that is transferred, increasing throughtput, and stored on your computer, the raw search results will
    ultimately not be retained.

###CLASSIFICATION THRESHOLDS

* **--class-score** (Optional) NO DEFAULT

    Sets the minimum bit score that must be reported for an alignment if it is to be considered for classification into a family

* **--class-coverage** (Optional) NO DEFAULT

    Sets the minimum coverage (orf length / alignment length) that must be reported for an alignment if it is to be considered 
    for classification into a family

* **--class-evalue** (Optional) NO DEFAULT

    Sets the maximum evalue that must be reported for an alignment if it is to be considered 
    for classification into a family

* **--top-hit** (REQUIRED) DEFAULT ENABLED
  
    (disable with --notop-hit)
    When set, an orf or read is classified into the top scoring family that passes all classification thresholds. --top-hit is
    currently required and Shotmap will not run to completion when --notop-hit is set, though future versions may accomodate --notop-hit.

* **--hit-type=read|orf** (REQUIRED) DEFAULT: --hit-type=read
  
    Determines the object that is being subject to classification. Currently only accepts "orf" or "read". When the value is "orf",
    each orf from a read that passes all classification thresholds can be classified into a family. When the value is "read", only the top scoring orf that passes all 
    classification thresholds is classifed into a family. All other orfs are discarded.

###ABUNDANCE CALCULATION ARGUMENTS

* **--abundance-type=binary|coverage** (REQUIRED) DEFAULT: --abundance-type=coverage
  
    Determines the type of abundance metric that shotmap will calculate. Currently accepts values "binary" and "coverage". When
    the value is "binary", each read/orf counts equally to the abundance calculation \(i.e., abundance is equal to the total number
    of reads that are classified into the family\). When the value is "coverage", abundance is weighted by the total number of base pairs that align to the family.

* **--normalization-type=none|family_length|target_length** (required, default="target-length")

    Determines if estimates of abundance should be length corrected, which could be important if family length varies greatly within
    a metagenome. Currently accepts ("none", "family_length", "target_length").
 
    When set to "none", no length normalization takes place. When set to "family_length", family abundance is divided by the average 
    family length (or hmm length is using HMMER). When set to "target_length", each read/orfs contribution to abundance is individually
    normalized by the length of the protein sequence it aligns to. Note that these values also influence relative abundance corrections.

###RAREFACTION ARGUMENTS

* **--prerare-samps=INTEGER** (Optional) NO DEFAULT

  Tells shotmap to rarefy a sample prior to its analysis. In this case, the first INTEGER sequences in a metagenomic sample's fasta file
  will be selected by shotmap and subject to analysis. Can be useful for reducing sequence volume or troubleshooting shotmap.

  Note that --prerare-samps must be invoked during the initial analysis of a sample and that changing this value in a subsequence reanalysis
  (i.e., using --goto) will not alter the data. In addition, you can not rarefy with an INTEGER greater than the number of metagenomic
  sequences in a sample
  
* **--postrare-samps=INTEGER** (Optional) NO DEFAULT

  Tells shotmap to rarefy samples by randomly subsampling data after sequences have been classified into families. Shotmap needs to know
  the type of object to rarefy when implementing this option (see --rarefaction-type). Note that --postrare-samps can be applied to a sample
  that has been subject to --prerare-samps, but that only those sequences that were sampled during --prerare-samps will be subject to rarefaction.

  Note that you cannot rarefy with an INTEGER greater than the number of objects in a sample.

* **--rarefaction-type=read|orf|class_read|class_orf** (REQUIRED IF --postrare-samps) DEFAULT: --rarefaction-type=read

  Tells shotmap to --postrare-samps using one of the following types of objects: read (all reads), orf (all orfs), class_read (all classified reads),
  class_orf (all classified orfs). More specifically, the object identified in the option value is used as the basis for subsampling. So, if 
  --rarefaction-type=class_read, and --postrare-samps=100, shotmap will randomly select 100 classfied reads from each sample in the calculation of abundance
  and quantification of diverstiy.

###REPROCESSING AND TROUBLESHOOTING ARGUMENTS (NOT SET IN CONFIGURATION FILE):

* **--pid=INTEGER** (Optional) NO DEFAULT

    The MySQL/flat file project identifier corresponding to data that you want to reprocess. Not used when analyzing data for the first time!

* **--goto=STRING** (Optional) NO DEFAULT

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

* **--reload** (Optional) DEFAULT: DISABLED)

  Normally, shotmap emits a warning when you attempt to analyze data that you have already processed at some level with shotmap. 
  It prefers that you use the --goto option and amend your settings, but you can completely start over using the --reload option.
  !!!Note that this will remove your prior data from the MySQL database and the shotmap data repository!!!

  This option is never needed when --db=none.

* **--verbose** (Optional) DEFAULT: DISABLED

  Verbose output is produced. Helpful for troubleshooting.


Details
-------
