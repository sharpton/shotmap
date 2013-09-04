#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use File::Path qw(make_path rmtree);
use IPC::System::Simple qw(capture $EXITVAL);
use File::Spec;

#called by remote, executes run_hmmsearch.sh, run_hmmscan.sh, or run_blast.sh, etc.
warn "This command was run:\n perl run_remote_parse_resultshandler.pl @ARGV";

my( $scriptpath, $query_seq_dir,     $result_dir,
    $sample_id,  $classification_id, $algo,       $trans_method,
    $proj_dir,   $scripts_dir,       $db_name,    $nsplits,
    $t_coverage, $t_evalue,          $t_score,    
    );

my $waitTimeInSeconds = 5; # default value is 5 seconds between job checks

my $loop_number       = 10; #how many times should we check that the data was run to completion? we restart failed jobs here
my $force_parse       = 0;
my $delete_raw_switch = 0; #should we delete the raw search results? Decreases file transfer time. Most relevant data stored in .msyqld files

GetOptions("resultdir|i=s"  => \$result_dir,
	   "querydir|q=s"   => \$query_seq_dir,	  
	   "dbname|n=s"     => \$db_name,
	   "scriptpath|x=s" => \$scriptpath,
	   "w=i"            => \$waitTimeInSeconds,  # between 1 and 60. More than 60 is too long! Check more frequently than that. 1 is a good value.
	   "nsplits=i"      => \$nsplits, #how many db splits? used to determine number of job arrays to set up.
	   "sample-id=i"    => \$sample_id,
#	   "class-id=i"     => \$classification_id,
	   "algo=s"         => \$algo,
	   "transmeth=s"    => \$trans_method,
	   "evalue|e:f"     => \$t_evalue,
	   "coverage|c:f"   => \$t_coverage,
	   "score|s:f"      => \$t_score,
	   "proj-dir=s"     => \$proj_dir,
	   "script-dir=s"   => \$scripts_dir,
	   "forceparse!"    => \$force_parse,
	   "delete-raw=i"   => \$delete_raw_switch,
    );

(defined($result_dir) && (-d $result_dir)) or die "The result directory <$result_dir> was not valid on the REMOTE SERVER! Double check it.";
(defined($query_seq_dir) && (-d $query_seq_dir)) or die "The query sequence directory <$query_seq_dir> was not valid on the REMOTE SERVER! Double check it.";
(defined($db_name)) or die "Database name <$db_name> was not valid!";
($waitTimeInSeconds >= 1 && $waitTimeInSeconds <= 600) or die "The wait time in seconds has to be between 1 and 60 (60 seconds = 1 minute). Yours was: ${waitTimeInSeconds}\n";
(defined($scriptpath) && (-f $scriptpath)) or die "The script at <$scriptpath> was not valid!";

#Convert undefined threshold settings to "NULL" so bash can pass them to perl properly
if( !defined( $t_coverage ) ){
    $t_coverage = "NULL";
}
if( !defined( $t_evalue ) ){
    $t_evalue = "NULL";
}
if( !defined( $t_score ) ){
    $t_score = "NULL";
}

#create a jobid storage log
my %jobs = ();
#open the query seq file directorie (e.g., /orfs/) and grab all of the orf splits
opendir( IN, $query_seq_dir ) || die "Can't opendir $query_seq_dir for read in run_remote_parse_results_handler.pl\n";
my @query_files = readdir( IN );
closedir( IN );
#loop over the split orf seq files, which represent launching a queue job for each
if( $force_parse ){ 
    foreach my $query_seq_file( @query_files ){
	next if( $query_seq_file =~ m/^\./  ); # skip the '.' and '..' and other dot files
	if( $query_seq_file =~ m/\.tmp\d*$/ ){ #if we have an old rapsearch run that we're reprocessing, we can't process the *.tmp files!
	    next; #this is safer than unlink; what is user has strange file extention? let's just pass. can delete by hand if abs. necessary
	    #unlink( $query_seq_file );
	}
	#need to set naming conventions for qsub script. These are same conventions used in run_remote_search_handler.pl
	my $result_file_prefix = get_prefix( $query_seq_file, $db_name );
	my $result_file_suffix = get_suffix( $algo );
	
	#modify result_dir here such that the output is placed into each split's subdir w/in $result_dir
	my $split_sub_result_dir = File::Spec->catdir($result_dir, $query_seq_file);
	if( ! -d $split_sub_result_dir ){
	    warn( "I could not find the following search result directory: ${split_sub_result_dir}\n" );
	    next;
	}
	#prep the array string for the array job option
	my $array_string = "1-${nsplits}";
	#run the jobs!
	print "-"x60 . "\n";
	print " RUN REMOTE PARSE RESULTS HANDLER.PL arguments for <${query_seq_file}>\n";
	print "          LOOP NUMBER: 0\n";
	print "          SCRIPT PATH: $scriptpath\n";
	print "        QUERY SEQ DIR: $query_seq_dir\n";
	print "       QUERY SEQ FILE: $query_seq_file\n";
	print "      RESULT FILE DIR: $split_sub_result_dir\n";
	print "   RESULT FILE PREFIX: $result_file_prefix\n";
	print "   RESULT FILE SUFFIX: $result_file_suffix\n";
	print "            SAMPLE_ID: $sample_id\n";
#    print "    CLASSIFICATION_ID: $classification_id\n";
	print "     SEARCH ALGORITHM: $algo\n";
	print "   TRANSLATION METHOD: $trans_method\n";
	print "    THRESHOLD: EVALUE: $t_evalue\n";
	print "  THRESHOLD: COVERAGE: $t_coverage\n";
	print "     THRESHOLD: SCORE: $t_score\n";
	print "           PROJECTDIR: $proj_dir\n";
	print "           SCRIPTSDIR: $scripts_dir\n";
	print "           DELETE_RAW: $delete_raw_switch\n";
	print "         ARRAY STRING: $array_string\n";
	print "-"x60 . "\n";
	my $results = run_remote_parse($scriptpath, $query_seq_dir, $query_seq_file, 
				       $split_sub_result_dir, $result_file_prefix, $result_file_suffix,
				       $sample_id, $algo, $trans_method,
				       $t_evalue,  $t_coverage, $t_score, $proj_dir, $scripts_dir, $delete_raw_switch,
				       $array_string);
	if ($results =~ m/^Your job-array (\d+)\./) { #an array job
	    my $job_id = $1;
	    $jobs{$job_id}++;
	} #Your job 8119214 ("run_rapsearch.sh") has been submitted 
	elsif ($results =~ m/^Your job (\d+) /) { #not an array job
	    my $job_id = $1;
	    $jobs{$job_id}++;
	} 
	else {
	    die "Remote server did not return a properly formatted job id when running run_parse_search_results.sh on (remote) localhost. Got $results instead!";
	}
    }
}

#At this point, we have a lot ofjobs in the queue. Let's monitor the queue and report back to local when jobs are complete 
my @job_ids = keys(%jobs);
my $time = remote_job_listener(\@job_ids, $waitTimeInSeconds);

#all of the jobs are done. Let's make sure they've all produced output. If not, rerun those jobs
my $count = 1;
my %complete_batches = ();
while( $count <= $loop_number + 1 ){ #the last loop will just report any sets that still look broken despite the attempt to restart them
    #get get the search_results
    my $empty_batches = 1; #if none of the query files need to be rerun, we'll stop the loop early. if need rerun, this sets to zero below
    foreach my $query_seq_file( @query_files ){
	next if( $complete_batches{$query_seq_file} );
	print "$query_seq_file\n";
	my $task_count = 0;
	my $split_array = '';
	next if( $query_seq_file =~ m/^\./  ); # skip the '.' and '..' and other dot files
	if( $query_seq_file =~ m/\.tmp\d*$/ ){ #if we have an old rapsearch run that we're reprocessing, we can't process the *.tmp files!
	    next; #this is safer than unlink; what is user has strange file extention? let's just pass. can delete by hand if abs. necessary
	    #unlink( $query_seq_file );
	}
	print " $query_seq_file\n";
        #need to set naming conventions for qsub script. These are same conventions used in run_remote_search_handler.pl
	my $result_file_prefix = get_prefix( $query_seq_file, $db_name );
	my $result_file_suffix = get_suffix( $algo );

	my $split_sub_result_dir = File::Spec->catdir($result_dir, $query_seq_file);
	print "$split_sub_result_dir\n";
	if( ! -d $split_sub_result_dir ){
	    warn( "I could not find the following search result directory: ${split_sub_result_dir}\n" );
	    next;
	}
	for( my $i=1; $i<=$nsplits; $i++ ){
	    #does the output file exist? This may not be a pefect check for crashed jobs! Future search algs may break this logic
	    my $has_match = 0;
	    my @split_res_files = glob( "${split_sub_result_dir}/${query_seq_file}-${db_name}_${i}.*.mysqld" ); #we have to glob because rapsearch
	    for my $file( @split_res_files ){
		next if( $file !~ m/\.mysqld$/ );
		if( -e $file && !( -z $file ) ){ #if the file is empty, try again in case perl created file handle before job crash
		    $has_match = 1;
		}
	    }
	    next if $has_match;
	    #if not, add the split to the list of array jobs to run
	    if( !$has_match ){
		if( $count == $loop_number + 1 ){
		    print "Despite $loop_number tries, I can't generate results for ${split_sub_result_dir}/${query_seq_file}-${db_name}_${i}.tab\n";
		}
		print "Looks like we need to retry ${query_seq_file} against database split ${i}...\n";
		$split_array .= "${i},";
		$task_count++;
		$empty_batches = 0;
	    }
	}	
#	next if( $task_count == 0 || $count == $loop_number + 1 ); #there were no failed jobs, it seems... or we're past the number of requested loops	
	if( $task_count == 0 ){
	    $complete_batches{$query_seq_file} = 1; #no jobs were run for this query seq file, so don't process it in future loops
	    next;
	}
	my $sub_array_string = "1-${task_count}";
	$split_array         =~ s/\,$//;
	#submit the jobs!
	print "-"x60 . "\n";
	print " RUN REMOTE PARSE RESULTS HANDLER.PL arguments for <$query_seq_file>\n";
	print "          LOOP NUMBER: $count\n";
	print "          SCRIPT PATH: $scriptpath\n";
	print "        QUERY SEQ DIR: $query_seq_dir\n";
	print "       QUERY SEQ FILE: $query_seq_file\n";
	print "      RESULT FILE DIR: $split_sub_result_dir\n";
	print "   RESULT FILE PREFIX: $result_file_prefix\n";
	print "   RESULT FILE SUFFIX: $result_file_suffix\n";
	print "            SAMPLE_ID: $sample_id\n";
#	print "    CLASSIFICATION_ID: $classification_id\n";
	print "     SEARCH ALGORITHM: $algo\n";
	print "   TRANSLATION METHOD: $trans_method\n";
	print "    THRESHOLD: EVALUE: $t_evalue\n";
	print "  THRESHOLD: COVERAGE: $t_coverage\n";
	print "     THRESHOLD: SCORE: $t_score\n";
	print "           PROJECTDIR: $proj_dir\n";
	print "           SCRIPTSDIR: $scripts_dir\n";
	print "           DELETE_RAW: $delete_raw_switch\n";
	print "         ARRAY STRING: $sub_array_string\n";
	print "-"x60 . "\n";
	my $results = run_remote_parse( $scriptpath,            $query_seq_dir,       $query_seq_file, 
					$split_sub_result_dir,  $result_file_prefix,  $result_file_suffix,
					$sample_id,             $algo,                $trans_method,
					$t_evalue, $t_coverage, $t_score, $proj_dir,  $scripts_dir,  $delete_raw_switch,
					$sub_array_string,      $split_array);
	
	if ($results =~ m/^Your job-array (\d+)\./) { #an array job
	    my $job_id = $1;
	    $jobs{$job_id}++;
	} #Your job 8119214 ("run_rapsearch.sh") has been submitted 
	elsif ($results =~ m/^Your job (\d+) /) { #not an array job
	    my $job_id = $1;
	    $jobs{$job_id}++;
	} 
	else {
	    die "Remote server did not return a properly formatted job id when running run_parse_search_results.sh on (remote) localhost. Got $results instead!";
	}
    }
    last if $empty_batches; #no jobs were run, so stop the while loop
    #At this point, we have a lot ofjobs in the queue. Let's monitor the queue and report back to local when jobs are complete 
    #this is a loop specific listener
    my @job_ids = keys(%jobs);
    if( scalar( @job_ids ) < 1 || $count == $loop_number + 1 ){
	print "It looks like all query-db pairs have output files, so I think I'm done with the cluster for this sample for now.\n";
	last;
    }
    my $time = remote_job_listener(\@job_ids, $waitTimeInSeconds);
    $count++;
}


###############
# SUBROUTINES #
###############

sub run_remote_parse {
    my ($scriptpath,  $query_seq_dir,      $query_seq_file, 
	$result_dir,  $result_file_prefix, $result_file_suffix,
	$sample_id,   $algo,               $trans_method,
	$t_evalue,    $t_coverage,         $t_score, $proj_dir, 
	$scripts_dir, $delete_raw_switch,  $array_string,       $split_array)            = @_;

    warn "Processing <$query_seq_file>. Running with array jobs...";

    #note that t_evalue, t_coverage, and t_score CAN be NULL, but not undefined - it'll break bash
    check_var( $scriptpath, "Script path" );
    check_var( $query_seq_dir, "Query seq dir" );
    check_var( $query_seq_file, "Query seq file" );
    check_var( $result_dir, "Result dir" );
    check_var( $result_file_prefix, "Result file prefix" );
    check_var( $result_file_suffix, "Result file suffix" );
    check_var( $sample_id, "Sample id" );
    check_var( $algo, "Algo" );
    check_var( $trans_method, "Trans method");
    check_var( $proj_dir, "Project directory" );
    check_var( $scripts_dir, "Scripts directory" );
    check_var( $t_evalue, "Evalue" );
    check_var( $t_coverage, "Coverage" );
    check_var( $t_score, "Score" );

    (defined($array_string)) or warn "You haven't specified an array string to use - I assume you don't want an array job?";

    my $out_stem = "${query_seq_file}-${db_name}"; # <-- this really better not have any whitespace in it!!!

    if( !defined($split_array ) ){
	$split_array = '';
    }

    # Arg names as seen in "run_last.sh", below in all-caps:
    #                          INPATH         INPUT           DBPATH     OUTPATH     OUTSTEM
    my $array_opt = "-t ${array_string}";
    my @args = ( $array_opt, $scriptpath,  $query_seq_dir, $query_seq_file, 
		 $result_dir,  $result_file_prefix,        $result_file_suffix,
		 $sample_id,   $algo,         $trans_method,
		 $t_evalue,    $t_coverage,    $t_score,    $proj_dir, 
		 $scripts_dir, $delete_raw_switch, $split_array);     

    warn("We will attempt to execute the following job:\n qsub @args");

    (-d $query_seq_dir) or die "Query seq dir $query_seq_dir did not already exist on the REMOTE CLUSTER machine! It must be a DIRECTORY that already exists.";
    (-d $result_dir)    or die "Result dir $result_dir did not already exist on the REMOTE CLUSTER machine! It must be a DIRECTORY that already exists.";
    (-f "${query_seq_dir}/${query_seq_file}") or die "Query seq file in ${query_seq_dir}/${query_seq_file} did not already exist on the REMOTE CLUSTER machine!";
    (-f $scriptpath) or die "Script $scriptpath did not already exist on the REMOTE CLUSTER machine! It must already exist.";

    my $results = capture("qsub @args");
    (0 == $EXITVAL) or die "Error running the script: $results ";
    return $results;
}

sub check_var{
    my( $var, $desc ) = @_;
    (defined($var) && (length($var) > 0)) or die "${desc} (${var}) was undefined or zero-len!";
}

sub remote_job_listener{
    my ($jobs, $waitTimeInSeconds) = @_;
    my $numwaits = 0;
    my %status   = ();
    while (1){
        last if(scalar(keys(%status)) == scalar(@{$jobs}) );         #stop checking if every job has a finished status
        my $results = execute_qstat();         #call qstat and grab the output
        foreach my $jobid( @{ $jobs } ){         #see if any of the jobs are complete. pass on those we've already finished
            next if( exists( $status{$jobid} ) );
            if( $results !~ m/$jobid/ ){
                $status{$jobid}++;
            }
        }
        sleep($waitTimeInSeconds);
        $numwaits++
    }
    my $time = $numwaits * $waitTimeInSeconds;
    return $time;
}

sub execute_qstat{
    my ($cmd) = @_;
    my $results = capture( "qstat" );
    (0 == $EXITVAL) or die "Error running execute_qstat: $results ";
    return $results;
}

sub check_and_make_path{
    my($path, $should_force) = @_;
    if (not -d $path) {
        warn("Directory did not already exist, so creating a directory at $path\n");
	make_path($path) || die "can't make_path: $!";
    } else {
	# directory ALREADY EXISTS if we are here
	if (defined($should_force) && $should_force) {
	    warn( "<$path> already existed, so we are REMOVING it first!\n");
	    rmtree( $path ) || die "can't rmtree:$!";
	    warn( "...creating $path\n" );
	    make_path( $path ) || die "can't make_path: $!";
	} else {
	    # if the file exists but there's NO forcing
	    die( "Directory exists at $path, will not overwrite without the 'force' argument being set to 1! " );
	}
    }
}

sub get_prefix{
    my( $query_seq_file, $db_name ) = @_;
    my $prefix = "${query_seq_file}-${db_name}"; #trailing underscore is added in qsub script
    return $prefix;
}

sub get_suffix{
    my ( $algo ) = @_;
    my $suffix = ".tab"; #includes the period
    if( $algo eq "rapsearch" ){ #rapsearch has two file output types, we only want m8 extension
	$suffix .= ".m8"; 
    }
    return $suffix;
}
