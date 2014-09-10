#!/usr/bin/perl -w

#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gladstone.ucsf.edu
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program (see LICENSE.txt).  If not, see <http://www.gnu.org/licenses/>.

package Shotmap::Notify;

use lib ($ENV{'SHOTMAP_LOCAL'} . "/ext/lib/perl5");     

use strict;
use warnings;
use Shotmap;
use IPC::System::Simple qw(capture run $EXITVAL);

my $USE_COLORS_CONSTANT = 1; ## Set this to '0' to avoid printing colored output to the terminal, or '1' to print colored output.

sub tryToLoadModule($) {
    # Tries to load a module. Returns a true value (1) if it succeeds. Otherwise, returns a false value (0).
    my $x = eval("require $_[0]");
    if ((defined($@) && $@)) {
	warn "Module loading of $_[0] FAILED. Skipping this module.";
	return 0;
    } else {
	$_[0]->import();
	return 1;
    }
}

if (!tryToLoadModule("Term::ANSIColor")) {
    $USE_COLORS_CONSTANT = 0; # Failed to load the ANSI color terminal, so don't use colors! Not sure how reliable this actually is.
}

sub safeColor($;$) { # one required and one optional argument
    ## Prints colored text, but only if USER_COLORS_CONSTANT is set.
    ## Allows you to totally disable colored printing by just changing USE_COLORS_CONSTANT to 0 at the top of this file
    my ($self, $str, $color) = @_;
    return (($USE_COLORS_CONSTANT) ? Term::ANSIColor::colored($str, $color) : $str);
}

sub dryNotify { # one optional argument
    my ($self, $msg) = @_;
    $msg = (defined($msg)) ? $msg : "This was only a dry run, so we skipped executing a command.";
    chomp($msg);
    print STDERR $self->Shotmap::Notify::safeColor("[DRY RUN]: $msg\n", "black on_magenta");
}

sub notifyAboutScp {
    my ($self, $msg) = @_;
    chomp($msg);
    my $parentFunction = defined((caller(2))[3]) ? (caller(2))[3] : '';
    print STDERR ($self->Shotmap::Notify::safeColor("[SCP]: $parentFunction: $msg\n", "green on_black")); ## different colors from normal notification message
    # no point in printing the line number for an SCP command, as they all are executed from Run.pm anyway
}

sub notifyAboutRemoteCmd{
    my ($self, $msg) = @_;
    chomp($msg);
    my $parentFunction = defined((caller(2))[3]) ? (caller(2))[3] : '';
    print STDERR ($self->Shotmap::Notify::safeColor("[REMOTE CMD]: $parentFunction: $msg\n", "black on_green")); 
    ## different colors from normal notification message
    # no point in printing the line number for a remote command, as they all are executed from Run.pm anyway
}

sub notify {
    my ($self, $msg) = @_;
    chomp($msg);
    print STDERR ($self->Shotmap::Notify::safeColor("[NOTE]: $msg\n", "cyan on_black"));
}

sub notify_verbose {
    my ($self, $msg) = @_;
    if( $self->verbose ){
	chomp($msg);
	print STDERR ($self->Shotmap::Notify::safeColor("[NOTE]: $msg\n", "cyan on_black"));
    }
}

sub dieWithUsageError {
    my ($self, $msg) = @_;
    chomp($msg);
    print("[TERMINATED DUE TO USAGE ERROR]: " . $msg . "\n");
    print STDOUT <DATA>;
    die($self->Shotmap::Notify::safeColor("[TERMINATED DUE TO USAGE ERROR]: " . $msg . " ", "yellow on_red"));
}

sub exec_and_die_on_nonzero {
    my ( $cmd ) = @_;
    #my $results = IPC::System::Simple::capture($cmd);
    my $results = IPC::System::Simple::run($cmd);
    (0 == $EXITVAL) or die "Error:  non-zero exit value: $results";
    return($results);
}

sub pipeline_params{
    my ( $self ) = @_;

    $self->Shotmap::Notify::notify("Starting a classification run using the following settings:\n");
    ($self->remote)                      && $self->Shotmap::Notify::notify("   * Use the remote server <" . $self->remote_host . ">\n");
    if( defined( $self->db_host ) ){        $self->Shotmap::Notify::notify("   * Database host: <"        . $self->db_host     . ">\n") };
    if( defined( $self->db_name  ) ){       $self->Shotmap::Notify::notify("   * Database name: <"        . $self->db_name     . ">\n") };
    ($self->use_search_alg("last"))      && $self->Shotmap::Notify::notify("   * Algorithm: last\n");
    ($self->use_search_alg("blast"))     && $self->Shotmap::Notify::notify("   * Algorithm: blast\n");
    ($self->use_search_alg("hmmscan"))   && $self->Shotmap::Notify::notify("   * Algorithm: hmmscan\n");
    ($self->use_search_alg("hmmsearch")) && $self->Shotmap::Notify::notify("   * Algorithm: hmmsearch\n");
    ($self->use_search_alg("rapsearch")) && $self->Shotmap::Notify::notify("   * Algorithm: rapsearch\n");
    ($self->stage)                       && $self->Shotmap::Notify::notify("   * Staging: Will copy the search databaase to " . $self->remote_host    . "\n");
    if( defined( $self->class_evalue )   ){ $self->Shotmap::Notify::notify("   * Evalue threshold: "          . $self->class_evalue   . "\n") };
    if( defined( $self->class_coverage ) ){ $self->Shotmap::Notify::notify("   * Coverage threshold: "        . $self->class_coverage . "\n") };
    if( defined( $self->class_score )    ){ $self->Shotmap::Notify::notify("   * Score threshold: "           . $self->class_score    . "\n") };

    return $self;
}

sub printBanner($$) {
    my ($self, $string) = @_;
    my $dateStr = `date`;
    chomp($string); # remove any ending-of-string newline that might be there
    chomp($dateStr); # remote always-there newline from the `date` command
    my $stringWithDate = $string . " ($dateStr)";
    my $pad  = "#" x (length($stringWithDate) + 4); # add four to account for extra # and whitespce on either side of string
    print STDERR $self->Shotmap::Notify::safeColor("$pad\n" . "# " . $stringWithDate . " #\n" . "$pad\n", "green on_black");
}

sub check_env_var{
    my ( $self, $env ) = @_;
    if (!defined( $env )) {
	print STDOUT ("[ERROR]: The SHOTMAP_LOCAL environment variable was NOT EXPORTED and is UNDEFINED.\n");
	print STDOUT ("[ERROR]: SHOTMAP_LOCAL needs to be defined as the local code directory where the shotmap files are located.\n");
	print STDOUT ("[ERROR]: This is where you'll do the github checkout, if you haven't already.\n");
	print STDOUT ("[ERROR]: I recommend setting it to a location in your home directory. Example: export SHOTMAP_LOCAL='/some/location/shotmap'\n");
	die "Environment variable SHOTMAP_LOCAL must be EXPORTED. Example: export SHOTMAP_LOCAL='/path/to/your/directory/for/shotmap'\n";
    }
}

sub warn_ssh_keys{
    my ( $self ) = @_;
    print STDERR "Please remember that you will need passphrase-less SSH set up already.\nNote that if you see a prompt for a password in your connection to <" . $self->remote_host . "> below, that would mean that you did not have passphrase-less SSH set up properly. Instructions for setting it up can be found by searching google for the term \"passphraseless ssh\".\n";
    my $likely_location_of_ssh_public_key = $ENV{'HOME'} . "/.ssh/id_rsa.pub";
    if (!(-s $likely_location_of_ssh_public_key)) {
	print "WARNING: I notice that you do not have an SSH public key (expected to be found in <$likely_location_of_ssh_public_key>), which means you most likely do not have passphrase-less ssh set up with the remote machine (<" . $self->remote_host . ">).\n";
    }
    return $self;
}

sub warn{
    my( $self, $string ) = @_;
    if( $string !~ m/\n$/ ){
	$string = $string . "\n";
    }
    unless( $self->is_test ){
	print STDERR ($self->Shotmap::Notify::safeColor("[WARNING]: $string", "magenta on_black"));
    }
    return $self;
}

sub print_verbose{
    my ( $self, $string ) = @_;
    if( $string !~ m/\n$/ ){
	$string = $string . "\n";
    }
    if( $self->verbose ){
	print STDERR $string;
    }
    return $self;
}

sub print{
    my ( $self, $string ) = @_;
    if( $string !~ m/\n$/ ){
	$string = $string . "\n";
    }
    print STDERR $string;
    return $self;
}

1;

__DATA__

shotmap.pl  [OPTIONS]

Version 0.1 Last updated September 2013.

Shotmap (Shotgun Metagenome Annotation Pipeline) program by Thomas Sharpton.

See the examples below for more information.

EXAMPLES:

1. You have to set your SHOTMAP_LOCAL environment variable.
export SHOTMAP_LOCAL=/my/home/directory/shotmapt       <-- this is your github-checked-out copy of shotmap

2. Now you need build a configuration file using build_conf_file.pl as follows:
   
    perl $SHOTMAP_LOCAL/scripts/build_conf_file.pl --conf-file=<path_to_configuration_file> [options]

NOTE: You may store your MySQL password in this file, which will be locked down with user-only read permissions.

3. You have to set up passphrase-less SSH to your computational cluster. In this example, the cluster should have a name like "compute.cluster.university.edu".
Follow the links at "https://www.google.com/search?q=passphraseless+ssh" in order to find some solutions for setting this up. It is quite easy!

4. Then you can run shotmap.pl as follows. 

 perl $SHOTMAP_LOCAL/scripts/shotmap.pl --conf-file=<path_to_configuration_file>

Note that the FIRST TIME you run it, you need to build either a HMM (--hdb) or blast (--bdb) search database, and you have to STAGE (i.e. transfer) the files to the remote cluster with the --stage option.
So your first run will look something like this:
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

OPTIONS:

CONFIGURATION FILE:

--conf-file=/PATH/TO/CONFIGURATION_FILE (optional, but RECOMMENDED, no default)
    Location of the configuration file that shotmap should use. This file can be built using "${SHOTMAP_LOCAL}/scripts/build_conf_file.pl" and contains
    a list of shotmap run-time arguments, as below, one per row. Configuration file options can be overridden when calling shotmap with run-time arguments. 
    You may also copy and edit a configuration file, to streamline additional anlayses that vary in only a small number of settings.

    When building a configuation file, you will be asked to enter your MySQL password. You are not required to put your password in this file, though it is
    recommended as passing that argument to shotmap.pl at run time will place your password in your history. The configuation file is secured with user-only,
    read-only permissions. Note that this is NOT a failsafe security method!

METAGENOME DATA ARGUMENTS:

--projdir=/PATH/TO/PROJECT/DIR (or -i /PATH/TO/PROJECT/DIR)     (REQUIRED argument)
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

SHOTMAP DATA REPOSITORY ARGUMENTS:

--ffdb=/PATH/TO/FLATFILES  (or -d /PATH/TO/FLATFILES)     (REQUIRED argument)
    local flat file database path

DATABASE ARGUMENTS:

--dbhost=YOUR.DATABASE.SERVER.COM           (REQUIRED argument)
    The ip address or hostname of machine that hosts the remote MySQL database. 

    Note that you must have select, insert, and delete permissions in MySQL. Also, you must be able 
    to READ DATA INFILE from /tmp/ (typical default setting in MySQL).

--dbuser=MYSQL_USERNAME                     (REQUIRED argument)
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

REFERENCE SEARCH DATABASE ARGUMENTS:

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

--nr (Optional, set off by default)
    When building a protein sequence (blast-like) search database, collapses identical sequences found within
    the same family (i.e., build a non-redundant database).

--db_suffix=STRING (required if using --build-refdb and --search-method=rapsearch, default "rsdb")
    When building a protein sequence (blast-like) database, appends this string to the end of binary formatted
    database files.

    Currently only used by RAPsearch.

--force-refdb
    Force database to be built. Overwrites a previously built search database with the same name and settings!

REMOTE COMPUTATIONAL CLUSTER ARGUMENTS:

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

TRANSLATION/GENE CALLING METHODS:

--trans-method=STRING (required, default: "transeq")
    Determines the algorithm that should be used to convert metagenomic reads into protein coding space. Currently, only 
    "transeq" is an accepted value, but future work will incorporate metagenomic gene calling tools.
--split-orfs (optional, default=ENABLED)
    (disable with --noslit-orfs)
    When set, translated orfs are split into sub-orfs on stop codons.

--min-orf-len=INTEGER (required, default=0)
    Removes translated reads (orfs) shorter than this length (in bp) from all subsequent analyses. Set to 0 if you want no filtering

SEARCH METHOD ARGUMENTS (One or more MUST be set):

--use_hmmsearch (optional, default=DISABLED) *OBSOLETE (see --search-method)*

    Tells shotmap to compare metagenomic reads into families using hmmsearch (HMMER)
    
--use_hmmscan (optional, default=DISABLED) *OBSOLETE (see --search-method)*
    Tells shotmap to compare metagenomic reads into families using hmmscan (HMMER)

--use_blast (optional, default=DISABLED) *OBSOLETE (see --search-method)*
    Tells shotmap to compare metagenomic reads into families using blast.  Also tells Shotmap to configure the search database
    for blast using formatdb

--use_last (optional, default=DISABLED) *OBSOLETE (see --search-method)*
    Tells shotmap to compare metagenomic reads into families using last.  Also tells Shotmap to configure the search database
    for last using lastdb

--use_rapsearch (optional, default=DISABLED) *OBSOLETE (see --search-method)*
    Tells shotmap to compare metagenomic reads into families using RAPsearch. Also tells Shotmap to configure the search database
    for rapsearch using prerapsearch

--search-method (required)
    Tells shotmap to use a particular search algorithm. Pick from hmmsearch, hmmscan, blast, last, rapsearch.

--forcesearch (optional, default=DISABLED)
    Forces shotmap to research all orfs against all families. This will overwrite previous search results! Note that this 
    automatically forces shotmap to also reparse all search results. When run with --goto=P, forcesearch can be used to 
    explicilty reparse search results.

SEARCH RESULT PARSING OPTIONS:

--parse-score=FLOAT (optional, no default)
    Sets the minimum bit score that must be reported for an alignment if it is to be retained in the searchresults MySQL table
    
--parse-coverage=FLOAT (optional, no default)
    Sets the minimum coverage (orf length / alignment length)  that must be reported for an alignment if it is to be retained
    in the searchresults MySQL table

--parse-evalue=FLOAT (optional, no default)
    Sets the maximum evalue that must be reported for an alignment if it is to be retained in the searchresults MySQL table

--small-transfer (optional, default=DISABLED)
    Only transfer the parsed search results, not the raw search results, from the remote cluster

CLASSIFICATION THRESHOLDS

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

ABUNDANCE CALCULATION ARGUMENTS

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

GENERAL ARGUMENTS, NOT SET IN CONFIGURATION FILE:

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



Please report bugs to the author.
--------------

