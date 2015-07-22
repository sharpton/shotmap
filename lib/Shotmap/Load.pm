#!/usr/bin/perl -w

#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gmail.com
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program (see LICENSE.txt).  If not, see <http://www.gnu.org/licenses/>.

package Shotmap::Load;

use lib ($ENV{'SHOTMAP_LOCAL'} . "/ext/lib/perl5");     

use strict;
use warnings;
use Shotmap;
use Getopt::Long qw(GetOptionsFromString GetOptionsFromArray);
use File::Basename;
use Data::Dumper;

sub check_vars{
    my $self = shift;
    my $method_str = shift;
     if( $self->opts->{"remote"} ){
	 (defined($self->opts->{"rhost"}))      
	     or $self->Shotmap::Notify::dieWithUsageError(
		 "--rhost (remote computational cluster primary note) must be specified since you set --remote. Exbample --rhost='main.cluster.youruniversity.edu')!"
	     );
	 (defined($self->opts->{"ruser"}))          
	     or $self->Shotmap::Notify::dieWithUsageError(
		 "--ruser (remote computational cluster username) must be specified since you set --remote. Example username: --ruser='someguy'!"
	     );
	 (defined($self->opts->{"rdir"})) 
	     or $self->Shotmap::Notify::dieWithUsageError(
		 "--rdir (remote computational server scratch/flatfile location. Example: --rdir=/cluster/share/yourname/shotmap). This is mandatory!"
	     );
	 (defined($self->opts->{"rpath"})) 
	     or $self->Shotmap::Notify::warn(
		 "Note that --rpath was not defined. This is the remote computational server's \$PATH, where we find various executables like 'lastal'). " .
		 "Example: --rpath=/cluster/home/yourname/bin:/somewhere/else/bin:/another/place/bin). " . 
		 "COLONS delimit separate path locations, just like in the normal UNIX path variable. This is not mandatory, but is a good idea to include.\n"
	     );
	 if( !defined($self->opts->{"cluster-config"}) ){ 
	     $self->Shotmap::Notify::dieWithUsageError(
		 "You must specify an SGE cluster configuration header file, or I won't be able to properly submit jobs to the remote cluster. Example: " .
		 "--cluster-config=" . $ENV{'SHOTMAP_LOCAL'} . "data/config/cluster_config.txt\n"
		 );
	 }
	 if( ! -e $self->opts->{"cluster-config"} ){
	     $self->Shotmap::Notify::dieWithUsageError(
		 "I can't seem to access your cluster-config file. You specified --cluster-config=" .
		 $self->opts->{"cluster-config"} . 
		 ". Please double check this filepath and permissions."
		 );
	 }
	 if( !defined( $self->opts->{"searchdb-split-size"} ) ){
	     $self->Shotmap::Notify::dieWithUsageError(
		 "Since you are running a remote job (--remote), you must set --searchdb-split-size, " .
		 "as this is how shotmap determines the number of tasks to run. Future versions "      .
		 "will enable searching against a single database file\n"		 
		 );
	 }
    } else {
	$self->Shotmap::Notify::notify_verbose( "You did not invoke --remote, so shotmap will run locally\n" );
	(defined($self->opts->{"nprocs"})) 
	    or $self->Shotmap::Notify::dieWithUsageError( 
		"You did not specify the number of processors that shotmap should use on your local compute server. Rerun by specifying --nprocs or run a remote job" 
	    );
    }
    (!$self->opts->{"dryrun"}) 
	or $self->Shotmap::Notify::dieWithUsageError(
	    "Sorry, --dryrun is actually not supported, as it's a huge mess right now! My apologies."
	);
    #right now, we only require --input  to be set at time of test or run, allows run-time looping over projects
    unless( defined( $self->opts->{"pid"} ) || !$self->full_pipe ){ 
	(-d $self->opts->{"input"} || -f $self->opts->{"input"} ) 
	    or $self->Shotmap::Notify::dieWithUsageError(
		"You must provide a properly structured raw data (--input) directory! Sadly, the specified directory <" . 
		$self->opts->{"input"} . "> did not appear to exist, so we cannot continue!\n"
	    );
	if( -d $self->opts->{"input"} ){
	    $self->input_type( "directory" );
	} elsif( -f $self->opts->{"input"} ){
	    $self->input_type( "file" );
	} else {
	    die "Somehow I couldn't determine the type of input for " .
		$self->opts->{"input"} . "\n";
	}
    }    
    #but, if no ffdb or searchdb-dir is defined, then we need the rawdata to know where to place the searchdb
    if( !defined( $self->opts->{"input"}      ) &&
	!defined( $self->opts->{"ffdb"}         ) &&
	!defined( $self->opts->{"searchdb-dir"} ) ){
	$self->Shotmap::Notify::dieWithUsageError(
	    "You must specify the location of the directory containing your input sequence data using --input"
	    );
    }
		  
    if( $self->full_pipe ){
	if( !defined( $self->opts->{"ffdb"}         ) &&
	    !defined( $self->opts->{"searchdb-dir"} ) ){
		$self->Shotmap::Notify::notify_verbose(
		    "I see you did not specify either --ffdb or --searchdb-dir. This is fine, " .
		    "as I will create a ffdb within the directory specified by --input. " .
		    "But, it might be faster to use build_shotmap_searchdb.pl to build a search " .
		    "database and specify its location with --searchdb-dir"
		    );
	}
    }
    if( defined( $self->opts->{"ffdb"} ) &&
	! -d $self->opts->{"ffdb"} ){
	$self->Shotmap::Notify::warn(
	    "I don't see a previously created ffdb at " . $self->opts->{"ffdb"} . " so I will try to create it." );
	mkdir( $self->opts->{"ffdb"} );
	
	(-d $self->opts->{"ffdb"} ) 
	    or $self->Shotmap::Notify::dieWithUsageError(
		"--ffdb (local flat-file database directory path) was specified as --ffdb='" . $self->opts->{"ffdb"} . 
		"', but I can't find that directory, even after trying to create it. Please check that you have " . 
		"permission to write this directory."
	    );
    }
    if( defined( $self->opts->{"searchdb-dir"} ) ){
	if( $self->full_pipe ){
	    (-d $self->opts->{"searchdb-dir"} )
		or $self->Shotmap::Notify::dieWithUsageError(
		    "--searchdb-dir (shotmap formatted search database) was specified as --searchdb-dir='" .
		    $self->opts->{"searchdb-dir"} .
		    "', but that directory does not appear to exist!"
		);
	} else {
	    #do nothing (for now)
	}
    }
    unless( defined $self->opts->{"searchdb-dir"} ){
	(defined($self->opts->{"refdb"})) 
	    or $self->Shotmap::Notify::dieWithUsageError(
		"--refdb (local REFERENCE flat-file database directory path) or " .
		"--searchdb-dir (location ot pre-build SEARCH database) " .
		"must be specified!"
	    );
	(-d $self->opts->{"refdb"})
	    or $self->Shotmap::Notify::dieWithUsageError(
		"--refdb (local REFERENCE flat-file database directory path) was specified as --refdb='" . $self->opts->{"refdb"} . 
		"', but that directory appeared not to exist! Note that Perl does NOT UNDERSTAND the tilde (~) expansion for home directories, ".
		"so please specify the full path in that case. Specify a directory that exists."
	    );
    }
    (defined( $self->opts->{"db"} ) ) 
	or $self->Shotmap::Notify::dieWithUsageError(
	    "I do not know if you want to use a mysql database to store your data or not. Please specify with --db. Select from:\n" .
	    "<none> <full> <slim>"
	);
    unless( $self->is_conf_build ){
	if( defined( $self->opts->{"conf-file"} ) ){
	    ( -e $self->opts->{"conf-file"} ) or 
		$self->Shotmap::Notify::dieWithUsageError(
		    "You have specified a configuration file by using the --conf-file option, but I cannot find that file. You entered <" . 
		    $self->opts->{"conf-file"} . ">"
		);
	}
    }
    my %trans_list = ( "6FT"       => 1, 
		       "6FT_split" => 1, 
		       "prodigal"  => 1 
    );
    my $trans      = $self->opts->{"trans-method"};
    ( defined( $trans ) && exists( $trans_list{ $trans } ) ) ||
	$self->Shotmap::Notify::dieWithUsageError(
	    "You must specify a translation method with --trans-method. Select from " . 
	    join( " ", keys( %trans_list ) )
	);

    my %algo_list = ( "hmmsearch" => 1, 
		      "hmmscan"   => 1,
		      "blast"     => 1,
		      "last"      => 1, 
		      "rapsearch" => 1
	);
    my $algo = $self->opts->{"search-method"};
    ( defined( $algo ) && exists( $algo_list{$algo} ) ) ||
      $self->Shotmap::Notify::dieWithUsageError( 
	  "You must specify a search algorithm with --search-method. Select from " . 
	  join( " ", keys( %algo_list ) )
      );
    if( $self->opts->{"search-method"} eq "rapsearch" && 
	!defined( $self->opts->{"db-suffix"} ) ){  
	 $self->Shotmap::Notify::dieWithUsageError( 
	     "You must specify a database name suffix for indexing when running rapsearch!" 
	     ); 
     }
    
    
    #($coverage >= 0.0 && $coverage <= 1.0) or 
    #$self->Shotmap::Notify::dieWithUsageError(
    #"Coverage must be between 0.0 and 1.0 (inclusive). You specified: $coverage.");
    
    if( defined( $self->opts->{"goto"} ) ){
	if( !defined( $self->opts->{"pid"} ) ) { 
	    #try to auto set the pid. Note that for mysql db usage, must still be defined.
	    if( !$self->use_db ){
		if( defined( $self->opts->{"input"} ) ){
		    my $path = $self->opts->{"input"};
		    my ($name, $dir, $suffix) = fileparse( $path );     #get project name and load
		    $self->opts->{"pid"} = $name;
		}
	    }
	    if( $self->iterate_output ){
		if( !defined($self->opts->{"pid"} ) ) { 
		    $self->Shotmap::Notify::dieWithUsageError(
			"If you specify --goto=SOMETHING, you must ALSO specify the --pid to goto!"
			); 
		}
	    }
	}
     }     
     if( $self->opts->{"bulk"} && $self->opts->{"multi"} ){
	 $self->Shotmap::Notify::dieWithUsageError( 
	     "You are invoking BOTH --bulk and --multi, but can you only proceed with one or the other! I recommend --bulk."
	     );
     }     
     if( $self->opts->{"slim"} && !$self->opts->{"bulk"} ){
	$self->Shotmap::Notify::dieWithUsageError( 
	    "You are invoking --slim without turning on --bulk, so I have to exit!"
	    );
     }     
     #try to detect if we need to stage the database or not on the remote server based on runtime options
     if ($self->opts->{"remote"} and 
	 ($self->opts->{"hdb"} or $self->opts->{"bdb"} and !$self->opts->{"stage"}) ){	
	 if( $self->auto() ){
	     $self->Shotmap::Notify::warn(	     
		 "If you want to build a search database and if you are using a remote server, " .
		 "you MUST specify the --stage option to copy/re-stage the database on the remote machine!" . 
		 "I will be nice and automatically set --stage for you"
		 );
	     $self->opts->{"stage"} = 1;
	 } else {
	     $self->Shotmap::Notify::dieWithUsageError( 
		 "If you want to build a search database and if you are using a remote server, " .
		 "you MUST specify the --stage option to copy/re-stage the database on the remote machine!"
		 );	
	 }
     }     
     if( $self->opts->{"forcedb"} && 
	 ( !$self->opts->{"hdb"} && !$self->opts->{"bdb"} ) ){
	 $self->Shotmap::Notify::dieWithUsageError(
	     "I don't know what kind of database to build. If you specify --force-searchdb, you must also specify --search-method so I know what type of search-database to build");
     }    
    if( $self->opts->{"forcedb"} && 
	$self->opts->{"remote"} && 
	!$self->opts->{"stage"} ){
	$self->Shotmap::Notify::dieWithUsageError(
	    "You are using --force-searchdb but not telling me that you want to restage the database on the remote server <" . 
	    $self->opts->{"rhost"} . ">. Disambiguate by using --stage"
	    );
     }    
    my $dbtype = $self->opts->{"db"};
    if( $dbtype ne "none" &&
	$dbtype ne "full" &&
	$dbtype ne "slim" ){
	$self->Shotmap::Notify::dieWithUsageError(
	    "I do not recognize the option you've provided with --db. Please specify with --db. Select from:\n" .
	    "<none> <full> <slim>"
	    );
    }
    if( $dbtype ne "none" ){
	(defined($self->opts->{"dbhost"}))          
	    or $self->Shotmap::Notify::dieWithUsageError(
		"--dbhost (remote database hostname: example --dbhost='data.youruniversity.edu') MUST be specified!"
	    );
	(defined($self->opts->{"dbuser"}))
	    or $self->Shotmap::Notify::dieWithUsageError(
		"--dbuser (remote database mysql username: example --dbuser='dataperson') MUST be specified!"
	    );
	unless( $method_str eq "build_conf_file" ){
	    (defined($self->opts->{"dbpass"}) || defined($self->opts->{"conf-file"})) 
		or $self->Shotmap::Notify::dieWithUsageError(
		    "--dbpass (mysql password for user --dbpass='" . $self->opts->{"dbuser"} . 
		    "') or --conf-file (file containing password) MUST be specified here in super-insecure plaintext, " .
		    "unless your database does not require a password, which is unusual. If it really is the case that you require NO password, " .
		    "you should specify --dbpass='' OR include a password in --conf-file ...."
		);
	}
	if (!defined($self->opts->{"dbname"})) {
	    $self->Shotmap::Notify::dieWithUsageError(
		"Note: --dbname=NAME was not specified on the command line, so I don't know which mysql database to talk to. Exiting\n"
		);
	}    
	if (!defined($self->opts->{"dbschema"}) ) {
	    my $schema_name = "Shotmap::Schema";
	    $self->Shotmap::Notify::warn(
		"Note: --dbschema=SCHEMA was not specified on the command line, so we are using the default schema name, which is \"$schema_name\".\n"
		);
	}
    }
    unless( $self->is_conf_build ){
	if( defined(  $self->opts->{"searchdb-dir"} ) &&
	    !defined( $self->opts->{"searchdb-name"}) ){
	    my $stem = ".fa";
	    #come back and autodetect the difference between hmm and fa
	    if( $self->opts->{"search-method"} eq "hmmsearch" ||
		$self->opts->{"search-method"} eq "hmmscan"   ){
		$stem = ".hmm.gz";
	    }
	    #searchdb-dir was checked to be -d above
	    #use the first database split to get the basename
	    my @files = glob( $self->opts->{"searchdb-dir"} . "/*_1${stem}" ); 
	    if( $self->full_pipe && !( @files ) ){
		die( "There does not appear to be a properly formatted search database in the directory " .
		     "specified by --searchdb-dir" );
	    }
	    my $name  = basename( $files[0] );
	    $name =~ s/\_1${stem}$//;
	    $self->opts->{"searchdb-name"} = $name;
	} else {
	    (defined($self->opts->{"searchdb-name"})) 
		or $self->Shotmap::Notify::dieWithUsageError( 
		    "Note: You must name your search database using the --searchdb-name option. Exiting\n" 
		);
	}       
    }
    (defined($self->opts->{"normalization-type"})) 
	or  $self->Shotmap::Notify::dieWithUsageError( 
	    "You must provide a proper abundance normalization type on the command line (--normalization-type)"
	);
    my $norm_type = $self->opts->{"normalization-type"};
    if( $norm_type !~ "none" &&
	$norm_type !~ "target_length" &&
	$norm_type !~ "family_length" ){
	    $self->Shotmap::Notify::dieWithUsageError( 
		"You must specify a correct normalization-type with --normalization-type. ".
		"You provided <${norm_type}>. Instead, select from: <none> <target_length> <family_length>"
	);	
    }
    (defined($self->opts->{"abundance-type"}))     
	or  $self->Shotmap::Notify::dieWithUsageError( 
	    "You must provide a proper abundance type on the command line (--abundance-type)"
	);
    my $abund_type = $self->opts->{"abundance-type"};
    if( $abund_type !~ "counts"   &&
	$abund_type !~ "coverage" && 
	$abund_type !~ "rpkg"     ){
	    $self->Shotmap::Notify::dieWithUsageError( 
		"You must specify a correct abundance-type with --abundance-type. ".
		"You provided <${abund_type}>. Instead, select from: <counts> <rpkg> <coverage>"
	);	
    }
    if (defined($self->opts->{"rarefaction-type"})){
	my $type = $self->opts->{"rarefaction-type"};
	if( $type !~ "read" &&
	    $type !~ "orf"  &&
	    $type !~ "class-read" &&
	    $type !~ "class-orf" &&
	    $type !~ "pre-rarefaction" ){
	    $self->Shotmap::Notify::dieWithUsageError( 
		"You must specify a correct rarefaction-type with --rarefaction-type. ".
		"You provided <${type}>. Instead, select from: <orf>  <read>"
	);
	}
    }
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

    my( $conf_file,            $local_ffdb,            $local_reference_ffdb, $raw_data,         $input_pid,
	$goto,                 $db_username,           $db_pass,              $db_hostname,         $dbname,
	$schema_name,          $db_prefix_basename,    $search_db_split_size, $db_type,          $search_db_dir,
	#the following options are now obsolete
	$hmm_db_split_size,    $blast_db_split_size, 

	$family_subset_list,   $metadata_file,
	$reps_only,            $nr_db,                 $db_suffix,            $is_remote,           $remote_hostname,
	$remote_user,          $remoteDir,             $remoteExePath,        $use_scratch,         $waittime,
	$multi,                $mult_row_insert_count, $bulk,                 $bulk_insert_count,   $slim,
	$remote_bash_source,
	#the use_* methods are now obsolete
	$use_hmmscan,          $use_hmmsearch,         $use_blast,            $use_last,            $use_rapsearch,
	#use this in its place
	$search_method,
	$nseqs_per_samp_split, $prerare_count,         $postrare_count,       $trans_method,        $should_split_orfs,
	$orf_filter_length,    $p_evalue,              $p_coverage,           $p_score,             $evalue,
	$coverage,             $score,                 $top_hit,              $top_hit_type,        $stage,	
	$rarefaction_type,     $class_level,
	#the following options are now obsolete
	$hmmdb_build,          $blastdb_build,    
     	
	$build_search_db,      $force_db_build,       $force_search,        $small_transfer, 
	$normalization_type,   $abundance_type,       $ags_method,
	#vars being tested
	$nprocs, $auto, $python, $perl, $cluster_config_file, $use_array, $scratch_path, 
	$lightweight, $iterate_output,  $read_filter_length, $adapt,
	#non conf-file vars	
	$verbose,
	$extraBrutalClobberingOfDirectories,
	$dryRun,
	$reload,
	);

    my %options = (	
	"ffdb"           => \$local_ffdb
	, "refdb"        => \$local_reference_ffdb
	, "input"        => \$raw_data
	, "metadata-file" => \$metadata_file
	# Database-server related variables
	, "db"         => \$db_type 
	, "dbuser"     => \$db_username
	, "dbpass"     => \$db_pass
	, "dbhost"     => \$db_hostname
	, "dbname"     => \$dbname
	, "dbschema"   => \$schema_name
	# FFDB Search database related options
	, "searchdb-dir"        => \$search_db_dir
	, "searchdb-name"       => \$db_prefix_basename
	, "searchdb-split-size" => \$search_db_split_size
	, "hmmsplit"         => \$hmm_db_split_size # now obsolete
	, "blastsplit"       => \$blast_db_split_size #now obsolete
	, "family-subset"    => \$family_subset_list	  ####RECENTLY CHANGED THIS KEY CHECK ELSEWHERE
	, "reps-only"        => \$reps_only
	, "nr"               => \$nr_db
	, "db-suffix"        => \$db_suffix #only needed for rapsearch
	# Remote computational cluster server related variables
	, "remote"     => \$is_remote
	, "rhost"      => \$remote_hostname
	, "ruser"      => \$remote_user
	, "rdir"       => \$remoteDir
	, "rpath"      => \$remoteExePath
	, "scratch"    => \$use_scratch
	, "wait"       => \$waittime        #   <-- in seconds
	, "cluster-config" => \$cluster_config_file
	, "use-array"      => \$use_array,
	, "scratch-path"   => \$scratch_path,
	, "remote-bash-source" => \$remote_bash_source,
	# Local compute related variables
	, "nprocs"     => \$nprocs #overrides hmmsplit, blastsplit (both =1) and seq-split-size (total seqs/nprocs)
	#db communication method (NOTE: use EITHER multi OR bulk OR neither)
	,    "multi"        => \$multi
	,    "multi-count"  => \$mult_row_insert_count
	,    "bulk"         => \$bulk
	,    "bulk-count"   => \$bulk_insert_count
	,    "slim"         => \$slim #no longer specified at the command line, use db-type
	#search methods 
	,    "use_hmmscan"   => \$use_hmmscan   #obsolete
	,    "use_hmmsearch" => \$use_hmmsearch #obsolete
	,    "use_blast"     => \$use_blast     #obsolete
	,    "use_last"      => \$use_last      #obsolete
	,    "use_rapsearch" => \$use_rapsearch #obsolete
	,    "search-method" => \$search_method
	#general options
	,    "seq-split-size"   => \$nseqs_per_samp_split
	,    "prerare-samps"    => \$prerare_count
	,    "postrare-samps"   => \$postrare_count
	,    "rarefaction-type" => \$rarefaction_type #could be orf, class_orf, or class_read in theory, only read and orf currently implemented
	#translation options
	,    "trans-method"    => \$trans_method
	,    "split-orfs"      => \$should_split_orfs
	,    "orf-filter-len"  => \$orf_filter_length
	,    "read-filter-len" => \$read_filter_length
	#search result parsing thresholds (less stringent, optional, defaults to family classification thresholds)
	,    "parse-evalue"   => \$p_evalue
	,    "parse-coverage" => \$p_coverage
	,    "parse-score"    => \$p_score
	,    "small-transfer" => \$small_transfer
	#family classification thresholds (more stringent)
	,    "class-evalue"   => \$evalue
	,    "class-coverage" => \$coverage
	,    "class-score"    => \$score
	,    "class-level"    => \$class_level
	,    "top-hit"        => \$top_hit
	,    "hit-type"       => \$top_hit_type
	#abundance claculation parameters
	,    "abundance-type"     => \$abundance_type
	,    "normalization-type" => \$normalization_type
	,    "ags-method"         => \$ags_method
	#usually set at run time
	, "conf-file"         => \$conf_file
	, "pid"               => \$input_pid          
	, "goto"              => \$goto     
	, "auto"              => \$auto  #use non-adaptive defaults
	, "adapt"             => \$adapt #use adaptive classification
	, "python"            => \$python
	, "perl"              => \$perl
	, "lightweight"       => \$lightweight #tries to keep the ffdb as small as possible
	, "iterate-output"    => \$iterate_output #saves all old output generated using different classification/abundance thresholds
	#forcing statements
	,    "stage"          => \$stage # should we "stage" the database onto the remote machine?
	,    "build-searchdb" => \$build_search_db
	,    "hdb"            => \$hmmdb_build #obsolete
	,    "bdb"            => \$blastdb_build #obsolete
	,    "force-searchdb" => \$force_db_build 
	,    "forcesearch" => \$force_search
	,    "verbose"     => \$verbose
	,    "clobber"     => \$extraBrutalClobberingOfDirectories
	,    "dryrun"      => \$dryRun
	,    "reload"      => \$reload
	);
    my @opt_type_array = ( "input|i=s"      
			  , "metadata-file|m=s"
			  # SearchDB/FFDB path variables
			  , "searchdb-dir|d=s"
			  , "ffdb|o=s"
			  , "refdb|r=s" 			  
			  # Database-server related variables
			  , "db=s"
			  , "dbuser|u=s"           
			  , "dbpass|p=s"         
			  , "dbhost=s"          
			  , "dbname=s" 
			  , "dbschema=s"   
			      # FFDB Search database related options
			  , "searchdb-name=s"
			  , "searchdb-split-size=i"
			  , "hmmsplit=i"    #obsolete
			  , "blastsplit=i"  #obsolete
			  , "family-subset=s" 
			  , "reps-only!"
			  , "nr!"
			  , "db-suffix:s"  
			  # Remote computational cluster server related variable
			  , "remote-bash-source:s"
			  , "remote!"
			  , "rhost=s"
			  , "ruser=s" 
			  , "rdir=s"
			  , "rpath=s"
			  , "scratch!"
			  , "wait|w=i"    
			  , "cluster-config=s"
			  , "use-array!"
			  , "scratch-path:s"
			  # Local compute related vars
			  , "nprocs=i" #this overrides read_split_size!
			  #db communication method (NOTE: use EITHER multi OR bulk OR neither)
			  , "multi!"         ### OBSOLETE?
			  , "multi-count:i"  ### OBSOLETE?
			  , "bulk!"
			  , "bulk-count:i"
			  , "slim!"         
			  #search methods
			  , "use_hmmscan!" 
			  , "use_hmmsearch!"
			  , "use_blast!" 
			  , "use_last!"
			  , "use_rapsearch!"
			  , "search-method=s"
			  #general options
			  , "seq-split-size=i" 
			  , "prerare-samps:i"
			  , "postrare-samps:i" 
			  , "rarefaction-type:s"
			  #translation options
			  , "trans-method:s" 
			  , "split-orfs!"    
			  , "orf-filter-len:i"    #keep orfs greater than or equal to this length
			  , "read-filter-len:i"   #keep reads greater than or equal to this length
			  #search result parsing thresholds (less stringent, optional, defaults to family classification thresholds)
			  , "parse-evalue:f" 
			  , "parse-coverage:f"
			  , "parse-score:f"   
			  , "small-transfer!"
			  #family classification thresholds (more stringent)
			  , "class-evalue:f"
			  , "class-coverage:f"
			  , "class-score:f"
			  , "class-level=s"  #read, orf
			  ,    "top-hit!"      ### NEED TO INTEGRATE METHODS
			  ,    "hit-type:s"  
			  #abundance calculation parameters
			  , "abundance-type:s"
			  , "normalization-type:s"			  			  
			  , "ags-method:s"
			  #general settings
			  , "conf-file|c=s" 
			  , "pid=i"
			  , "goto|g=s"			  
			  , "auto!"
			  , "adapt!"
			  , "python=s"
			  , "perl=s"
			  , "lightweight!"
			  , "iterate-output!"
			  #forcing statements
			  , "stage!"
			  , "build-searchdb!"
			  , "hdb!"  #obsolete
			  , "bdb!"  #obsolete
			  , "force-searchdb!"
			  , "forcesearch!"
			  , "verbose|v!"
			  , "clobber"   
			  , "dryrun|dry!"
			  , "reload!"   		
	);
    #grab command line options

    GetOptionsFromArray( \@args, \%options, @opt_type_array );
    unless( $self->is_conf_build ){
	if( defined( $conf_file ) ){	
	    if( ! -e $conf_file ){ 
		$self->Shotmap::Notify::dieWithUsageError( 
		    "The path you supplied for --conf-file doesn't exist! You used <$conf_file>\n" 
		    ); 
	    }	    	 
	    my $opt_str = get_conf_file_options( $conf_file, \%options );
	    GetOptionsFromString( $opt_str, \%options, @opt_type_array );
	} else {
	    #$self->Shotmap::Notify::warn( "You did not supply a configuration file (i.e., --conf-file). " .
	    #"It is recommend you do so, unless you want to pass all arguments " .
	    #"via the command line\n" );
	}
    } else {
	( defined( $conf_file ) )
	    or $self->Shotmap::Notify::dieWithUsageError( 
		"You must specify the location of your configuration file with --conf-file"
	    );
    }
    #getopts keeps the values referenced, so we have to dereference them if we want to directly call. 
    #Note: if we ever add hash/array vals, we'll have to reconsider this function
    %options = %{ dereference_options( \%options ) };
    %options = %{ $self->Shotmap::Load::load_defaults( \%options ) };
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
    
    #This needs to be set before rest for proper printing
    $self->verbose( $self->opts->{"verbose"} );

    #set automator
    $self->auto( $self->opts->{"auto"} );
    if( $self->auto ){
	$self->Shotmap::Notify::print_verbose( 
	    "I see --auto is on, so I will automate as " .
	    "much as possible. You can turn me off with --noauto" );
    }
    #set adaptor
    $self->adapt( $self->opts->{"adapt"} );
    if( $self->adapt ){
	$self->Shotmap::Notify::print_verbose( 
	    "I see --adapt is on, so I will adaptive classify reads. " .
	    "Note this might override other options. " . 
	    "You can turn me off with --noadapt" );
	$self->adapt_class(1);
	$self->parse_score( $self->readlen_map->{"thresholds"}->{'0'} ); #lowest accepted adapt-class threshold
	$self->class_score("");
    }

    # Some run time parameters
    $self->dryrun( $self->opts->{"dryrun"} );
    $self->project_id( $self->opts->{"pid"} );
    $self->raw_data( $self->opts->{"input"} );
    if( defined( $self->opts->{"metadata-file"} ) ){
	$self->metadata_file( $self->opts->{"metadata-file"} );
    }
    $self->wait( $self->opts->{"wait"} );
    $self->scratch( $self->opts->{"scratch"} );
    $self->lightweight( $self->opts->{"lightweight"} );
    if( defined( $self->opts->{"iterate-output"} ) ){
	$self->iterate_output( $self->opts->{"iterate-output"} );
    }
    $self->clobber( $self->opts->{"clobber"} );
    
    # Set remote - do here because it f/x many downstream vars
    # more on remote variables below.
    $self->remote( $self->opts->{"remote"} );

    # Set read parameters
    $self->read_split_size( $self->opts->{"seq-split-size"} ); 
    $self->nprocs( $self->opts->{"nprocs"} ); #this overrides read_split_size

    # Set orf calling parameters
    $self->trans_method(      $self->opts->{"trans-method"}   );
    $self->orf_filter_length( $self->opts->{"orf-filter-len"} );
    $self->read_length_filter( $self->opts->{"read-filter-len"} );

    # Set information about the algorithms being used
    my $search_method = $self->opts->{"search-method"};
    my $blast_methods = { "blast"     => 1,
			  "rapsearch" => 1,
			  "last"      => 1,
    };
    my $hmm_methods   = { "hmmscan"    => 1,
			  "hmmsearch"  => 1,
    };
    $self->search_method( $search_method );
    if( defined( $blast_methods->{$search_method} ) ){
	$self->search_type( "blast" );
	my $meth = $self->search_method;
	if( $meth eq "rapsearch" ){
	    $self->search_db_fmt_method( "prerapsearch" );	    
	} elsif( $meth eq "last" ){
	    $self->search_db_fmt_method( "lastdb" );	    	    
	} elsif( $meth eq "blast" ){
	    $self->search_db_fmt_method( "makeblastdb" );	    	    
	}
    } elsif( defined( $hmm_methods->{$search_method} ) ){
	$self->search_type("hmm");
    } else {
	$self->Shotmap::Notify::dieWithUsageError( "Can't glean search algorithm type from declared --search-method=${search_method}" );
    }

    # Set local repository data
    $self->local_scripts_dir( $ENV{'SHOTMAP_LOCAL'} . "/scripts" ); #point to location of the shotmap scripts. Auto-detected from SHOTMAP_LOCAL variable.
    if( defined( $self->opts->{"ffdb"} ) ){
	$self->is_iso_db( 0 );
    }
    $self->ffdb( $self->opts->{"ffdb"} ); 
    $self->ref_ffdb( $self->opts->{"refdb"} ); 
    $self->family_subset( $self->opts->{"family-subset"} ); #constrain analysis to a set of families of interest

    # Set the search database properties and names
    if( defined( $self->opts->{"searchdb-dir"} ) ){
	$self->iso_db_build(1);
	$self->search_db_path_root( $self->opts->{"searchdb-dir"} );
    } else {
	$self->search_db_path_root( $self->ffdb);
    }
    $self->force_build_search_db( $self->opts->{"force-searchdb"} );
    if( $self->force_build_search_db ){
	$self->build_search_db( $self->search_type, 1 );
	$self->stage(1) if $self->remote;
    } else {
	$self->build_search_db( $self->search_type, $self->opts->{"build-searchdb"} );
    }
    $self->search_db_split_size( $self->search_type, $self->opts->{"searchdb-split-size"} );
    $self->nr( $self->opts->{"nr"} );     #should we build a non-redundant database
    $self->reps( $self->opts->{"reps"} ); #should we only use representative sequences? Probably defunct - just alter the input db
    my $db_prefix_basename = $self->opts->{"searchdb-name"};    
    $self->search_db_name_suffix( $self->opts->{"db-suffix"} );
    if( defined( $self->family_subset ) ){
	my $subset_name = basename( $self->opts->{"family-subset"} ); 
	$db_prefix_basename = $db_prefix_basename. "_" . $subset_name; 
    }
    $self->search_db_name( "basename", $db_prefix_basename );
    my $db_name;
    if( $self->search_type eq "blast" ){
	unless( defined( $self->opts->{"searchdb-dir"} ) &&
		$self->full_pipe ){ #only do this if we're building a searchdb on the fly
	    if( $self->remote ){
		$db_name = $db_prefix_basename . 
		    ($self->reps()?'_reps':'') . 
		    ($self->nr()?'_nr':'')     . 
		    (defined( $self->search_db_split_size( $self->search_type ) ) ? "_" . $self->search_db_split_size( $self->search_type ) : '');
	    } else { #local job, so no search db splits
		$db_name = $db_prefix_basename . 
		    ($self->reps()?'_reps':'') . 
		    ($self->nr()?'_nr':'');
	    }
	} else {
	    $db_name = $self->opts->{"searchdb-name"};
	}
	$self->search_db_name( $self->search_type, $db_name );
	if( ( !$self->build_search_db( $self->search_type  ) ) && ( ! -d $self->search_db_path( $self->search_type ) ) ){
	    if( $self->auto() && !$self->is_conf_build){ 
		unless( $self->is_iso_db ){ #build_search_db is implicit.
		    $self->Shotmap::Notify::warn(
			"You are apparently trying to conduct a pairwise sequence search, " .
			"but aren't telling me to build a database and I can't find one that already exists with your requested name " . 
			"<${db_name}>. I will build one for you."
			);
		}
		$self->build_search_db( $self->search_type, 1 );
	    } else {
		unless( $self->is_test || $self->is_conf_build ){
		    $self->Shotmap::Notify::dieWithUsageError(
			"You are apparently trying to conduct a pairwise sequence search, " .
			"but aren't telling me to build a database and I can't find one that already exists with your requested name " . 
			"<${db_name}>. As a result, you must use the --build-searchdb option to build a new blast database"
			);	    
		}
	    }
	}
    }
    if( $self->search_type eq "hmm" ){
	if( $self->remote ){
	    $db_name = "${db_prefix_basename}" . 
		(defined( $self->search_db_split_size( $self->search_type ) ) ? "_" . $self->search_db_split_size( $self->search_type ) : '');
	} else { #local job, so no search db splits
	    $db_name = $db_prefix_basename;
	    $self->search_db_name( $self->search_type, $db_name );
	    if ( !$self->build_search_db( $self->search_type ) && ( ! -d $self->search_db_path( $self->search_type ) ) ){
		if( $self->auto() ){
		    $self->Shotmap::Notify::warn(
			"You are apparently trying to conduct a HMMER related search, " .
			"but aren't telling me to build a database and I can't find one " .
			"that already exists with your requested name " . 
			"<${db_name}>. I will build one for you."
			);
		    $self->build_search_db( $self->search_type, 1 );
		} else {
		    $self->Shotmap::Notify::dieWithUsageError(
			"You are apparently trying to conduct a HMMER related search, but aren't telling me to build an HMM database " . 
			"and I can't find one that already exists with your requested name. As a result, you must use the " . 
			"--build-searchdb option to build a new blast database"
			);
		}
	    }
	}
    }
    # Set remote compute associated variables
    if( $self->remote ){
	$self->stage( $self->opts->{"stage"} ) unless defined $self->stage(); #might have set above in force-searchdb statements
	$self->remote_user( $self->opts->{"ruser"} );
	$self->remote_host( $self->opts->{"rhost"} );
	print( $self->remote_host . "\n" );
	$self->remote_exe_path( $self->opts->{"rpath"} );
	$self->remote_master_dir( $self->opts->{"rdir"} );
	$self->remote_ffdb(    $self->remote_master_dir . "/shotmap_ffdb" ); 
	$self->scratch_path( $self->opts->{"scratch-path"} );
	$self->use_array( $self->opts->{"use-array"} );
	$self->cluster_config_file( $self->opts->{"cluster-config"} );
	$self->Shotmap::Notify::warn_ssh_keys();	
	if( defined( $self->opts->{"remote-bash-source"} ) ){
	    $self->bash_source( $self->opts->{"remote-bash-source"} );
	}
	#if we aren't staging, does the database exist on the remote server?
	#skip for now if goto is invoked.
	unless( $self->is_conf_build ){
	    if( !$self->stage && !(defined( $self->{"opts"}->{"goto"} ) ) ){
		$self->Shotmap::Load::stage_check();
	    }
	}
    }
    
    # Search specific settings
    if( defined( $self->opts->{"forcesearch"} ) ){
	$self->force_search( $self->opts->{"forcesearch"} );
    }
    
    # Set Relational (MySQL) database values
    $self->db_type( $self->opts->{"db"} );
    if( $self->db_type ne "none" ){
	$self->use_db( 1 );
	$self->Shotmap::DB::load_db_libs();
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
	$self->bulk_insert_count( $self->opts->{"bulk_count"} );
	if( $self->db_type eq "slim" ){
	    $self->is_slim( 1 );
	}
    } else {
	$self->use_db( 0 );
	$self->db_name( "" ); #if local, don't need the db name, but still need to set it so subsequent code works
    }

    # Set parsing values
    unless( $self->adapt ){
	$self->parse_evalue( $self->opts->{"parse-evalue"} ); 
	$self->parse_coverage( $self->opts->{"parse-coverage"} ); 
	$self->parse_score( $self->opts->{"parse-score"} );
    }
    if( $self->lightweight ){
	$self->small_transfer( 1 );
    } else {
	$self->small_transfer( $self->opts->{"small-transfer"} );
    }
    # Set classification values
    $self->clustering_strictness( $self->opts->{"is-strict"}); 
    unless( $self->adapt ){
	$self->class_evalue( $self->opts->{"class-evalue"} ); 
	$self->class_coverage( $self->opts->{"class-coverage"} ); 
	$self->class_score( $self->opts->{"class-score"} ); 
    }
    $self->class_level( $self->opts->{"class-level"} );
    $self->top_hit_type( $self->opts->{"hit-type"} );
    
    # Set abundance calculation parameters
    $self->abundance_type(     $self->opts->{"abundance-type"}     );
    $self->normalization_type( $self->opts->{"normalization-type"} );
    $self->ags_method(           $self->opts->{"ags-method"}           ); #currently "none" or "microbecensus"

    # Set rarefication parameters
    if( defined( $self->opts->{"prerare-samps"} ) ){ 
	$self->Shotmap::Notify::warn( "You are running with --prerare-samps, so I will only process " . 
	      $self->opts->{"prerare-samps"} . " sequences from each sample\n");
	$self->prerarefy_samples( $self->opts->{"prerare-samps"} );
	$self->rarefaction_type( "pre-rarefaction" );
    };
    if( defined( $self->opts->{"postrare-samps"} ) ){ 
	$self->Shotmap::Notify::warn( "You are running with --postrare-samps. When calculating diversity statistics, I'll randomly select " . 
	      $self->opts->{"postrare-samps"} . " sequences from each sample\n");
	$self->postrarefy_samples( $self->opts->{"postrare-samps"} );
	$self->rarefaction_type( $self->opts->{"rarefaction-type"} );
    };

    ## some system level settings
    # PYTHON
    if( defined( $self->opts->{"python"} ) ){
	$self->python( $self->opts->{"python"} );
    } else {
	$self->python( "python" );
    }
    # PERL
    if( defined( $self->opts->{"perl"} ) ){
	$self->perl( $self->opts->{"perl"} );
    } else {
	$self->perl( "perl" );
    }
    return $self;
}

sub load_defaults{
    my ( $self, $options ) = @_; #options is a hashref    
    my $defaults = {
	    # mysql db settings
  	    "db"                    => "none"
	    # search-db settings	
	    ,    "nr"               => 1
	    ,    "db-suffix"        => 'rsdb'
	    ,    "verbose"          => 0
	    # Remote computational cluster server related variables
	    ,        "ruser"        => $ENV{"LOGNAME"}
	    ,        "scratch"      => 1
	    ,        "wait"         => 5
	    ,        "use-array"    => 1
	    ,       "scratch-path"  => "/scratch/"
	    #db communication method (NOTE: use EITHER multi OR bulk OR neither)
	    ,        "dbuser"       => $ENV{"LOGNAME"}
	    ,        "dbschema"     => "Shotmap::Schema"
	    ,        "bulk"         => 1
	    ,        "bulk-count"   => 1000	
	    # search methods 
	    ,       "search-method" => 'rapsearch'
	    # general options
	    ,      "seq-split-size" => 100000
	    ,    "rarefaction-type" => "read"
	    ,    "auto"             => 1
	    ,    "adapt"            => 1
	    ,    "lightweight"      => 1
	    ,    "iterate-output"   => 0
	    ,    "nprocs"           => 1
	    # translation options
	    ,      "trans-method"    => 'prodigal'
	    ,      "orf-filter-len"  => 15
	    ,      "read-filter-len" => 50
	    # search result parsing thresholds (less stringent, optional, defaults to family classification thresholds)
	    ,      "parse-score"    => $self->readlen_map->{"thresholds"}->{'0'} #lowest accepted adapt-class threshold
	    # family classification thresholds (more stringent)
	    ,      "top-hit"        => 1
	    ,      "hit-type"       => 'best_hit'
	    ,      "class-level"    => 'read'
	    # abundance claculation parameters
	    ,      "abundance-type"     => 'coverage'
	    ,      "normalization-type" => 'target_length'
	    ,      "ags-method"         => 'microbecensus'
    };
    if( defined( $options->{"input"} ) ){
	my $input = $options->{"input"};
	if( -d $input ){
	    $defaults->{"ffdb"} = $options->{"input"} . "/shotmap_ffdb/";
	} elsif( -f $input ){
	    my( $file, $path ) = fileparse( $input );
	    $defaults->{"ffdb"} = $path . "/shotmap_ffdb/";
	}
	$self->is_iso_db(1); #on by default, turn off if ffdb specified by user
    }
    if( defined( $options->{"refdb"} ) ){
	$defaults->{"searchdb-name"} = basename( $options->{"refdb"} );
    }
    #############
    # Set configuration-specific defaults here

    #PLATFORMS
    #may move read length specific to autodetect, but this is here in case we 
    #ever need platform specific settings. Not currently implemented.
    my $config_count = 0;

    if( defined( $options->{"hiseq-101"} ) ){
	$defaults->{"class-score"} = 31;
	$config_count++;
    }
    if( defined( $options->{"miseq-300"} ) ){
	$defaults->{"class-score"} = 42;
	$config_count++;
    }
    if( defined( $options->{"454"} ) ) {
	$defaults->{"class-score"} = 42;
	$config_count++;
    }
    if( $config_count > 1 ){
       $self->Shotmap::Notify::dieWithUsageError(
	   "You can only specify either --hiseq-101, OR --miseq-300, OR --454"
	   );
    }
    
    # RAPID v. MAXACC
    if( defined( $options->{"rapid"} ) && defined( $options->{"maxacc"} )){
	$self->Shotmap::Notify::dieWithUsageError(
	    "You can only invoke either --rapid or --maxacc!"
	    );	
    }
    if( defined( $options->{"rapid"} ) ){
	$defaults->{"prerare-samps"} = 1500000;
	$defaults->{"search-method"} = "rapsearch_accelerated";	
    }
    if( defined( $options->{"maxacc"} ) ){
	$defaults->{"search-method"} = "blast"; #note, should have switch to hmm on sequence length
	$defaults->{"trans-method"}  = "6FT_split";
    }
    #Overwrite defaults with user-defined variables
    foreach my $opt( keys( %$defaults ) ){
	next if defined $options->{$opt}; #user provided a variable, which we want
	$options->{$opt} = $defaults->{$opt};
    }
    return $options;
}

sub stage_check{
    my $self    = shift;
    my $remote_db_dir = $self->remote_search_db;
    my $command = "if ssh " . $self->remote_user . "\@" . $self->remote_host . " \"[ -d ${remote_db_dir} ]\"; then echo \"1\"; else echo \"0\"; fi";
    my $results = `$command`;
    if( $results == 0 ){ 
	$self->Shotmap::Notify::dieWithUsageError( 
	    "You are trying to search against a remote database that hasn't been staged. " . 
	    "Run with --stage to place the db " . $self->search_db_name . " on the remote server " . $self->remote_host . "\n"
	    );
    }
    return;
}
    
1;
