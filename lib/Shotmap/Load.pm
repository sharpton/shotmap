#!/usr/bin/perl -w

#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gladstone.ucsf.edu
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program (see LICENSE.txt).  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

package Shotmap::Load;

use Shotmap;
use Getopt::Long qw(GetOptionsFromString GetOptionsFromArray);
use File::Basename;
use Data::Dumper;

sub check_vars{
    my $self = shift;
    (defined($self->opts->{"rdir"})) or $self->Shotmap::Notify::dieWithUsageError("--rdir (remote computational server scratch/flatfile location. Example: --rdir=/cluster/share/yourname/shotmap). This is mandatory!");
    (defined($self->opts->{"remoteExePath"})) or warn("Note that --rpath was not defined. This is the remote computational server's \$PATH, where we find various executables like 'lastal'). Example: --rpath=/cluster/home/yourname/bin:/somewhere/else/bin:/another/place/bin). COLONS delimit separate path locations, just like in the normal UNIX path variable. This is not mandatory, but is a good idea to include.");
    
    (!$self->opts->{"dryrun"}) or $self->Shotmap::Notify::dieWithUsageError("Sorry, --dryrun is actually not supported, as it's a huge mess right now! My apologies.");
    (defined($self->opts->{"ffdb"})) or $self->Shotmap::Notify::dieWithUsageError("--ffdb (local flat-file database directory path) must be specified! Example: --ffdb=/some/local/path/shotmap_repo (or use the shorter '-d' option to specify it. This used to be hard-coded as being in /bueno_not_backed_up/yourname/shotmap_repo");
    (-d $self->opts->{"ffdb"} ) or $self->Shotmap::Notify::dieWithUsageError("--ffdb (local flat-file database directory path) was specified as --ffdb='" . $self->opts->{"ffdb"} . "', but that directory appeared not to exist! Note that Perl does NOT UNDERSTAND the tilde (~) expansion for home directories, so please specify the full path in that case. You must specify a directory that already exists.");
    
    (defined($self->opts->{"refdb"})) or $self->Shotmap::Notify::dieWithUsageError("--refdb (local REFERENCE flat-file database directory path) must be specified! Example: --refdb=/some/local/path/protein_family_database");
    (-d $self->opts->{"refdb"})      or $self->Shotmap::Notify::dieWithUsageError("--refdb (local REFERENCE flat-file database directory path) was specified as --refdb='" . $self->opts->{"refdb"} . "', but that directory appeared not to exist! Note that Perl does NOT UNDERSTAND the tilde (~) expansion for home directories, so please specify the full path in that case. Specify a directory that exists.");
    (defined($self->opts->{"dbhost"}))          or $self->Shotmap::Notify::dieWithUsageError("--dbhost (remote database hostname: example --dbhost='data.youruniversity.edu') MUST be specified!");
    (defined($self->opts->{"dbuser"}))          or $self->Shotmap::Notify::dieWithUsageError("--dbuser (remote database mysql username: example --dbuser='dataperson') MUST be specified!");
    (defined($self->opts->{"dbpass"}) || defined($self->opts->{"conf-file"})) or $self->Shotmap::Notify::dieWithUsageError("--dbpass (mysql password for user --dbpass='" . $self->opts->{"dbuser"} . "') or --conf-file (file containing password) MUST be specified here in super-insecure plaintext,\nunless your database does not require a password, which is unusual. If it really is the case that you require NO password, you should specify --dbpass='' OR include a password in --conf-file ....");
    if( defined( $self->opts->{"conf-file"} ) ){
	( -e $self->opts->{"conf-file"} ) or $self->Shotmap::Notify::dieWithUsageError("You have specified a password file by using the --conf-file option, but I cannot find that file. You entered <" . $self->opts->{"conf-file"} . ">");
     }
     if( $self->opts->{"remote"} ){
	 (defined($self->opts->{"rhost"}))      or $self->Shotmap::Notify::dieWithUsageError("--rhost (remote computational cluster primary note) must be specified since you set --remote. Example --rhost='main.cluster.youruniversity.edu')!");
	 (defined($self->opts->{"ruser"}))          or $self->Shotmap::Notify::dieWithUsageError("--ruser (remote computational cluster username) must be specified since you set --remote. Example username: --ruser='someguy'!");
     }	 
     ($self->opts->{"use_hmmsearch"} || $self->opts->{"use_hmmscan"} || 
      $self->opts->{"use_blast"}     || $self->opts->{"use_last"}    || 
      $self->opts->{"use_rapsearch"} ) or 
      $self->Shotmap::Notify::dieWithUsageError( "You must specify a search algorithm. Example --use_rapsearch!");
     
     if( $self->opts->{"use_rapsearch"} && !defined( $self->opts->{"db_suffix"} ) ){  
	 $self->Shotmap::Notify::dieWithUsageError( "You must specify a database name suffix for indexing when running rapsearch!" ); 
     }
     
     #($coverage >= 0.0 && $coverage <= 1.0) or $self->Shotmap::Notify::dieWithUsageError("Coverage must be between 0.0 and 1.0 (inclusive). You specified: $coverage.");
     
     if ((defined($self->opts->{"goto"}) && $self->opts->{"goto"}) && !defined($self->opts->{"pid"})) { 
	$self->Shotmap::Notify::dieWithUsageError("If you specify --goto=SOMETHING, you must ALSO specify the --pid to goto!"); }
     
     if( $self->opts->{"bulk"} && $self->opts->{"multi"} ){
	 $self->Shotmap::Notify::dieWithUsageError( "You are invoking BOTH --bulk and --multi, but can you only proceed with one or the other! I recommend --bulk.");
     }
     
     if( $self->opts->{"slim"} && !$self->opts->{"bulk"} ){
	$self->Shotmap::Notify::dieWithUsageError( "You are invoking --slim without turning on --bulk, so I have to exit!");
     }
     
     #try to detect if we need to stage the database or not on the remote server based on runtime options
     if ($self->opts->{"remote"} and ($self->opts->{"hdb"} or $self->opts->{"bdb"} and !$self->opts->{"stage"}) ){	
	 #This error is problematic in the case that we reclassify old search results, need to create a better check that
	 #considers goto variable.
	 $self->Shotmap::Notify::dieWithUsageError("If you specify hmm_build or blastdb_build AND you are using a remote server, you MUST specify the --stage option to copy/re-stage the database on the remote machine!");
     }
     
     if( $self->opts->{"forcedb"} && ( !$self->opts->{"hdb"} && !$self->opts->{"bdb"} ) ){
	 $self->Shotmap::Notify::dieWithUsageError("I don't know what kind of database to build. If you specify --forcedb, you must also specific --hbd and/or --bdb");
     }
     
    if( $self->opts->{"forcedb"} && $self->opts->{"remote"} && !$self->opts->{"stage"} ){
	$self->Shotmap::Notify::dieWithUsageError("You are using --forcedb but not telling me that you want to restage the database on the remote server <" . $self->opts->{"rhost"} . ">. Disambiguate by using --stage");
     }
    
    unless( defined( $self->opts->{"pid"} ) ){ (-d $self->opts->{"projdir"}) or $self->Shotmap::Notify::dieWithUsageError("You must provide a properly structured project directory! Sadly, the specified directory <" . $self->opts->{"projdir"} . "> did not appear to exist, so we cannot continue!\n") };
    
    if (!defined($self->opts->{"dbname"})) {
	$self->Shotmap::Notify::dieWithUsageError("Note: --dbname=NAME was not specified on the command line, so I don't know which mysql database to talk to. Exiting\n");
    }    
    if (!defined($self->opts->{"dbschema"})) {
	my $schema_name = "ShotDB::Schema";
	warn("Note: --dbschema=SCHEMA was not specified on the command line, so we are using the default schema name, which is \"$schema_name\".");
    }
    (defined($self->opts->{"searchdb-prefix"})) or $self->Shotmap::Notify::dieWithUsageError( "Note: db_prefix_basename (search database basename/prefix) was not specified on the command line (--searchdb-prefix=PREFIX)." );

    (defined($self->opts->{"blastsplit"})) or  $self->Shotmap::Notify::dieWithUsageError( "Note: blast_db_split_size (total number of sequence database files) was not specified on the command line (--blastsplit=INTEGER)");
    (defined($self->opts->{"hmmsplit"})) or  $self->Shotmap::Notify::dieWithUsageError( "Note: hmm_db_split_size (total number of hmm database files) was not specified on the command line (--hmmsplit=INTEGER)");

    (defined($self->opts->{"normalization-type"})) or  $self->Shotmap::Notify::dieWithUsageError( "You must provide a proper abundance normalization type on the command line (--normalization-type)");
    (defined($self->opts->{"abundance-type"}))     or  $self->Shotmap::Notify::dieWithUsageError( "You must provide a proper abundance type on the command line (--abundance-type)");
    return $self;
}

sub dereference_options{
    my $options = shift; #hashref
    foreach my $key( keys( %$options )){
	my $value = $options->{$key};
	if( defined( $value ) ){
	    $options->{$key} = ${ $value };
	}
    }
    return $options;
}

sub get_conf_file_options($$){
    my ( $conf_file, $options ) = @_;
    my $opt_str = '';
    print "Parsing configuration file <${conf_file}>. Note that command line options trump conf-file settings\n";
    open( CONF, $conf_file ) || die "can't open $conf_file for read: $!\n";
    while(<CONF>){
	chomp $_;
	if( $_ =~ m/^\-\-(.*)\=(.*)$/ ){
	    my $key = $1;
	    my $val = $2;
	    next if defined( ${ $options->{$key} } ); #command line opts trump 
	    $opt_str .= " --${key}=${val} ";
	} elsif( $_ =~ m/^\-\-(.*)$/ ){
	    my $key = $1;
	    next if defined( ${ $options->{$key} } ); #command line opts trump 
	    $opt_str .= " --$key ";
	}
    }
    close CONF;
    return $opt_str;
}

sub get_options{
    my $self = shift;
    my @args = @_;

    my( $conf_file,            $local_ffdb,           $local_reference_ffdb, $project_dir,         $input_pid,
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
	$normalization_type,   $abundance_type,
	#non conf-file vars
	$verbose,
	$extraBrutalClobberingOfDirectories,
	$dryRun,
	$reload,
	);

    my %options = (	
	"ffdb"         => \$local_ffdb
	, "refdb"      => \$local_reference_ffdb
	, "projdir"    => \$project_dir
	# Database-server related variables
	, "dbuser"     => \$db_username
	, "dbpass"     => \$db_pass
	, "dbhost"     => \$db_hostname
	, "dbname"     => \$dbname
	, "dbschema"   => \$schema_name
	# FFDB Search database related options
	, "searchdb-prefix"   => \$db_prefix_basename
	, "hmmsplit"   => \$hmm_db_split_size
	, "blastsplit" => \$blast_db_split_size
	, "family-subset" => \$family_subset_list	  ####RECENTLY CHANGED THIS KEY CHECK ELSEWHERE
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
	#abundance claculation parameters
	,    "abundance-type" => \$abundance_type
	,    "normalization-type" => \$normalization_type
	#usually set at run time
	, "conf-file"         => \$conf_file
	, "pid"               => \$input_pid          
	, "goto"              => \$goto     
	#forcing statements
	,    "stage"       => \$stage # should we "stage" the database onto the remote machine?
	,    "hdb"         => \$hmmdb_build
	,    "bdb"         => \$blastdb_build
	,    "forcedb"     => \$force_db_build
	,    "forcesearch" => \$force_search
	,    "verbose"     => \$verbose
	,    "clobber"     => \$extraBrutalClobberingOfDirectories
	,    "dryrun"      => \$dryRun
	,    "reload"      => \$reload
	);
    my @opt_type_array = ("ffdb|d=s"
			  , "refdb=s" 
			  , "projdir|i=s"      
			      # Database-server related variables
			  , "dbuser|u=s"           
			  , "dbpass|p=s"         
			  , "dbhost=s"          
			  , "dbname=s" 
			  , "dbschema=s"   
			      # FFDB Search database related options
			  , "searchdb-prefix=s"
			  , "hmmsplit=i" 
			  , "blastsplit=i" 
			  , "family-subset=s" 
			  , "reps-only!"
			  , "nr!"
			  , "db_suffix:s"  
			  # Remote computational cluster server related variables
			  , "remote!"
			  , "rhost=s"
			  , "ruser=s" 
			  , "rdir=s"
			  , "rpath=s"
			  , "scratch!"
			  , "wait|w=i"    
			  #db communication method (NOTE: use EITHER multi OR bulk OR neither)
			  , "multi!"         ### OBSOLETE?
			  , "multi_count:i"  ### OBSOLETE?
			  , "bulk!"
			  , "bulk_count:i"
			  , "slim!"         
			  #search methods
			  , "use_hmmscan!" 
			  , "use_hmmsearch!"
			  , "use_blast!" 
			  , "use_last!"
			  , "use_rapsearch!"
			  #general options
			  , "seq-split-size=i" 
			  , "prerare-samps:i"
			  , "postrare-samps:i" 
			  #translation options
			  , "trans-method:s" 
			  , "split-orfs!"    
			  , "min-orf-len:i"    
			  #search result parsing thresholds (less stringent, optional, defaults to family classification thresholds)
			  , "parse-evalue:f" 
			  , "parse-coverage:f"
			  , "parse-score:f"   
			  , "small-transfer!"  ### ???
			  #family classification thresholds (more stringent)
			  , "class-evalue:f"
			  , "class-coverage:f"
			  , "class-score:f"
			  ,    "top-hit!"      ### NEED TO INTEGRATE METHODS
			  ,    "hit-type:s"    ### NEED TO INTEGRATE METHODS  
			  #abundance calculation parameters
			  , "abundance-type:s"
			  , "normalization-type:s"			  
			  #general settings
			  , "conf-file|c=s" 
			  , "pid=i"
			  , "goto|g=s"			  
			  #forcing statements
			  , "stage!"
			  , "hdb!"  
			  , "bdb!"  
			  , "forcedb!"
			  , "forcesearch!"
			  , "verbose|v!"
			  , "clobber"   
			  , "dryrun|dry!"
			  , "reload!"   		
	);
    #grab command line options
    GetOptionsFromArray( \@args, \%options, @opt_type_array );
    if( defined( $conf_file ) ){
	if( ! -e $conf_file ){ $self->Shotmap::Notify::dieWithUsageError( "The path you supplied for --conf-file doesn't exist! You used <$conf_file>\n" ); }
	my $opt_str = get_conf_file_options( $conf_file, \%options );
	GetOptionsFromString( $opt_str, \%options, @opt_type_array );

    }
    #getopts keeps the values referenced, so we have to dereference them if we want to directly call. Note: if we ever add hash/array vals, we'll have to reconsider this function
    %options = %{ dereference_options( \%options ) };
    $self->opts( \%options );    
}

sub get_password_from_file{
    my ( $self, $passfile ) = @_;
    open( FILE, $passfile ) || die "Can't open $passfile for read:$!\n";
    my $pass;
    while(<FILE>){
	chomp $_;
	if( $_ =~ m/^dbpass\=(.*)$/ ){
	    $pass = $1;
	}
    }
    close FILE;
    return $pass;
}

sub set_params{
    my ( $self ) = @_;

    # Some run time parameters
    $self->dryrun( $self->opts->{"dryrun"} );
    $self->project_id( $self->opts->{"pid"} );
    $self->project_dir( $self->opts->{"projdir"} );
    $self->wait( $self->opts->{"wait"} );
    $self->scratch( $self->opts->{"scratch"} );

    # Set read parameters
    $self->read_split_size( $self->opts->{"seq-split-size"} );

    # Set orf calling parameters
    my $trans_method = $self->opts->{"trans-method"};
    if( $self->opts->{"split-orfs"} ){
	$trans_method = $trans_method . "_split";
	$self->split_orfs( $self->opts->{"split-orfs"} );
    }
    $self->trans_method( $trans_method );
    $self->orf_filter_length( $self->opts->{"min-orf-len"} );

    # Set information about the algorithms being used
    $self->use_search_alg( "blast",     $self->opts->{"use_blast"}     );
    $self->use_search_alg( "last",      $self->opts->{"use_last"}      );
    $self->use_search_alg( "rapsearch", $self->opts->{"use_rapsearch"} );
    $self->use_search_alg( "hmmsearch", $self->opts->{"use_hmmsearch"} );
    $self->use_search_alg( "hmmscan",   $self->opts->{"use_hmmscan"}   );

    # Set local repository data
    $self->local_scripts_dir( $ENV{'SHOTMAP_LOCAL'} . "/scripts" ); #point to location of the shotmap scripts. Auto-detected from SHOTMAP_LOCAL variable.
    $self->ffdb( $self->opts->{"ffdb"} ); 
    $self->ref_ffdb( $self->opts->{"refdb"} ); 
    $self->family_subset( $self->opts->{"family-subset"} ); #constrain analysis to a set of families of interest

    # Set the search database properties and names
    $self->force_build_search_db( $self->opts->{"forcedb"} );
    $self->build_search_db( "blast", $self->opts->{"bdb"} );
    $self->build_search_db( "hmm",   $self->opts->{"hdb"} );    
    $self->search_db_split_size( "blast", $self->opts->{"blastsplit"} );
    $self->search_db_split_size( "hmm",   $self->opts->{"hmmsplit"}   );
    $self->nr( $self->opts->{"nr"} );     #should we build a non-redundant database
    $self->reps( $self->opts->{"reps"} ); #should we only use representative sequences? Probably defunct - just alter the input db
    my $db_prefix_basename = $self->opts->{"searchdb-prefix"};
    if( defined( $self->family_subset ) ){
	my $subset_name = basename( $self->opts->{"family-subset"} ); 
	$db_prefix_basename = $db_prefix_basename. "_" . $subset_name; 
    }
    $self->search_db_name( "basename", $db_prefix_basename );
    my $blastdb_name = $db_prefix_basename . '_' . ($self->reps()?'reps_':'') . 
	($self->nr()?'nr_':'') . $self->search_db_split_size( "blast");
    $self->search_db_name( "blast", $blastdb_name );
    if( ( $self->use_search_alg("blast") || $self->use_search_alg("last") || $self->use_search_alg("rapsearch") ) && 
	( ( !$self->build_search_db("blast") ) && ( ! -d $self->ffdb . "/BLASTdbs/" . $blastdb_name ) ) ){
	$self->Shotmap::Notify::dieWithUsageError(
	    "You are apparently trying to conduct a pairwise sequence search, " .
	    "but aren't telling me to build a database and I can't find one that already exists with your requested name " . 
	    "<${blastdb_name}>. As a result, you must use the --bdb option to build a new blast database"
	    );
    }
    $self->search_db_name_suffix( $self->{"opts"}->{"db_suffix"} );
    my $hmmdb_name = "${db_prefix_basename}_" . $self->search_db_split_size( "hmm" );
    $self->search_db_name( "hmm", $hmmdb_name );
    if( ( $self->use_search_alg("hmmsearch") || $self->use_search_alg("hmmscan")  ) && 
	( !$self->build_search_db("hmm") ) && 
	( ! -d $self->ffdb() . "/HMMdbs/" . $hmmdb_name ) ){
	$self->Shotmap::Notify::dieWithUsageError(
	    "You are apparently trying to conduct a HMMER related search, but aren't telling me to build an HMM database " . 
	    "and I can't find one that already exists with your requested name. As a result, you must use the --hdb option to build a new blast database"
	    );
    }
    if ( ( $self->use_search_alg("hmmscan") || $self->use_search_alg("hmmsearch") ) && 
	 !$self->build_search_db( "hmm" ) && !(-d $self->search_db_path( "hmm" ) )){
	warn("The hmm database path did not exist, BUT we did not specify the --hdb option to build a database.");
	die("The hmm database path did not exist, BUT we did not specify the --hdb option to build a database. We should specify --hdb probably.");
    }
    if ( ( $self->use_search_alg("last "|| $self->use_search_alg("blast") || $self->use_search_alg("rapsearch") ) && !$self->build_search_db( "blast" ) && !(-d $self->search_db_path( "blast" )))) {
	warn("The blast database path did not exist, BUT we did not specify the --bdb option to build a database.");
	die("The blast database path did not exist, BUT we did not specify the --bdb option to build a database. We should specify --bdb probably.");
    }
    
    # Set remote compute associated variables
    $self->remote( $self->opts->{"remote"} );
    if( $self->remote ){
	$self->stage( $self->opts->{"stage"} );
	$self->remote_user( $self->opts->{"ruser"} );
	$self->remote_host( $self->opts->{"rhost"} );
	print( $self->remote_host . "\n" );
	$self->remote_exe_path( $self->opts->{"rpath"} );
	$self->remote_master_dir( $self->opts->{"rdir"} );
	$self->remote_scripts_dir( $self->remote_master_dir . "/scripts" ); 
	$self->remote_ffdb(    $self->remote_master_dir . "/shotmap_ffdb" ); 
	$self->Shotmap::Notify::warn_ssh_keys();
	#if we aren't staging, does the database exist on the remote server?
	if( !$self->stage ){
	    if( $self->use_search_alg("blast") || $self->use_search_alg("last") || $self->use_search_alg("rapsearch") ){
		my $remote_db_dir = $self->remote_ffdb . "/BLASTdbs/" . $self->search_db_name( "blast" );
		my $command = "if ssh " . $self->remote_user . "\@" . $self->remote_host . " \"[ -d ${remote_db_dir} ]\"; then echo \"1\"; else echo \"0\"; fi";
		my $results = `$command`;
		if( $results == 0 ){ 
		    $self->Shotmap::Notify::dieWithUsageError( 
			"You are trying to search against a remote database that hasn't been staged. " . 
			"Run with --stage to place the db ${blastdb_name} on the remote server " . $self->remote_host . "\n"
			);
		}
	    }
	    if( $self->use_search_alg("hmmsearch") || $self->use_search_alg("hmmscan") ){
		my $remote_db_dir = $self->remote_ffdb . "/HMMdbs/" . $self->search_db_name( "hmm" );
		my $command = "if ssh " . $self->remote_user . "\@" . $self->remote_host . " \"[ -d ${remote_db_dir} ]\"; then echo \"1\"; else echo \"0\"; fi";
		my $results = `$command`;
		if( $results == 0 ){ 
		    $self->Shotmap::Notify::dieWithUsageError( 
			"You are trying to search against a remote database that hasn't been staged. " . 
			"Run with --stage to place the db ${hmmdb_name} on the remote server " . $self->remote_host . "\n"
			);
		}
	    }
	}
    }
    
    # Search specific settings
    if( defined( $self->opts->{"forcesearch"} ) ){
	$self->force_search( $self->opts->{"forcesearch"} );
    }

    # Set Relational (MySQL) database values
    $self->db_name( $self->opts->{"dbname"} );
    $self->db_host( $self->opts->{"dbhost"} );
    $self->db_user( $self->opts->{"dbuser"} );
    my $DBIstring = "DBI:mysql:" . $self->db_name . ":" . $self->db_host;
    $self->dbi_connection($DBIstring);
    if( defined( $self->opts->{"dbpass"} ) ){
	$self->db_pass( $self->opts->{"dbpass"} ); 
    } elsif( defined( $self->opts->{"conf-file"}) ){
	my $pass = $self->Shotmap::Load::get_password_from_file( $self->opts->{"conf-file"} );
	$self->db_pass( $pass );
    }
    $self->schema_name( $self->opts->{"dbschema"} );
    $self->build_schema();
    $self->multi_load( $self->opts->{"multi"} );
    $self->bulk_load( $self->opts->{"bulk"}  );
    $self->is_slim( $self->opts->{"slim"} );
    $self->bulk_insert_count( $self->opts->{"bulk_count"} );

    # Set parsing values
    $self->parse_evalue( $self->opts->{"parse-evalue"} ); 
    $self->parse_coverage( $self->opts->{"parse-coverage"} ); 
    $self->parse_score( $self->opts->{"parse-score"} );
    $self->small_transfer( $self->opts->{"small-transfer"} ); #????
    
    # Set classification values
    $self->clustering_strictness( $self->opts->{"is-strict"}); 
    $self->class_evalue( $self->opts->{"class-evalue"} ); 
    $self->class_coverage( $self->opts->{"class-coverage"} ); 
    $self->class_score( $self->opts->{"class-score"} ); 
    $self->top_hit_type( $self->opts->{"hit-type"} );
    
    # Set abundance calculation parameters
    $self->abundance_type(     $self->opts->{"abundance-type"}     );
    $self->normalization_type( $self->opts->{"normalization-type"} );

    # Set rarefication parameters
    if( defined( $self->opts->{"prerare-samps"} ) ){ 
	warn( "You are running with --prerare-samps, so I will only process " . 
	      $self->opts->{"prerare-samps"} . " sequences from each sample\n");
	$self->prerarefy_samples( $self->opts->{"prerare-samps"} );
    };
    if( defined( $self->opts->{"postrare-samps"} ) ){ 
	warn( "You are running with --postrare-samps. When calculating diversity statistics, I'll randomly select " . 
	      $self->opts->{"postrare-samps"} . " sequences from each sample\n");
	$self->postrarefy_samples( $self->opts->{"postrare-samps"} );
    };
    
    return $self;
}
    
1;
