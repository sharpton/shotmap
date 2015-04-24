#!/usr/bin/perl -w

#MRC.pm - The MRC workflow manager
#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gladstone.ucsf.edu
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program (see LICENSE.txt).  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

package Shotmap::Search;

use lib ($ENV{'SHOTMAP_LOCAL'} . "/ext/lib/perl5");     

use Shotmap;
use File::Basename;
use File::Copy;

sub build_search_db{
    my( $self ) = @_;
    my $search_type   = $self->search_type;
    my $search_method = $self->search_method;
    my $full_pipe     = $self->full_pipe; #is this a full pipeline run, or just a db build?
    #NOTE: These warning should NEVER be needed given the precautions we take in Load.pm (search method defines type of database to build!)
    #hmm
    if ($self->build_search_db("hmm")){
	if ( $search_method ne "hmmsearch" && $search_method ne "hmmscan" && $full_pipe ){
	    $self->Shotmap::Notify::warn("It seems that you want to build an hmm database, but you aren't invoking hmmscan or hmmsearch. " .
					 "While I will continue, you should check your settings to make certain you aren't making a mistake."
		);
	}
	$self->Shotmap::Notify::printBanner("BUILDING HMM DATABASE");
	$self->Shotmap::Run::build_search_db( $self->search_db_name( $search_type ), $self->force_build_search_db, $search_type );
    }
    #blast-like
    if ($self->build_search_db("blast")) {
	if ( $search_method ne "blast" && $search_method ne "last" && $search_method ne "rapsearch" && $full_pipe){
	    $self->Shotmap::Notify::warn("It seems that you want to build a sequence database, but you aren't invoking pairwise sequence search algorithgm. " .
					 "While I will continue, you should check your settings to make certain you aren't making a mistake. "
		);
	}
	$self->Shotmap::Notify::printBanner("BUILDING SEQUENCE DATABASE");
	$self->Shotmap::Run::build_search_db( $self->search_db_name( $search_type ), $self->force_build_search_db, $search_type, $self->reps, $self->nr );
    }
    
    #may not need to build the search database, but let's see if we need to load the database info into mysql....
    if( $self->use_db && $full_pipe ){
	$self->Shotmap::Notify::printBanner("LOADING FAMILY DATA"); #could run a check to see if this is necessary, the loadings could be sped up as well....

	if( ! $self->Shotmap::Run::check_family_loadings( $search_type, $self->db_name ) ){
	    $self->Shotmap::Run::load_families( $search_type, $self->db_name );
	}
	if( ! $self->Shotmap::Run::check_familymember_loadings( $search_type, $self->db_name ) ){
	    $self->Shotmap::Run::load_family_members( $search_type, $self->db_name );
	}    
	#still need to build this
	if( defined( $self->family_annotations ) ){ #points to file that contains annotations for families
	    if( ! -e $self->family_annotations ){
		die "The path to the family annotations that you specified does not seem to exist! You pointed me to <" . $self->family_annotations . ">\n";
	    } else {
		$self->Shotmap::DB::load_annotations( $self->family_annotations );
	    }
	}
    }
    if( $full_pipe ){
	#we always want to copy these searchdb prop files files to the params directory now
	$self->Shotmap::Run::cp_search_db_properties();
    }
    return $self;
}

#obsolete. we now embed the function Shotmap::Run::build_remote_script into Shotmap::Search::run_search
sub build_search_script{
    my( $self ) = @_;

    my $projID         = $self->project_id();
    my $is_remote      = $self->remote;
    my $local_ffdb     = $self->ffdb;
    my $localScriptDir = $self->local_scripts_dir();
    my $dbname         = $self->db_name;
    my $use_scratch    = $self->scratch;
    my $search_method  = $self->search_method;
    my $search_type    = $self->search_type;
    my $db_name        = $self->search_db_name($search_type);

    if ($is_remote) {
	my $project_path = $self->remote_project_path();
	$self->Shotmap::Notify::printBanner("BUILDING REMOTE $search_method SCRIPT");
	my $search_script       = "$local_ffdb/projects/$dbname/$projID/run_${search_method}.sh";
	$self->Shotmap::Notify::print_verbose( "Search script will be here: ${search_script}" );
	if( $search_type eq "hmm" ){
	    my $n_hmm_searches = $self->Shotmap::DB::get_number_hmmdb_scans( $self->search_db_split_size($search_type) );
	    my $nsplits        = $self->Shotmap::DB::get_number_db_splits( $search_type ); #do we still need this?
	    $self->Shotmap::Notify::print( "Total number HMMs: $n_hmm_searches\n" );
	    $self->Shotmap::Notify::print( "Number of search database partitions: $nsplits" );
	    Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_${search_method}_script.pl -z $n_hmm_searches " .
						     "-o $search_script -n $nsplits --name $db_name -p $project_path -s $use_scratch");
	    if( ! -e $search_script ){
		die "Can't locate your search script, which should be here: $search_script\n";
	    }
	    $self->Shotmap::Run::transfer_file($search_script, $self->remote_connection() . ":" . $self->remote_script_path($search_method) );
	}
	if( $search_type eq "blast" ){
	    my $db_length  = $self->Shotmap::DB::get_blast_db_length($db_name);
	    my $nsplits    = $self->Shotmap::DB::get_number_db_splits($search_type);
	    $self->Shotmap::Notify::print( "Search database size: $db_length\n" );
	    $self->Shotmap::Notify::print( "Number of search database partitions: $nsplits\n" );
	    if( $search_method eq "rapsearch" ){
		Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_${search_method}_script.pl -z $db_length " . 
							 "-o $search_script -n $nsplits --name $db_name -p $project_path -s $use_scratch " .
							 "--suf " . $self->search_db_name_suffix );
	    }
	    else{
		Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_${search_method}_script.pl -z $db_length " . 
							 "-o $search_script -n $nsplits --name $db_name -p $project_path -s $use_scratch");
	    }
	    if( ! -e $search_script ){
		die "Can't locate your search script, which should be here: $search_script\n";
	    }
	    $self->Shotmap::Notify::print_verbose( "Will place the search script on the remote server here: " . $self->remote_script_path($search_method) );
	    $self->Shotmap::Run::transfer_file($search_script, $self->remote_connection() . ":" . $self->remote_script_path($search_method) );
	}
    }
    return $self;
}

sub run_search{
    my( $self ) = @_;

    my $is_remote      = $self->remote;
    my $waittime       = $self->wait;
    my $search_method  = $self->search_method;
    my $search_type    = $self->search_type;
    my $db_name        = $self->search_db_name($search_type);
    my $verbose        = $self->verbose;
    my $force_search   = $self->force_search;

    if ($is_remote){
	$self->Shotmap::Notify::printBanner("RUNNING REMOTE SEARCH");
	my $db_splits = $self->Shotmap::DB::get_number_db_splits( $search_type );
	#build the search submission script
	my $script = $self->Shotmap::Run::build_remote_script( "search" );	
	$self->Shotmap::Run::transfer_file($script, $self->remote_connection() . ":" . $self->remote_script_path($search_method) );
	foreach my $sample_alt_id(@{ $self->get_sample_alt_ids() }) {
	    $self->Shotmap::Run::run_search_remote($sample_alt_id, $search_method, $db_splits, $waittime, $verbose, $force_search);
	    $self->Shotmap::Notify::print( "Progress report: $search_method for sample ${sample_alt_id} completed on " . `date` );
	}  
    } else {
	$self->Shotmap::Notify::printBanner("RUNNING LOCAL SEARCH");
	foreach my $sample_alt_id (@{$self->get_sample_alt_ids()}){
	    my $in_dir   = File::Spec->catdir($self->project_dir, ${sample_alt_id}, "orfs");
	    my $out_dir  = File::Spec->catdir($self->project_dir, ${sample_alt_id}, "searchresults");
	    $self->Shotmap::Notify::notify("Running search for sample ID $sample_alt_id" );
	    #force search is called from environment in spawn_local_threads
	    $self->Shotmap::Run::run_search($sample_alt_id, $search_method,    $waittime, $verbose);
	}	
    }
    return $self;
}

sub stage_search_db{
    my( $self ) = @_;
    my $local_ffdb = $self->ffdb;
    my $projID = $self->project_id();
    my $dbname = $self->db_name();
    my $localScriptDir = $self->local_scripts_dir();
    my $search_method = $self->search_method;

    if ($self->remote && $self->stage){
	$self->Shotmap::Notify::printBanner("STAGING REMOTE SEARCH DATABASE");
	if (defined($self->search_db_name("hmm")) && 
	    ( $search_method eq "hmmsearch" || $search_method eq "hmmscan" )){
	    $self->Shotmap::Run::remote_transfer_search_db( $self->search_db_name("hmm"), "hmm");
	    if (!$self->scratch){
		print "Not using remote scratch space, apparently...\n";
		#should do optimization here
	    } else {
		print "Using remote scratch space, apparently...\n";
	    }
	    #do we still want to do this?
	    #$self->Shotmap::Run::gunzip_remote_dbs($self->search_db_name("hmm"), "hmm");
	}	
	if (defined($self->search_db_name("blast")) && 
	    ( $search_method eq "blast" || $search_method eq "last" || $search_method eq "rapsearch" )){
	    my $blastdb_name = $self->search_db_name( "blast" );
	    my $use_scratch  = $self->scratch;
	    $self->Shotmap::Run::remote_transfer_search_db($self->search_db_name("blast"), "blast");
	    #should do optimization here. Also, should roll over to blast+
	    if( !$self->scratch ){
		$self->Shotmap::Notify::print_verbose ("Not using remote scratch space, apparently...\n");
	    } else {
		$self->Shotmap::Notify::print_verbose( "Using remote scratch space, apparently...\n" );
	    }
	    #do we still want to do this?
	    #$self->Shotmap::Run::gunzip_remote_dbs($self->search_db_name("blast"), "blast");
	    my $project_path = $self->remote_project_path();
	    my $nsplits      = $self->Shotmap::DB::get_number_db_splits("blast");

	    my $script = $self->Shotmap::Run::build_remote_script( "dbformat" );
	    $self->Shotmap::Run::transfer_file($script, $self->remote_connection() . ":" . $self->remote_script_path($self->search_db_fmt_method) );
	    $self->Shotmap::Run::format_remote_blast_dbs( $self->remote_script_path($self->search_db_fmt_method) );
	}
    }        
    return $self;
}

sub format_search_db{
    my( $self ) = @_;
    my $search_method = $self->search_method;
    my $db_file = $self->Shotmap::Run::get_db_filepath_prefix( $search_method ) . "_1.fa"; #only ever 1 for local search
    #rapsearch reqs dbs to have a separate suffix from $db_file
    if( $search_method eq "rapsearch" ){
	#First see if we need to do this
	my $fmt_db  = "${db_file}." . $self->search_db_name_suffix;
	unless( -e $fmt_db && !($self->force_build_search_db ) ){ #ok, we do	    
	    $self->Shotmap::Notify::printBanner("FORMATTING SEQUENCE DATABASE");
	    $self->Shotmap::Notify::print( "Formatting searchdb for $search_method" );
	    $self->Shotmap::Run::format_search_db( $search_method );
	    $self->Shotmap::Notify::print( "Formatting complete" );
	}
    } elsif( $search_method eq "blast" || $search_method eq "last" ){
	#First see if we need to do this
	unless( -e "${db_file}" && !($self->force_build_search_db ) ){ 
	    $self->Shotmap::Notify::printBanner("FORMATTING SEQUENCE DATABASE");
	    $self->Shotmap::Notify::print( "Formatting searchdb for $search_method" );
	    $self->Shotmap::Run::format_search_db( $search_method );
	    $self->Shotmap::Notify::print( "Formatting complete" );       
	}
    } else {
	
    }
}

1;
