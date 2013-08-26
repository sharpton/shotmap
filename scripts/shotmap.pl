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

## ================================================================================
## ================================================================================
## FAQ for problems encountered while running mrc_handler.pl:
##
## 1) To solve: 'Can't locate MRC.pm in @INC ...'
## IF YOU GET AN ERROR about MRC or Sfams::Schema not being find-able,
## THEN YOU MAY BE ABLE TO FIX THIS BY TYPING:
##         export MRC_LOCAL=/your/location/of/MRC           <-- replace that path with the actual one
## For example, if MRC is in your home directory, you would type:
##         export MRC_LOCAL=~/MRC
## Please note: do not use spaces around the EQUALS SIGN (=), or it won't work!
##
## ================================================================================
## ================================================================================

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
use MRC;
use MRC::DB;
use MRC::Run;
use Getopt::Long qw(GetOptionsFromString);
use Data::Dumper;
use Bio::SeqIO;
use File::Basename;
use File::Spec;

use Benchmark;
use Carp;
$SIG{ __DIE__ } = sub { Carp::confess( @_ ) }; # prints a STACK TRACE whenever there is a fatal error! Very handy

print STDERR ">> ARGUMENTS TO mrc_handler.pl: perl mrc_handler.pl @ARGV\n";

my $wf = Shotmap->new();
$wf->Shotmap::Notify::check_env_var( $ENV{'MRC_LOCAL'} );
$wf->Shotmap::Load::get_options( @ARGV );
$wf->Shotmap::Load::check_vars();
$wf->Shotmap::Load::set_params();

print Dumper $wf;

die;

#printBanner("Starting classification run, processing $project_dir\n");

#add these to the get_options routine above
my $check     = 0;
my $is_strict = 1; #strict (single classification per read, e.g. top hit) v. fuzzy (all hits passing thresholds) clustering. 1 = strict. 0 = fuzzy. Fuzzy not yet implemented!

my $path_to_family_annotations;
my $abundance_type = "coverage";
my $normalization_type = "target_length";


#where does this belong?    
#    if( $should_split_orfs ){
#	$trans_method = $trans_method . "_split";
 #   }

