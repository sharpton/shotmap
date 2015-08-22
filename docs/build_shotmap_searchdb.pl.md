build_shotmap_searchdb.pl
=========================

Usage:
------

    perl build_shotmap_searchdb.pl -r </path/to/reference/family/database/dir/> -d </output/search_database/dir/> [options]

Description:
------------

This script constructs a shotmap formatted search database, as defined [here](search_databases.md).

Examples:
---------

To build a RAPsearch formatted database, use the defaults

   perl build_shotmap_searchdb.pl -r  </path/to/reference/family/database/dir/> -d </output/search_database/dir/> 

To build a database of HMMER v3 formatted HMMs, use the following:

   perl build_shotmap_searchdb.pl -r  </path/to/reference/family/database/dir/> -d </output/search_database/dir/> --search-method=hmmsearch


OPTIONS:
--------

* **-r, --refdb=/PATH/TO/REFERENCE/FLATFILES**  (REQUIRED argument) NO DEFAULT VALUE

    Location of the protein family reference data.  Each family must have a HMM (if running HMMER tools) 
    or a set of protein sequences sequences, in fasta format, that are members of the family (if running blast-like tools).

    Files in this directory should correspond to an individual family, with the prefix of the file being 
    the family identifier (e.g., IPR020405) and the suffix should either be .hmm (for HMMs) or .fa
    (for protein sequences). These files can be placed in any subdirectory stucture within this upper 
    level directory; shotmap will recurse through all subdirectories and append all appropriate .hmm or .fa files to the list
    of families that will be incorporated into the search database.

* **-d, --searchdb-dir=/PATH/TO/SEARCHDB/DIRECTORY** (REQUIRED argument) DEFAULT: NONE

  This is the location of the shotmap formatted search database that will be used to assign metagenomic sequences to families. This
  database is produced by running build_shotmap_searchdb.pl. Point this parameter to the directory containing the database files.

* **--search-method=rapsearch|rapsearch_acceleratedlast|blast|hmmscan|hmmersearch** (REQUIRED) DEFAULT: --search-method=rapsearch

   ShotMAP formats databases to interface with specific search algorithms. For example, if you want to use blast to identify homologs, build_shotmap_searchdb.pl
   needs to know this so that the database is constructs is apporpriate for the blast algorithms.

   Shotmap can currently accepts the following options
   rapsearch - RAPsearch v 2.19 or greater
   last      - lastal
   blast     - blastall
   hmmsearch - HMMER v 3
   hmmscan   - HMMER v 3

* **--searchdb-name=STRING** (Optional argument) DEFAULT: reference database directory name

    The name of the search database(s) (sequence and HMM) that shotmap will build. 
    The use of additional arguments (see below) may result in additional strings being concattenated to this prefix. For example,
    if --searchdb-name=KEGG and --nr is invoked, the search database name will be KEGG_nr

* **--searchdb-split-size=INTEGER** (OPTIONAL argument, ONLY FOR REMOTE SEARCHES) NO DEFAULT VALUE

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
