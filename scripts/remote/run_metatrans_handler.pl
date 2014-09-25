#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use IPC::System::Simple qw(capture $EXITVAL);

my( $indir, $outdir, $waittime, $logsdir, $method );
my $remote_scripts_path = undef; 
my $array = 1;
my $filter_length = 0; #what is the minimum orf length that we should keep. used in split_orfs_on_stop, inclusive (default is no length filtering)
my $verbose = 0;

GetOptions(
    "i=s" => \$indir,
    "o=s" => \$outdir,
    "w=i" => \$waittime,
    "s=s" => \$remote_scripts_path,
    "l=s" => \$logsdir,
    "f=i" => \$filter_length,
    "m=s" => \$method,
    "v!"  => \$verbose,
);

defined($remote_scripts_path) or die "remote scripts path must be defined!\n";
defined($method) or die "An translation method must be defined with -m!\n";

print STDERR "run_metatrans_handler.pl: Working on remote server...\n";

opendir( IN, $indir ) || die "Can't opendir $indir for read: $!";
my @infiles = readdir(IN);
closedir( IN );

my %jobs = ();  #create a jobid storage log (hash)
my ($inbasename, $outbasename); #grab the files that we want to translate
my $array_length = 0;

if (scalar(@infiles) == 2) { 
    die("There is probably a serious problem here; it appears that we did not have any " .
	 "valid input files! Better double-check that input directory: $indir\n" . 
	 "Probably something broke EARLIER in the process, leading that directory to be empty!"); 
}

if( $verbose ){
    warn("We got a total of " . (scalar(@infiles)-2) . # minus 2 is because we don't want to count '.' and '..'
	 " probably-legitimate candidate input files from the input directory <$indir> to check through."); 
}

foreach my $file( @infiles ){
    next if ($file =~ m/^\./ ); # Skip any files starting with a dot, including the special ones: "." and ".."
    if( $verbose ){
	warn "Checking through the input files, specifically, the file <$file>...";
    }
    if ($array) { #need to know how many array jobs to launch
	$array_length++; 
	#only need to process the single file, because the array jobs do the rest of the work.
	if(!defined($inbasename)) { #let's set some vars, but we won't process until we've looped over the entire directory
	    ($file =~ m/(.*)split\_*/) or die "Can't grab the new basename from the file <$file>!";
	    # Set the input basename! Note that "$1" is the pattern-matched thing in the regex above (before the literal text "split")
	    $inbasename  = $1 . "split_"; 
	    $outbasename = $inbasename;
	    $outbasename =~ s/\_raw\_/\_orf\_/; # change "/raw/" to "/orf/"
	}
    } else{
	my $outfile = $file; 	#need to change the basename for the output file
	$outfile =~ s/\_raw\_/\_orf\_/; ## change "/raw/" to "/orf/"
	
	my $results = run_metatrans( $method, $indir, $file, $outdir, $outfile, 0, $remote_scripts_path, $logsdir );
	
	($results =~ m/^Your job (\d+) /) 
	    or die("Remote server did not return a properly formatted job id when running transeq on " . 
		   "(remote) localhost. Got $results instead!. Quitting!");
	my $job_id = $1; # this is the numeric id from the regex above
	$jobs{$job_id} = $file;
    }
}

# Now, if $array is set, we run the array job.
if ($array) {
    my $results = run_metatrans( $method, $indir, $inbasename, $outdir, $outbasename, $array_length, $remote_scripts_path, $logsdir );
    #6971202.1-4:1
    #Your job-array 6971206.1-4:1 ("run_transeq_array.sh") has been submitted
    ($results =~ m/^Your job-array (\d+)\./) 
	or die("Remote server did not return a properly formatted job id when running transeq on " . 
	       "(remote) localhost. Got $results instead!. Quitting! Note that we require this EXACT " . 
	       "text, so maybe they changed the format? But probably not.");
    my $job_id = $1; # capture the numeric part from the regex above
    $jobs{$job_id}++;
}

#At this point, we have a lot ofjobs in the queue. Let's monitor the queue and report back to local when jobs are complete 
my @job_ids = keys(%jobs);
my $time    = remote_job_listener(\@job_ids, $waittime);

print STDERR "Looks like run_transeq_handler.pl finished successfully!\n";


###############
# SUBROUTINES #
###############
sub run_metatrans {   
    my( $method, $indir, $inbasename, $outdir, $outbasename, $array_length, $remote_scripts_path ) = @_;
    defined($method)     or die "missing method!";
    defined($indir)      or die "missing indir!";    
    defined($inbasename) or die "missing inbasename!";   
    defined($outdir)     or die "missing outdir!";    
    defined($outbasename) or die "missing outbasename!";
    defined($remote_scripts_path) or die "missing remote_scripts_path!";
    # The final variable, $split_outdir, is OPTIONAL and does not need to be defined

    my $array;
    if( $array_length < 1 ){
	$array = 0;
    } elsif( $array_length >= 1 ) {
	$array = 1;
    } else {
	die "Can't determine how to parse the array_length variable. Got $array_length\n";
    }
    my $script = "$remote_scripts_path/run_${method}.sh";
    my $qsubArrayJobArgument = "";
    if( $array ){
	$qsubArrayJobArgument = " -t '1-${array_length}' ";
    }
    my @args = ($qsubArrayJobArgument, $script, $indir, $inbasename, $outdir, $outbasename );    
    print("run_metatrans_handler.pl: (run_metatrans): About to execute this command: qsub @args");
    my $results = IPC::System::Simple::capture("qsub " . "@args");
    ($EXITVAL == 0 ) or die("Error in run_metatrans_array (running run_metatrans.sh) on remote server: $results ");
    return $results;
}

sub execute_qstat {
    # No arguments to this function
    my $results = IPC::System::Simple::capture("qstat");
    ($EXITVAL == 0) or die "Error running execute_cmd: $results";
    return $results;
}

sub remote_job_listener{
    my ($jobs, $waitTimeInSeconds) = @_;
    my %status   = ();
    my $startTimeInSeconds = time();
    ($waitTimeInSeconds >= 1) or die "Programming error: Wait time in seconds must be at least 1. Change it to 1 or more!";
    while (scalar(keys(%status)) != scalar(@{$jobs}) ) { # Keep checking until EVERY job has a finished status
        my $results = execute_qstat(); #call qstat and grab the output
        foreach my $jobid( @{ $jobs } ){ #see if any of the jobs are complete. pass on those we've already finished
            next if( exists( $status{$jobid} ) ); # skip... something.
            if ($results !~ m/$jobid/) { # if the results... do NOT include this job ID, then do this...
                $status{$jobid}++; # I am not sure if this is robust against jobs having the same SUB-string in them. Like "199" versus "1999"
            }
        }
        sleep($waitTimeInSeconds);
    }
    return (time() - $startTimeInSeconds); # return amount of wall-clock time this took
}
