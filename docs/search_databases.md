Building a ShotMAP Search Database
----------------------------------

ShotMAP classifies sequences into a database of protein families. You must specify the database that ShotMAP should use (i.e., a reference database),
and it must be properly formatted and indexed by ShotMAP before it can be effectively leveraged as a ShotMAP search database.
To construct a search database, which you only need to do one time, use the build_shotmap_search_db.pl as follows:

    perl $SHOTMAP_LOCAL/scripts/build_shotmap_search_db.pl -r <path_to_reference_database> -d <path_to_search_database> 

Here, -r is the input and is a directory that contains a series of files of either one of two types:

* For protein sequence classification: fasta formatted sequences that have either a .fa, .faa, or .pep file extension. Gzipped compressed files (e.g., .fa.gz) are accepted.
* For hmm classification: HMMER3 formatted HMM files that end in a .hmm file extension. Gzipped compressed files are accepted.

Each protein family should have a distinct file. ShotMAP collects the data in this directory to produce an indexed search_database. 

Note that by default, ShotMAP assumes you will use RAPsearch2; if you plan to use a different algorithm
(e.g., HMMER), then you will need to invoke the --search-method option when running build_shotmap_search_db.pl.

For more information, please see the documentation for [build_shotmap_search_db.pl](build_shotmap_search_db.pl).