#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use DBI;
use Data::Dumper;

#Initialize vars

my( $conf_file,            $local_ffdb,            $local_reference_ffdb, $project_dir,         $input_pid,
    $goto,                 $db_username,           $db_pass,              $db_hostname,         $dbname,
    $schema_name,          $db_prefix_basename,    $hmm_db_split_size,    $blast_db_split_size, $family_subset_list,  
    $reps_only,            $nr_db,                 $db_suffix,            $is_remote,           $remote_hostname,
    $remote_user,          $remoteDir,             $remoteExePath,        $use_scratch,         $waittime,
    $multi,                $mult_row_insert_count, $bulk,                 $bulk_insert_count,   $slim,
    $use_hmmscan,          $use_hmmsearch,         $use_blast,            $use_last,            $use_rapsearch,
    $nseqs_per_samp_split, $prerare_count,         $postrare_count,       $trans_method,        $should_split_orfs,
    $filter_length,        $p_evalue,              $p_coverage,           $p_score,             $evalue,
    $coverage,             $score,                 $top_hit,              $top_hit_type,        $stage,
    $hmmdb_build,          $blastdb_build,         $force_db_build,       $force_search,        $small_transfer,
    $verbose,
    $extraBrutalClobberingOfDirectories,
    $dryRun,
    );

$local_ffdb           = undef; #/bueno_not_backed_up/sharpton/MRC_ffdb/"; #where will we store project, result and HMM/blast DB data created by this software?
$local_reference_ffdb = undef; #"/bueno_not_backed_up/sharpton/sifting_families/"; # Location of the reference flatfile data (HMMs, aligns, seqs for each family). The subdirectories for the above should be fci_N, where N is the family construction_id in the Sfams database that points to the families encoded in the dir. Below that are HMMs/ aligns/ seqs/ (seqs for blast), with a file for each family (by famid) within each.

$project_dir          = undef; #where are the project files to be processed?
$family_subset_list   = undef; # path to a file that lists (one per line) which family ids you want to include. Defaults to all. Will probably come back and make this a seperate familyconstruction, e.g. /home/sharpton/projects/MRC/data/subset_perfect_famids.txt

$db_username   = undef;
$db_pass       = undef;
$db_hostname   = undef;

#remote compute (e.g., SGE) vars
$is_remote        = 1; # By default, assume we ARE using a remote compute cluster
$stage            = 0; # By default, do NOT stage the database (this takes a long time)!
$remote_hostname  = undef; #"chef.compbio.ucsf.edu";
$remote_user      = undef; #"yourname";
$remoteDir        = undef;
$remoteExePath    = undef; # like a UNIX $PATH, a colon-delimited set of paths to search for executables. Example: /netapp/home/yourname/bin:/somewhere/else/bin
$waittime         = 30; #in seconds

$hmm_db_split_size    = 500; #how many HMMs per HMMdb split?
$blast_db_split_size  = 50000; #how many family sequence files per blast db split? keep small to keep mem footprint low
$nseqs_per_samp_split = 1000000; #how many seqs should each sample split file contain?
$db_prefix_basename   = undef; # "SFams_all_v0"; #set the basename of your database here.
$reps_only            = 0; #should we only use representative seqs for each family in the blast db? decreases db size, decreases database diversity
$nr_db                = 1; #should we build a non-redundant version of the sequence database?
$db_suffix            = "rsdb"; #prerapsearch index can't point to seq file or will overwrite, so append to seq file name 

$hmmdb_build    = 0;
$blastdb_build  = 0;
$force_db_build = 0;
$force_search   = 0;
$small_transfer = 0;

#optionally set thresholds to use when parsing search results and loading into database. more conservative thresholds decreases DB size
$p_evalue       = undef;
$p_coverage     = undef;
$p_score        = 40;
#optionally set thresholds to use when classifying reads into families.
$evalue         = undef; #a float
$coverage       = undef; #undef or between 0-1
$score          = 20;
$top_hit        = 1;
$top_hit_type   = "read"; # "orf" or "read" Read means each read can have one hit. Orf means each orf can have one hit.

$use_hmmscan    = 0; #should we use hmmscan to compare profiles to reads?
$use_hmmsearch  = 0; #should we use hmmsearch to compare profiles to reads?
$use_blast      = 0; #should we use blast to compare SFam reference sequences to reads?
$use_last       = 0; #should we use last to compare SFam reference sequences to reads?
$use_rapsearch  = 0; #should we use rapsearch to compare SFam reference sequences to reads?

$use_scratch          = 0; #should we use scratch space on remote machine?

$dbname               = undef; #"MRC_MetaHIT";   #might have multiple DBs with same schema.  Which do you want to use here
$schema_name          = undef; #"MRC::Schema"; 

#Translation settings
$trans_method         = "transeq";
$should_split_orfs    = 1; #should we split translated reads on stop codons? Split seqs are inserted into table as orfs
if( $should_split_orfs ){
    $trans_method = $trans_method . "_split";
}
$filter_length        = 14; #filters out orfs of this size or smaller

#Don't turn on both this AND (slim + bulk).
$multi                = 0; #should we multiload our inserts to the database?
$bulk_insert_count    = 1000;
#for REALLY big data sets, we streamline inserts into the DB by using bulk loading scripts. Note that this isn't as "safe" as traditional inserts
$bulk = 1;
#for REALLY, REALLY big data sets, we improve streamlining by only writing familymembers to the database in a standalone familymembers_slim table. 
#No foreign keys on the table, so could have empty version of database except for these results. 
#Note that no metareads or orfs will write to DB w/ this option
$slim = 1;

$prerare_count  = undef; #should we limit our analysis to a subset of the sequences in the input files? Takes the top N number of sequences/sample and constrains analysis to thme
$postrare_count = undef; #when calculating diversity statistics, randomly select this number of raw reads per sample

my %options = ("ffdb"         => \$local_ffdb
	       , "refdb"      => \$local_reference_ffdb
	       , "projdir"    => \$project_dir
	       # Database-server related variables
	       , "dbuser"     => \$db_username
	       , "dbpass"     => \$db_pass
	       , "dbhost"     => \$db_hostname
	       , "dbname"     => \$dbname
	       , "dbschema"   => \$schema_name
	       # FFDB Search database related options
	       , "searchdb=prefix"   => \$db_prefix_basename
	       , "hmmsplit"   => \$hmm_db_split_size
	       , "blastsplit" => \$blast_db_split_size
	       , "sub"        => \$family_subset_list	  
	       , "reps-only"  => \$reps_only
	       , "nr"         => \$nr_db
	       , "db_suffix"  => \$db_suffix
	       # Remote computational cluster server related variables
	       , "remote"     => \$is_remote
	       , "rhost"      => \$remote_hostname
	       , "ruser"      => \$remote_user
	       , "rdir"       => \$remoteDir
	       , "rpath"      => \$remoteExePath
	       , "scratch"    => \$use_scratch
	       , "wait"       => \$waittime        #   <-- in seconds
	       #db communication method (NOTE: use EITHER multi OR bulk OR neither)
	       ,    "multi"        => \$multi
	       ,    "multi_count"  => \$mult_row_insert_count
	       ,    "bulk"         => \$bulk
	       ,    "bulk_count"   => \$bulk_insert_count
	       ,    "slim"         => \$slim
	       #search methods
	       ,    "use_hmmscan"   => \$use_hmmscan
	       ,    "use_hmmsearch" => \$use_hmmsearch
	       ,    "use_blast"     => \$use_blast
	       ,    "use_last"      => \$use_last
	       ,    "use_rapsearch" => \$use_rapsearch
	       #general options
	       ,    "seq-split-size" => \$nseqs_per_samp_split
	       ,    "prerare-samps"  => \$prerare_count
	       ,    "postrare-samps" => \$postrare_count
	       #translation options
	       ,    "trans-method"   => \$trans_method
	       ,    "split-orfs"     => \$should_split_orfs
	       ,    "min-orf-len"    => \$filter_length
	       #search result parsing thresholds (less stringent, optional, defaults to family classification thresholds)
	       ,    "parse-evalue"   => \$p_evalue
	       ,    "parse-coverage" => \$p_coverage
	       ,    "parse-score"    => \$p_score
	       ,    "small-transfer" => \$small_transfer
	       #family classification thresholds (more stringent)
	       ,    "class-evalue"   => \$evalue
	       ,    "class-coverage" => \$coverage
	       ,    "class-score"    => \$score
	       ,    "top-hit"        => \$top_hit
	       ,    "hit-type"       => \$top_hit_type
    );

GetOptions( \%options,
	    , "conf-file=s"  => \$conf_file
	    , "ffdb|d=s"             , "refdb=s"            , "projdir|i=s"      
	    # Database-server related variables
	    , "dbuser|u=s"           , "dbpass|p=s"         , "dbhost=s"          , "dbname=s"        , "dbschema=s"   
	    # FFDB Search database related options
	    , "searchdb-prefix=s"           , "hmmsplit=i"         , "blastsplit=i"      , "sub=s"           , "reps-only!"      , "nr!"             , "db_suffix:s"  
	    # Remote computational cluster server related variables
	    , "remote!"              , "rhost=s"            , "ruser=s"           , "rdir=s"          , "rpath=s"         , "scratch!"        , "wait|w=i"    
	    #db communication method (NOTE: use EITHER multi OR bulk OR neither)
	    ,    "multi!"            ,    "multi_count:i"   ,    "bulk!"          ,    "bulk_count:i" ,    "slim!"         
	    #search methods
	    ,    "use_hmmscan"       ,    "use_hmmsearch"   ,    "use_blast"      ,    "use_last"     ,    "use_rapsearch" 
	    #general options
	    ,    "seq-split-size=i"  ,    "prerare-samps:i" ,    "postrare-samps:i" 
	    #translation options
	    ,    "trans-method:s"    ,    "split-orfs!"     ,    "min-orf-len:i"    
	    #search result parsing thresholds (less stringent, optional, defaults to family classification thresholds)
	    ,    "parse-evalue:f"    ,    "parse-coverage:f",    "parse-score:f"   , "small-transfer!" 
	    #family classification thresholds (more stringent)
	    ,    "class-evalue:f"    ,    "class-coverage:f",    "class-score:f"   ,    "top-hit!"     ,    "hit-type:s"       
    );

my $switches = { #optionless args are printed out differently
    "reps-only" => 0,
    "nr"        => 0,
    "remote"    => 0,
    "scratch"   => 0,
    "multi"     => 0,
    "bulk"      => 0,
    "slim"      => 0,
    "use_hmmscan"   => 0,
    "use_hmmsearch" => 0,
    "use_blast"     => 0,
    "use_last"      => 0,
    "use_rapsearch" => 0,
    "split-orfs"    => 0,
    "top-hit"       => 0,
};

if( !defined( $db_pass ) ){
    print "Enter the MySQL password for user <${db_username}> at database host <${db_hostname}>:\n";
    `stty -echo`;
    $db_pass = <>;
    `stty echo`;
    print "Testing MySQL connection....\n";
    chomp( $db_pass );
}

my $dbh = DBI->connect( "dbi:mysql:$dbname:$db_hostname", $db_username, $db_pass )
    or die "Connection Error: $DBI::errstr\n";

print "Looks like we can connect with these database settings. Building conf-file...\n";
open( OUT, ">$conf_file" ) || die "Can't open $conf_file for write: $!\n";
foreach my $key( keys( %options ) ){
    if( defined( $switches->{$key} ) ){
	if( ${ $options{$key} } == 0  || !defined( $options{$key} ) ){
	    print OUT "--no${key}\n";
	} else {
	    print OUT "--${key}\n";
	}
    } else {
	next unless( defined( ${ $options{$key} } ) );
	my $value = ${ $options{$key} };
	print OUT "--${key}=${value}\n";
    }    
}
close OUT;

`chmod 0600 $conf_file`;
print "Confile created here with permissions 0600: $conf_file\n";
