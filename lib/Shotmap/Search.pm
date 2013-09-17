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

use Shotmap;
use File::Basename;

sub build_search_db{
    my( $self ) = @_;
    
    if ($self->build_search_db("hmm")){
	if (!$self->use_search_alg("hmmscan") && !$self->use_search_alg("hmmsearch")) {
	    warn("WARNING: It seems that you want to build an hmm database, but you aren't invoking hmmscan or hmmsearch. " .
		 "While I will continue, you should check your settings to make certain you aren't making a mistake."
		);
	}
	$self->Shotmap::Notify::printBanner("BUILDING HMM DATABASE");
	$self->Shotmap::Run::build_search_db( $self->search_db_name("hmm"), $self->search_db_split_size("hmm"), $self->force_build_search_db, "hmm");
    }

    if ($self->build_search_db("blast")) {
	if (!$self->use_search_alg("blast") && !$self->use_search_alg("last") && !$self->use_search_alg("rapsearch")) {
	    warn("It seems that you want to build a sequence database, but you aren't invoking pairwise sequence search algorithgm. " .
		 "While I will continue, you should check your settings to make certain you aren't making a mistake. " . 
		 "You might considering running --use_blast, --use_last, and/or --use_rapsearch");
	}
	$self->Shotmap::Notify::printBanner("BUILDING SEQUENCE DATABASE");
	$self->Shotmap::Run::build_search_db( $self->search_db_name("blast"), $self->search_db_split_size("blast"), $self->force_build_search_db, "blast", $self->reps, $self->nr );
    }
    
    #may not need to build the search database, but let's see if we need to load the database info into mysql....
    $self->Shotmap::Notify::printBanner("LOADING FAMILY DATA"); #could run a check to see if this is necessary, the loadings could be sped up as well....
    if( $self->use_search_alg("blast") || $self->use_search_alg("last") || $self->use_search_alg("rapsearch")) {
	if( ! $self->Shotmap::Run::check_family_loadings( "blast", $self->db_name ) ){
	    $self->Shotmap::Run::load_families( "blast", $self->db_name );
	}
	if( ! $self->Shotmap::Run::check_familymember_loadings( "blast", $self->db_name ) ){
	    $self->Shotmap::Run::load_family_members( "blast", $self->db_name );
	}
    }
    if( $self->use_search_alg("hmmsearch") || $self->use_search_alg("hmmscan") ){
	if( ! $self->Shotmap::Run::check_family_loadings( "hmm", $self->db_name ) ){
	    $self->Shotmap::Run::load_families( "hmm", $self->db_name );
	}
    }

    #still need to build this
    if( defined( $self->family_annotations ) ){ #points to file that contains annotations for families
	if( ! -e $self->family_annotations ){
	    warn "The path to the family annotations that you specified does not seem to exist! You pointed me to <" . $self->family_annotations . ">\n";
	} else {
	    $self->Shotmap::DB::load_annotations( $self->family_annotations );
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
    my $use_blast      = $self->use_search_alg("blast");
    my $use_last       = $self->use_search_alg("last");
    my $use_rapsearch  = $self->use_search_alg("rapsearch");
    my $use_hmmsearch  = $self->use_search_alg("hmmsearch");
    my $use_hmmscan    = $self->use_search_alg("hmmscan");
    my $hmmdb_name     = $self->search_db_name("hmm");
    my $blastdb_name   = $self->search_db_name("blast");

    if ($is_remote) {
	my $project_path = $self->remote_project_path();
	if ($use_hmmscan){
	    $self->Shotmap::Notify::printBanner("BUILDING REMOTE HMMSCAN SCRIPT");
	    my $h_script       = "$local_ffdb/projects/$dbname/$projID/run_hmmscan.sh";
	    my $n_hmm_searches = $self->Shotmap::DB::get_number_hmmdb_scans( $self->search_db_split_size("hmm") );
	    my $nsplits        = $self->Shotmap::DB::get_number_db_splits("hmm"); #do we still need this?
	    print "number of hmm searches: $n_hmm_searches\n";
	    print "number of hmm splits: $nsplits\n";
	    Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_hmmscan_script.pl -z $n_hmm_searches " .
						     "-o $h_script -n $nsplits --name $hmmdb_name -p $project_path -s $use_scratch");
	    $self->Shotmap::Run::transfer_file($h_script, $self->remote_connection() . ":" . $self->remote_script_path("hmmscan"));
	}
	if ($use_hmmsearch){
	    $self->Shotmap::Notify::printBanner("BUILDING REMOTE HMMSEARCH SCRIPT");
	    my $h_script   = "$local_ffdb/projects/$dbname/$projID/run_hmmsearch.sh";
	    #my $n_hmm_searches  = $self->Shotmap::DB::get_number_hmmdb_scans($hmm_db_split_size);
	    my $n_sequences = $self->Shotmap::DB::get_number_sequences( $self->read_split_size );
	    my $nsplits     = $self->Shotmap::DB::get_number_db_splits("hmm");
	    print "number of searches: $n_sequences\n";
	    print "number of hmmdb splits: $nsplits\n";
	    Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_hmmsearch_script.pl -z $n_sequences -o $h_script " .
						     "-n $nsplits --name $hmmdb_name -p $project_path -s $use_scratch");
	    Shotmap::Run::transfer_file($h_script, $self->remote_connection() . ":" . $self->remote_script_path("hmmsearch"));
	}
	if ($use_blast){
	    $self->Shotmap::Notify::printBanner("BUILDING REMOTE BLAST SCRIPT");
	    my $b_script   = "$local_ffdb/projects/$dbname/$projID/run_blast.sh";
	    my $db_length  = $self->Shotmap::DB::get_blast_db_length($blastdb_name);
	    my $nsplits    = $self->Shotmap::DB::get_number_db_splits("blast");
	    print "database length is $db_length\n";
	    print "number of blast db splits: $nsplits\n";
	    Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_blast_script.pl -z $db_length " . 
						     "-o $b_script -n $nsplits --name $blastdb_name -p $project_path -s $use_scratch");
	    Shotmap::Run::transfer_file($b_script, $self->remote_connection() . ":" . $self->remote_script_path("blast"));
	}
	if ($use_last){
	    $self->Shotmap::Notify::printBanner("BUILDING REMOTE LAST SCRIPT");
	    #we use the blast script code as a template given the similarity between the methods, so there are some common var names between the block here and above
	    my $last_local     = "$local_ffdb/projects/$dbname/$projID/run_last.sh";
	    my $db_length    = $self->Shotmap::DB::get_blast_db_length($blastdb_name);
	    my $nsplits      = $self->Shotmap::DB::get_number_db_splits("blast");
	    print "database length is $db_length\n";
	    print "number of last db splits: $nsplits\n";
	    Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_last_script.pl -z $db_length " . 
						     "-o $last_local -n $nsplits --name $blastdb_name -p $project_path -s $use_scratch");
	    Shotmap::Run::transfer_file($last_local, $self->remote_connection() . ":" . $self->remote_script_path("last"));
	}
	if ($use_rapsearch){
	    $self->Shotmap::Notify::printBanner("BUILDING REMOTE RAPSEARCH SCRIPT");
	    #we use the blast scrip code as a template given the similarity between the methods, so there are some common var names between the block here and above
	    my $rap_local    = "$local_ffdb/projects/$dbname/$projID/run_rapsearch.sh";
	    my $db_length    = $self->Shotmap::DB::get_blast_db_length($blastdb_name);
	    my $nsplits      = $self->Shotmap::DB::get_number_db_splits("blast");
	    print "database length is $db_length\n";
	    print "number of rapsearch db splits: $nsplits\n";
	    Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_rapsearch_script.pl -z $db_length " .
						     "-o $rap_local -n $nsplits --name $blastdb_name -p $project_path -s $use_scratch");
	    $self->Shotmap::Run::transfer_file($rap_local, $self->remote_connection() . ":" . $self->remote_script_path("rapsearch"));
	}
    }
    return $self;
}

sub run_search{
    my( $self ) = @_;

    my $is_remote      = $self->remote;
    my $waittime       = $self->wait;
    my $use_blast      = $self->use_search_alg("blast");
    my $use_last       = $self->use_search_alg("last");
    my $use_rapsearch  = $self->use_search_alg("rapsearch");
    my $use_hmmsearch  = $self->use_search_alg("hmmsearch");
    my $use_hmmscan    = $self->use_search_alg("hmmscan");
    my $hmmdb_name     = $self->search_db_name("hmm");
    my $blastdb_name   = $self->search_db_name("blast");
    my $verbose        = $self->verbose;
    my $force_search   = $self->force_search;

    if ($is_remote){
	$self->Shotmap::Notify::printBanner("RUNNING REMOTE SEARCH");
	my( $hmm_splits, $blast_splits );
	if( $use_hmmscan || $use_hmmsearch ){
	    $hmm_splits   = $self->Shotmap::DB::get_number_db_splits("hmm");
	}
	if( $use_blast || $use_last || $use_rapsearch ){
	    $blast_splits = $self->Shotmap::DB::get_number_db_splits("blast");
	}
	foreach my $sample_id(@{ $self->get_sample_ids() }) {
	    ($use_hmmscan)   && $self->Shotmap::Run::run_search_remote($sample_id, "hmmscan",   $hmm_splits,   $waittime, $verbose, $force_search);
	    ($use_hmmsearch) && $self->Shotmap::Run::run_search_remote($sample_id, "hmmsearch", $hmm_splits,   $waittime, $verbose, $force_search);
	    ($use_blast)     && $self->Shotmap::Run::run_search_remote($sample_id, "blast",     $blast_splits, $waittime, $verbose, $force_search);
	    ($use_last)      && $self->Shotmap::Run::run_search_remote($sample_id, "last",      $blast_splits, $waittime, $verbose, $force_search);
	    ($use_rapsearch) && $self->Shotmap::Run::run_search_remote($sample_id, "rapsearch", $blast_splits, $waittime, $verbose, $force_search);
	    print "Progress report: finished ${sample_id} on " . `date` . "";
	}  
    } else {
	$self->Shotmap::Notify::printBanner("RUNNING LOCAL SEARCH");
	foreach my $sample_id(@{ $self->get_sample_ids() }){
            #my $sample_path = $local_ffdb . "/projects/" . $self->get_project_id() . "/" . $sample_id . "/";
	    my %hmmdbs = %{ $self->Shotmap::DB::get_hmmdbs($hmmdb_name) };
	    warn "Running hmmscan for sample ID ${sample_id}...";
	    foreach my $hmmdb(keys(%hmmdbs)) {
		my $results_full_path = "search_results/${sample_id}_v_${hmmdb}.hsc";
		#run with tblast output format (e.g., --domtblout)
		$self->Shotmap::Run::run_hmmscan("orfs.fa", $hmmdbs{$hmmdb}, $results_full_path, 1);
	    }
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

    if ($self->remote && $self->stage){
	$self->Shotmap::Notify::printBanner("STAGING REMOTE SEARCH DATABASE");
	if (defined($self->search_db_name("hmm")) && ($self->use_search_alg("hmmsearch") || $self->use_search_alg("hmmscan"))){
	    $self->Shotmap::Run::remote_transfer_search_db( $self->search_db_name("hmm"), "hmm");
	    if (!$self->scratch){
		print "Not using remote scratch space, apparently...\n";
		#should do optimization here
		$self->Shotmap::Run::gunzip_remote_dbs($self->search_db_name("hmm"), "hmm");
	    } else {
		print "Using remote scratch space, apparently...\n";
	    }
	}	
	if (defined($self->search_db_name("blast")) && ($self->use_search_alg("blast") || $self->use_search_alg("last") || $self->use_search_alg("rapsearch"))){
	    my $blastdb_name = $self->search_db_name( "blast" );
	    my $use_scratch  = $self->scratch;
	    $self->Shotmap::Run::remote_transfer_search_db($self->search_db_name("blast"), "blast");
	    #should do optimization here. Also, should roll over to blast+
	    if( !$self->scratch ){
		print "Not using remote scratch space, apparently...\n";
		$self->Shotmap::Run::gunzip_remote_dbs($self->search_db_name("blast"), "blast");
	    } else {
		print "Using remote scratch space, apparently...\n";
	    }
	    my $project_path = $self->remote_project_path();
	    my $nsplits      = $self->Shotmap::DB::get_number_db_splits("blast");
	    if ($self->use_search_alg("blast")){
		print "Building remote formatdb script...\n";
		my $formatdb_script_path = "$local_ffdb/projects/$dbname/$projID/run_formatdb.sh";
		Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_formatdb_script.pl -o $formatdb_script_path " .
							 "-n $nsplits --name $blastdb_name -p $project_path -s $use_scratch");
		$self->Shotmap::Run::transfer_file($formatdb_script_path, ($self->remote_connection() . ":" . $self->remote_script_path("formatdb") ));
		$self->Shotmap::Run::format_remote_blast_dbs( $self->remote_script_path("formatdb") );
	    }
	    if ($self->use_search_alg("last")){
		print "Building remote lastdb script...\n";
		my $lastdb_script = "$local_ffdb/projects/$dbname/$projID/run_lastdb.sh";
		Shotmap::Notify::exec_and_die_on_nonzero("perl $localScriptDir/building_scripts/build_remote_lastdb_script.pl -o $lastdb_script " . 
							 "-n $nsplits --name $blastdb_name -p $project_path -s $use_scratch");
		$self->Shotmap::Run::transfer_file($lastdb_script, ($self->remote_connection() . ":" . $self->remote_script_path("lastdb") ));
		$self->Shotmap::Run::format_remote_blast_dbs( $self->remote_script_path("lastdb") ); #this will work for last
	    }
	    if ($self->use_search_alg("rapsearch")){
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


1;
