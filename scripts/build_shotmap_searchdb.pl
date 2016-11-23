#!/usr/bin/perl -w

use lib ($ENV{'SHOTMAP_LOCAL'} . "/scripts"); ## Allows shotmap scripts to be found in the SHOTMAP_LOCAL directory
use lib ($ENV{'SHOTMAP_LOCAL'} . "/lib"); ## Allows "Shotmap.pm and Schema.pm" to be found in the SHOTMAP_LOCAL directory. DB.pm needs this.
use lib ($ENV{'SHOTMAP_LOCAL'} . "/ext/lib/perl5");     

## Note: you may want to set SHOTMAP_LOCAL with the following commands in your shell:
##       export SHOTMAP_LOCAL=/home/yourname/shotmap          (assumes your SHOTMAP directory is in your home directory, change accordingly
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

use Benchmark;
use Carp;

$SIG{ __DIE__ } = sub { Carp::confess( @_ ) }; # prints a STACK TRACE whenever there is a fatal error! Very handy

#update $PATH to place shotmap installed binaries at the front. This can be turned off or amended per user needs
local $ENV{'PATH'} = $ENV{'SHOTMAP_LOCAL'} . "/bin/" . ":" . $ENV{'PATH'};

print STDERR ">> ARGUMENTS TO build_shotmap_searchdb.pl: perl build_shotmap_searchdb.pl @ARGV\n";

# Initialize a new pipeline
my $pipe = Shotmap->new();
$pipe->is_iso_db(1);
$pipe->Shotmap::Notify::check_env_var( $ENV{'SHOTMAP_LOCAL'} );
$pipe->Shotmap::Load::get_options( @ARGV );
$pipe->Shotmap::Load::check_vars();
$pipe->Shotmap::Load::set_params();
#$pipe->Shotmap::Notify::pipeline_params();

my $path_to_family_annotations;
#having the item below set to on is dangerous unless you know what you are doing
#$pipe->force_build_search_db(1);
#instead, just set to build, tell user if conflict exists
$pipe->build_search_db( $pipe->search_type, 1 );
# Build search database and load into DB
$pipe->Shotmap::Search::build_search_db();
$pipe->Shotmap::Search::set_search_db_n_splits();
$pipe->Shotmap::Search::format_search_db();
