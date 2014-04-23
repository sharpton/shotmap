#!/usr/bin/perl -w

use lib ($ENV{'SHOTMAP_LOCAL'} . "/scripts"); ## Allows shotmap scripts to be found in the SHOTMAP_LOCAL directory
use lib ($ENV{'SHOTMAP_LOCAL'} . "/lib"); ## Allows "Shotmap.pm and Schema.pm" to be found in the SHOTMAP_LOCAL directory. DB.pm needs this.
## Note: you may want to set SHOTMAP_LOCAL with the following commands in your shell:
##       export SHOTMAP_LOCAL=/home/yourname/shotmap          (assumes your SHOTMAP directory is in your home directory!)
##       You can also add that line to your ~/.bashrc so that you don't have ot set SHOTMAP_LOCAL every single time!

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

print STDERR ">> ARGUMENTS TO shotmap.pl: perl shotmap.pl @ARGV\n";

# Initialize a new pipeline
my $pipe = Shotmap->new();
$pipe->Shotmap::Notify::printBanner( "Initializing the shotmap pipeline" );
$pipe->Shotmap::Notify::check_env_var( $ENV{'SHOTMAP_LOCAL'} );
$pipe->Shotmap::Load::get_options( @ARGV );
$pipe->Shotmap::Load::check_vars();
$pipe->Shotmap::Load::set_params();
$pipe->Shotmap::Notify::pipeline_params();

my $path_to_family_annotations;

# What step of the pipeline are we running?
## If the user has specified something in the --goto option, then we skip some parts of the analysis and go directly
## to the "skip to this part" part.
## Note that this is only useful if we have a process ID! 
## block tries to jump to a module in handler for project that has already done some work
if (defined($pipe->opts->{"goto"}) && $pipe->opts->{"goto"}) {
    (defined($pipe->project_id) && $pipe->project_id) or die "You CANNOT specify --goto without also specifying an input PID (--pid=NUMBER).\n";
    if (!$pipe->dryrun) {
	$pipe->Shotmap::Run::back_load_project($pipe->project_id);
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
if( $pipe->remote ){ 
 REMOTESTAGE: $pipe->Shotmap::Search::stage_search_db(); 
} else { 
 LOCALSTAGE: $pipe->Shotmap::Search::format_search_db();
}
# Build search script
 BUILDSEARCHSCRIPT: $pipe->Shotmap::Search::build_search_script();
# Execute search
 EXECUTESEARCH: $pipe->Shotmap::Search::run_search();
# Parse search results
 PARSERESULTS: $pipe->Shotmap::Results::parse_results();
# Get search results from remote server
if( $pipe->remote ){
 GETRESULTS: $pipe->Shotmap::Results::grab_results();
}
die;
# Load results into DB
 LOADRESULTS: $pipe->Shotmap::Results::load_results();
# Classify reads into families
 CLASSIFYREADS: $pipe->Shotmap::Results::classify_reads();
# Calculate diversity
 CALCDIVERSITY: $pipe->Shotmap::Results::calculate_diversity();
$pipe->Shotmap::Notify::printBanner("ANALYSIS COMPLETED!");
