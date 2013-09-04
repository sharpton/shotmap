#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use IPC::System::Simple qw(capture $EXITVAL);

my( $indir, $outdir, $waittime, $unsplit_orfs_dir, $logsdir );
my $remote_scripts_path = undef; #"/netapp/home/sharpton/projects/MRC/scripts/";
my $array = 1;
my $filter_length = 0; #what is the minimum orf length that we should keep. used in split_orfs_on_stop, inclusive (default is no length filtering)

GetOptions(
    "i=s" => \$indir,
    "o=s" => \$outdir,
    "w=i" => \$waittime,
    "s=s" => \$remote_scripts_path,
    "u=s" => \$unsplit_orfs_dir, #if defined, we will split translated reads on stop. put unsplit data here.
    "l=s" => \$logsdir,
    "f=i" => \$filter_length,
);

defined($remote_scripts_path) or die "remote scripts path must be defined!";

my $split_outdir;
my $should_split_orfs   = (defined($unsplit_orfs_dir) && $unsplit_orfs_dir) ? 1 : 0; # Set this to 1 ("true") if the unsplit_orfs_dir was specified

#reset some vars to integrate orf splitting into the code below
if ($should_split_orfs){
    $split_outdir = $outdir; # set this to the OLD outdir
    $outdir = $unsplit_orfs_dir; # and I guess change outdir to the un-split orfs dir... confusing.
}

print STDERR "run_transeq_handler.pl: Working on remote server...\n";

opendir( IN, $indir ) || die "Can't opendir $indir for read: $!";
my @infiles = readdir(IN);
closedir( IN );

my %jobs = ();  #create a jobid storage log (hash)
my ($inbasename, $outbasename); #grab the files that we want to translate
my $array_length = 0;

if (scalar(@infiles) == 2) { warn("There is probably a serious problem here; it appears that we did not have any valid input files! Better double-check that input directory: $indir\nProbably something broke EARLIER in the process, leading that directory to be empty!"); }
warn("We got a total of " . (scalar(@infiles)-2) . " probably-legitimate candidate input files from the input directory <$indir> to check through."); # minus 2 is because we don't want to count '.' and '..'

foreach my $file( @infiles ){
    next if ($file =~ m/^\./ ); # Skip any files starting with a dot, including the special ones: "." and ".."
    warn "Checking through the input files, specifically, the file <$file>...";
    if ($array) { #need to know how many array jobs to launch
	$array_length++; 
	#only need to process the single file, because the array jobs do the rest of the work.
	if(!defined($inbasename)) { #let's set some vars, but we won't process until we've looped over the entire directory
	    ($file =~ m/(.*)split\_*/) or die "Can't grab the new basename from the file <$file>!";
	    $inbasename  = $1 . "split_"; # Set the input basename! Note that "$1" is the pattern-matched thing in the regex above (before the literal text "split")
	    $outbasename = $inbasename;
	    $outbasename =~ s/\_raw\_/\_orf\_/; # change "/raw/" to "/orf/"
	}
    } else{
	my $outfile = $file; 	#need to change the basename for the output file
	$outfile =~ s/\_raw\_/\_orf\_/; ## change "/raw/" to "/orf/"
	
	my $split_output_setting = ($should_split_orfs) ? "$split_outdir/$outfile" : undef;
	my $results = run_transeq("$indir/$file", "$outdir/$outfile", $remote_scripts_path, $logsdir, $split_output_setting);
	
	($results =~ m/^Your job (\d+) /) or die("Remote server did not return a properly formatted job id when running transeq on (remote) localhost. Got $results instead!. Quitting!");
	my $job_id = $1; # this is the numeric id from the regex above
	$jobs{$job_id} = $file;
    }
}

# Now, if $array is set, we run the array job.
if ($array) {
    my $split_outdir_setting = ($should_split_orfs) ? "$split_outdir" : undef;
    my $results = run_transeq_array( $indir, $inbasename, $outdir, $outbasename, $array_length, $remote_scripts_path, $logsdir,  $filter_length, $split_outdir_setting );
    #6971202.1-4:1
    #Your job-array 6971206.1-4:1 ("run_transeq_array.sh") has been submitted
    ($results =~ m/^Your job-array (\d+)\./) or die("Remote server did not return a properly formatted job id when running transeq on (remote) localhost. Got $results instead!. Quitting! Note that we require this EXACT text, so maybe they changed the format? But probably not.");
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
sub run_transeq_array {
    my( $indir, $inbasename, $outdir, $outbasename, $array_length, $remote_scripts_path, $logsdir, $filter_length, $split_outdir ) = @_;
    defined($indir)      or die "missing indir!";    
    defined($inbasename) or die "missing inbasename!";   
    defined($outdir)     or die "missing outdir!";    
    defined($outbasename) or die "missing outbasename!";
    defined($array_length) or die "missing array_length!";
    defined($remote_scripts_path) or die "missing remote_scripts_path!";
    defined($logsdir)             or die "missing logsdir!";
    defined($filter_length)       or die "missing filter_length!";
    # The final variable, $split_outdir, is OPTIONAL and does not need to be defined
    ($array_length >= 1) or die "qsub requires that the second array length parameter CANNOT be less than the first one. However, in our case, the array length is: $array_length (which is less than 1!).";
    my $script = "$remote_scripts_path/run_transeq_array.sh";
    my $qsubArrayJobArgument = " -t '1-${array_length}' ";
    my @args = ($qsubArrayJobArgument, $script, $indir, $inbasename, $outdir, $outbasename, $remote_scripts_path, $logsdir);
    if (defined($split_outdir) ) { push(@args, $split_outdir); } ## add $split_outdir to the argument list, if it was specified
    if (defined($filter_length) && defined( $split_outdir ) ) { push(@args, $filter_length); } ## add it to the argument list, if it was specified
    warn("run_transeq_handler.pl: (run_transeq_array): About to execute this command: qsub @args");
    my $results = IPC::System::Simple::capture("qsub " . "@args");
    ($EXITVAL == 0 ) or die("Error in run_transeq_array (running transeq array) on remote server: $results ");
    return $results;
}

sub run_transeq {
    my ($input, $output, $remote_scripts_path, $logsdir, $filter_length, $split_outdir) = @_;
    my $script = "$remote_scripts_path/run_transeq.sh";
    my @args = ($script, $input, $output, $logsdir);
    if (defined($split_outdir)) { push(@args, $split_outdir); } ## add it to the argument list, if it was specified
    if (defined($filter_length) && defined($split_outdir)) { push(@args, $filter_length); } ## add it to the argument list, if it was specified
    warn("run_transeq_handler.pl: (run_transeq): About to execute this command: qsub @args");
    my $results = IPC::System::Simple::capture("qsub " . "@args");
    if($EXITVAL != 0) { die( "Error running transeq (run_transeq) on remote server: $results "); }
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
