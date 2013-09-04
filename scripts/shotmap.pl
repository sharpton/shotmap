#!/usr/bin/perl -w

#mrc_handler.pl - The control script responsible for executing an MRC run.
#Usage: 
#perl mrc_handler.pl -u <username> -p <password> -d <path_to_flat_file_db> -s <path_to_mrc_scripts_directory> -i <path_to_metagenome_data> -h <hmm_database_name> > <path_to_out_log> 2> <path_to_error_log>
#
#Example Usage:
#nohup perl mrc_handler.pl -u username -p password -d /bueno_not_backed_up/sharpton/MRC_ffdb -s ./ -i ../data/randsamp_subset_perfect_2 -h OPFs_all_v1.0 > randsamp_perfect_2.all.out 2> randsamp_perfect_2.all.err &

## examples:
# perl ./MRC/scripts/mrc_handler.pl --dbuser=alexgw --dbpass=$PASS --dbhost=lighthouse.ucsf.edu --rhost=chef.compbio.ucsf.edu --ruser=alexgw --ffdb=/home/alexgw/MRC_ffdb --refdb=/home/alexgw/sifting_families  --projdir=./MRC/data/randsamp_subset_perfect_2/ 

# perl ./MRC/scripts/mrc_handler.pl --dbuser=alexgw --dbpass=$PASS --dbhost=lighthouse.ucsf.edu --rhost=chef.compbio.ucsf.edu --ruser=alexgw --ffdb=/home/alexgw/MRC_ffdb --refdb=/home/alexgw/sifting_families  --projdir=./MRC/data/randsamp_subset_perfect_2/ --dryrun
# perl ./MRC/scripts/mrc_handler.pl --dbuser=alexgw --dbpass=$PASS --dbhost=lighthouse.ucsf.edu --rhost=chef.compbio.ucsf.edu --ruser=alexgw --rdir=/scrapp2/alexgw/MRC --ffdb=/home/alexgw/MRC_ffdb --refdb=/home/alexgw/sifting_families --projdir=./MRC/data/randsamp_subset_perfect_2/

# Note that Perl "use" takes effect at compile time!!!!!!!! So you can't put any control logic to detect whether the ENV{'MRC_LOCAL'}
# exists --- that logic will happen AFTER 'use' has already been invoked. From here: http://perldoc.perl.org/functions/use.html
# Added by Alex Williams, Feb 2013.
use lib ($ENV{'MRC_LOCAL'} . "/scripts"); ## Allows "MRC.pm" to be found in the MRC_LOCAL directory
use lib ($ENV{'MRC_LOCAL'} . "/lib"); ## Allows "Schema.pm" to be found in the MRC_LOCAL directory. DB.pm needs this.
## Note: you may want to set MRC_LOCAL with the following commands in your shell:
##       export MRC_LOCAL=/home/yourname/MRC          (assumes your MRC directory is in your home directory!)
##       You can also add that line to your ~/.bashrc so that you don't have ot set MRC_LOCAL every single time!
#use if ($ENV{'MRC_LOCAL'}), "MRC";

use strict;
use warnings;
use Shotmap;
use Shotmap::Load;
use Shotmap::Notify;
use Shotmap::Reads;
use Shotmap::Orfs;
use Shotmap::Search;
use Shotmap::Results;
use Getopt::Long qw(GetOptionsFromString);
use Data::Dumper;
use Bio::SeqIO;
use File::Basename;
use File::Spec;

use Benchmark;
use Carp;
$SIG{ __DIE__ } = sub { Carp::confess( @_ ) }; # prints a STACK TRACE whenever there is a fatal error! Very handy

print STDERR ">> ARGUMENTS TO mrc_handler.pl: perl mrc_handler.pl @ARGV\n";

# Initialize a new pipeline
my $pipe = Shotmap->new();
$pipe->Shotmap::Notify::printBanner( "Initializing the shotmap Pipeline" );
$pipe->Shotmap::Notify::check_env_var( $ENV{'MRC_LOCAL'} );
$pipe->Shotmap::Load::get_options( @ARGV );
$pipe->Shotmap::Load::check_vars();
$pipe->Shotmap::Load::set_params();
$pipe->Shotmap::Notify::pipeline_params();

#add these to the get_options routine above
my $is_strict = 1; #strict (single classification per read, e.g. top hit) v. fuzzy (all hits passing thresholds) clustering. 1 = strict. 0 = fuzzy. Fuzzy not yet implemented!

my $path_to_family_annotations;
my $abundance_type = "coverage";
my $normalization_type = "target_length";

# What step of the pipeline are we running?
## If the user has specified something in the --goto option, then we skip some parts of the analysis and go directly
## to the "skip to this part" part.
## Note that this is only useful if we have a process ID! 
## block tries to jump to a module in handler for project that has already done some work
if (defined($pipe->opts->{"goto"}) && $pipe->opts->{"goto"}) {
    (defined($pipe->project_id) && $pipe->project_id) or die "You CANNOT specify --goto without also specifying an input PID (--pid=NUMBER).\n";
    if (!$pipe->dryrun) {
	$pipe->Shotmap::Run::back_load_project($pipe->project_id);
	#$analysis->MRC::Run::get_part_samples($project_dir);
	$pipe->Shotmap::Run::back_load_samples();
    } else {
	$pipe->Shotmap::Notify::dryNotify("Skipped loading samples.");
    }
    my $goto = $pipe->opts->{"goto"};
    $goto = uc($goto); ## upper case it
    if ($goto eq "T" or $goto eq "TRANSLATE"){    warn "Skipping to TRANSLATE READS step!\n";            goto TRANSLATE; }
    if ($goto eq "O" or $goto eq "LOADORFS" ){    warn "Skipping to orf loading step!\n";                goto LOADORFS; }
    if ($goto eq "B" or $goto eq "BUILD")   {     warn "Skipping to searchdb building step!\n";          goto BUILDSEARCHDB; }
    if ($goto eq "R" or $goto eq "REMOTE")  {     warn "Skipping to staging remote server step!\n";      goto REMOTESTAGE; }
    if ($goto eq "S" or $goto eq "SCRIPT")  {     warn "Skipping to building hmmscan script step!\n";    goto BUILDSEARCHSCRIPT; }
    if ($goto eq "X" or $goto eq "SEARCH")  {     warn "Skipping to hmmscan step!\n";                    goto EXECUTESEARCH; }
    if ($goto eq "P" or $goto eq "PARSE")   {     warn "Skipping to get remote hmmscan results step!\n"; goto PARSERESULTS; }
    if ($goto eq "G" or $goto eq "GET")     {     warn "Skipping to get remote hmmscan results step!\n"; goto GETRESULTS; }
    if ($goto eq "L" or $goto eq "LOADRESULTS"){  warn "Skipping to get remote hmmscan results step!\n"; goto LOADRESULTS; }
    if ($goto eq "C" or $goto eq "CLASSIFY"){     warn "Skipping to classifying reads step!\n";          goto CLASSIFYREADS; }
    if ($goto eq "D" or $goto eq "DIVERSITY")  {  warn "Skipping to producing output step!\n";           goto CALCDIVERSITY; }
    die "QUITTING DUE TO INVALID --goto OPTION: (specifically, the option was \"$goto\"). If we got to here in the code, it means there was an INVALID FLAG PASSED TO THE GOTO OPTION.";
}

# Load the project
$pipe->Shotmap::Reads::load_project();
# Find orfs
 TRANSLATE: $pipe->Shotmap::Orfs::translate_reads();
# Load orfs into DB
 LOADORFS: $pipe->Shotmap::Orfs::load_orfs();
# Build search database and load into DB
 BUILDSEARCHDB: $pipe->Shotmap::Search::build_search_db();
# Stage search database on remote server
 REMOTESTAGE: $pipe->Shotmap::Search::stage_search_db();
# Build search script
 BUILDSEARCHSCRIPT: $pipe->Shotmap::Search::build_search_script();
# Execute search
 EXECUTESEARCH: $pipe->Shotmap::Search::run_search();
# Parse search results
 PARSERESULTS: $pipe->Shotmap::Results::parse_results();
# Get search results from remote server
 GETRESULTS: $pipe->Shotmap::Results::grab_results();
# Load results into DB
 LOADRESULTS: $pipe->Shotmap::Results::load_results();
# Classify reads into families
 CLASSIFYREADS: $pipe->Shotmap::Results::classify_reads();
# Calculate diversity
 CALCDIVERSITY: $pipe->Shotmap::Results::calculate_diversity();
