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
use Benchmark;
use Carp;

$SIG{ __DIE__ } = sub { Carp::confess( @_ ) }; # prints a STACK TRACE whenever there is a fatal error! Very handy

my $pipe = Shotmap->new();
$pipe->Shotmap::Notify::check_env_var( $ENV{'SHOTMAP_LOCAL'} );
$pipe->Shotmap::Load::get_options( @ARGV );
$pipe->Shotmap::Load::check_vars();
$pipe->Shotmap::Load::set_params();

#only ever run on a project that has been processed to at least some extent, so backload
$pipe->Shotmap::Run::back_load_project($pipe->project_id);
$pipe->Shotmap::Run::back_load_samples();

#Now specify the sample path level directories that we want to delete
$pipe->Shotmap::DB::delete_sample_subpath( $pipe->project_id, "/unsplit_orfs/" );
$pipe->Shotmap::DB::delete_sample_subpath( $pipe->project_id, "/orfs/" );
