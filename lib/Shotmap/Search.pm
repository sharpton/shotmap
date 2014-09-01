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
    my $search_type = $self->search_type;
    my $search_method = $self->search_method;
    #NOTE: These warning should NEVER be needed given the precautions we take in Load.pm (search method defines type of database to build!)
    #hmm
    if ($self->build_search_db("hmm")){
	if ( $search_method ne "hmmsearch" && $search_method ne "hmmscan" ){
	    $self->Shotmap::Notify::warn("It seems that you want to build an hmm database, but you aren't invoking hmmscan or hmmsearch. " .
					 "While I will continue, you should check your settings to make certain you aren't making a mistake."
		);
	}
	$self->Shotmap::Notify::printBanner("BUILDING HMM DATABASE");
	$self->Shotmap::Run::build_search_db( $self->search_db_name( $search_type ), $self->force_build_search_db, $search_type );
    }
    #blast-like
    if ($self->build_search_db("blast")) {
	if ( $search_method ne "blast" && $search_method ne "last" && $search_method ne "rapsearch" ){
	    $self->Shotmap::Notify::warn("It seems that you want to build a sequence database, but you aren't invoking pairwise sequence search algorithgm. " .
					 "While I will continue, you should check your settings to make certain you aren't making a mistake. "
		);
	}
	$self->Shotmap::Notify::printBanner("BUILDING SEQUENCE DATABASE");
	$self->Shotmap::Run::build_search_db( $self->search_db_name( $search_type ), $self->force_build_search_db, $search_type, $self->reps, $self->nr );
    }
    
    #may not need to build the search database, but let's see if we need to load the database info into mysql....
    if( $self->use_db ){
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
    #we always want to symlink these files to the params directory now
    my $raw_db_path    = $self->search_db_path( $search_type ); 
    my $famlen_tab     = "${raw_db_path}/family_lengths.tab";
    my $ffdb_famlen_cp = $self->params_dir . "/family_lengths.tab";
    my $symlink_exists = eval { symlink( $famlen_tab, $ffdb_famlen_cp ); 1 };
    if( ! $symlink_exists ) { #maybe symlink doesn't work on system, so let's try a cp
	copy( $famlen_tab, $ffdb_famlen_cp );
    }
    if( ! -e $famlen_tab ){
	die "Can't seem to create a copy of the family length table located here:\n  $famlen_tab \n".
	    "Trying to place it here:\n  $ffdb_famlen_cp\n";
    }
    if( $search_type eq "blast" ){
	my $seqlen_tab     = $self->search_db_path( $search_type ) . "/sequence_lengths.tab";
	my $ffdb_seqlen_cp = $self->params_dir . "/sequence_lengths.tab";
	$symlink_exists    = eval { symlink( $seqlen_tab, $ffdb_seqlen_cp); 1 };
	if( ! $symlink_exists ) { #maybe symlink doesn't work on system, so let's try a cp
	    copy( $seqlen_tab, $ffdb_seqlen_cp );
	}
	if( ! -e $seqlen_tab ){
	    die "Can't seem to create a copy of the family length table located here:\n  $seqlen_tab \n".
		"Trying to place it here:\n  $ffdb_seqlen_cp\n";
	}	    
    }
    return $self;
}

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
	foreach my $sample_id(@{ $self->get_sample_ids() }) {
	    $self->Shotmap::Run::run_search_remote($sample_id, $search_method,   $db_splits,   $waittime, $verbose, $force_search);
	    $self->Shotmap::Notify::print( "Progress report: $search_method for sample ${sample_id} completed on " . `date` );
	}  
    } else {
	$self->Shotmap::Notify::printBanner("RUNNING LOCAL SEARCH");
	foreach my $sample_id (@{$self->get_sample_ids()}){
	    my $in_dir   = File::Spec->catdir($self->ffdb, "projects", $self->db_name(), $self->project_id(), ${sample_id}, "orfs");
	    my $out_dir  = File::Spec->catdir($self->ffdb, "projects", $self->db_name(), $self->project_id(), ${sample_id}, "searchresults");
	    $self->Shotmap::Notify::notify("Running search for sample ID $sample_id" );
	    #force search is called from environment in spawn_local_threads
	    $self->Shotmap::Run::run_search($sample_id, $search_method,    $waittime, $verbose);
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
	if (defined($self->search_db_name("hmm")) && ( $search_method eq "hmmsearch" || $search_method eq "hmmscan" )){
	    $self->Shotmap::Run::remote_transfer_search_db( $self->search_db_name("hmm"), "hmm");
	    if (!$self->scratch){
		print "Not using remote scratch space, apparently...\n";
		#should do optimization here
	    } else {
		print "Using remote scratch space, apparently...\n";
	    }
	    $self->Shotmap::Run::gunzip_remote_dbs($self->search_db_name("hmm"), "hmm");
	}	
	if (defined($self->search_db_name("blast")) && ( $search_method eq "blast" || $search_method eq "last" || $search_method eq "rapsearch" )){
	    my $blastdb_name = $self->search_db_name( "blast" );
	    my $use_scratch  = $self->scratch;
	    $self->Shotmap::Run::remote_transfer_search_db($self->search_db_name("blast"), "blast");
	    #should do optimization here. Also, should roll over to blast+
	    if( !$self->scratch ){
		$self->Shotmap::Notify::print_verbose ("Not using remote scratch space, apparently...\n");
	    } else {
		$self->Shotmap::Notify::print_verbose( "Using remote scratch space, apparently...\n" );
	    }
	    $self->Shotmap::Run::gunzip_remote_dbs($self->search_db_name("blast"), "blast");
	    my $project_path = $self->remote_project_path();
	    my $nsplits      = $self->Shotmap::DB::get_number_db_splits("blast");
	    if ($search_method eq "blast" ){
		print "Building remote formatdb script...\n";
		my $formatdb_script_path = "$local_ffdb/projects/$dbname/$projID/run_formatdb.sh";
		Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_formatdb_script.pl -o $formatdb_script_path " .
							 "-n $nsplits --name $blastdb_name -p $project_path -s $use_scratch");
		$self->Shotmap::Run::transfer_file($formatdb_script_path, ($self->remote_connection() . ":" . $self->remote_script_path("formatdb") ));
		$self->Shotmap::Run::format_remote_blast_dbs( $self->remote_script_path("formatdb") );
	    }
	    if ($search_method eq "last" ){
		print "Building remote lastdb script...\n";
		my $lastdb_script = "$local_ffdb/projects/$dbname/$projID/run_lastdb.sh";
		Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_lastdb_script.pl -o $lastdb_script " . 
							 "-n $nsplits --name $blastdb_name -p $project_path -s $use_scratch");
		$self->Shotmap::Run::transfer_file($lastdb_script, ($self->remote_connection() . ":" . $self->remote_script_path("lastdb") ));
		$self->Shotmap::Run::format_remote_blast_dbs( $self->remote_script_path("lastdb") ); #this will work for last
	    }
	    if ($search_method eq "rapsearch" ){
		print "Building remote prerapsearch script...\n";
		my $db_suffix = $self->search_db_name_suffix();
		my $prerapsearch_script = "$local_ffdb/projects/$dbname/$projID/run_prerapsearch.sh";
		Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_prerapsearch_script.pl -o $prerapsearch_script " . 
							 "-n $nsplits --name $blastdb_name -p $project_path -s $use_scratch --suf $db_suffix");
		$self->Shotmap::Run::transfer_file($prerapsearch_script, ($self->remote_connection() . ":" . $self->remote_script_path("prerapsearch") ));
		$self->Shotmap::Run::format_remote_blast_dbs( $self->remote_script_path("prerapsearch") ); #this will work for rapsearch
	    }
	}
    }        
    return $self;
}

sub format_search_db{
    my( $self ) = @_;
    my $search_method = $self->search_method;
    if( $search_method eq "rapsearch" ){
	#First see if we need to do this
	my $db_file = $self->Shotmap::Run::get_db_filepath_prefix( $search_method ) . "_1.fa"; #only ever 1 for local search
	my $fmt_db  = "${db_file}." . $self->search_db_name_suffix;
	unless( -e $fmt_db && !($self->force_build_search_db ) ){ #ok, we do
	    $self->Shotmap::Run::format_search_db( $search_method );
	}
    } else {
        die( "Local execution is not currently configured for anything but rapsearch in Shotmap::Search::format_search_db" );
    }
}

1;
