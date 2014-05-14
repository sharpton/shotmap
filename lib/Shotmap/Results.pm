#!/usr/bin/perl -w

#MRC.pm - The MRC workflow manager
#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gladstone.ucsf.edu
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program (see LICENSE.txt).  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

package Shotmap::Results;

use Shotmap;

sub calculate_diversity{
    my( $self ) = @_;
    $self->Shotmap::Notify::printBanner("CALCULATINGDIVERSITY");

    my $hmmdb_name     = $self->search_db_name("hmm");
    my $blastdb_name   = $self->search_db_name("blast");
    my $use_blast      = $self->use_search_alg("blast");
    my $use_last       = $self->use_search_alg("last");
    my $use_rapsearch  = $self->use_search_alg("rapsearch");
    my $use_hmmsearch  = $self->use_search_alg("hmmsearch");
    my $use_hmmscan    = $self->use_search_alg("hmmscan");

    my @algosToRun = ();
    if ($use_hmmscan)   { push(@algosToRun, "hmmscan"); }
    if ($use_hmmsearch) { push(@algosToRun, "hmmsearch"); }
    if ($use_blast)     { push(@algosToRun, "blast"); }
    if ($use_last)      { push(@algosToRun, "last"); }
    if ($use_rapsearch) { push(@algosToRun, "rapsearch"); }
    foreach my $algo (@algosToRun) {
	my ( $class_id, $searchdb_name, $abund_param_id );
	my $abundance_type = "coverage";
	if( $algo eq "hmmsearch" || $algo eq "hmmscan" ){
	    $searchdb_name = $self->search_db_name( "hmm" );
	}
	if( $algo eq "blast" || $algo eq "last" || $algo eq "rapsearch" ){
	    $searchdb_name = $self->search_db_name( "blast" );
	}
	$class_id = $self->Shotmap::DB::get_classification_id(
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, $searchdb_name, $algo, $self->top_hit_type,
	    )->classification_id();
	$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id(
	    $self->abundance_type, $self->normalization_type
	    )->abundance_parameter_id;
	$self->Shotmap::Run::build_intersample_abundance_map( $class_id, $abund_param_id );
	$self->Shotmap::Run::calculate_diversity( $class_id, $abund_param_id );
    }
}

sub classify_reads{
    my( $self ) = @_;

    my $is_remote      = $self->remote;
    my $waitime        = $self->wait;
    my $use_blast      = $self->use_search_alg("blast");
    my $use_last       = $self->use_search_alg("last");
    my $use_rapsearch  = $self->use_search_alg("rapsearch");
    my $use_hmmsearch  = $self->use_search_alg("hmmsearch");
    my $use_hmmscan    = $self->use_search_alg("hmmscan");
    my $hmmdb_name     = $self->search_db_name("hmm");
    my $blastdb_name   = $self->search_db_name("blast");

    $self->Shotmap::Notify::printBanner("CLASSIFYING READS");
    foreach my $sample_id( @{ $self->get_sample_ids() } ){
	next unless( $self->Shotmap::Run::check_sample_rarefaction_depth( $sample_id ) ); #NEW FUNCTION
	my @algosToRun = ();
	if ($use_hmmscan)   { push(@algosToRun, "hmmscan"); }
	if ($use_hmmsearch) { push(@algosToRun, "hmmsearch"); }
	if ($use_blast)     { push(@algosToRun, "blast"); }
	if ($use_last)      { push(@algosToRun, "last"); }
	if ($use_rapsearch) { push(@algosToRun, "rapsearch"); }
	foreach my $algo (@algosToRun) {
	    my ( $class_id, $searchdb_name );
	    if( $algo eq "hmmsearch" || $algo eq "hmmscan" ){
		$searchdb_name = $self->search_db_name( "hmm" );
	    }
	    if( $algo eq "blast" || $algo eq "last" || $algo eq "rapsearch" ){
		$searchdb_name = $self->search_db_name( "blast" );
	    }
	    $class_id = $self->Shotmap::DB::get_classification_id(
		$self->class_evalue(), $self->class_coverage(), $self->class_score(), $searchdb_name, $algo, $self->top_hit_type(),
		)->classification_id();
	    print "Classifying reads using classification_id ${class_id}\n";
	    if( defined( $self->postrarefy_samples ) ){
		print "Rarefying to " . $self->postrarefy_samples . " reads per sample\n";
	    }
	    print "Calculating abundances and building classification map...\n";  
	    #The MySQL Way: worked well until we hit HiSeq sample depths. Now off by default
	    #my $dbh  = $self->Shotmap::DB::build_dbh();
	    #my $result_set = $self->Shotmap::Run::classify_reads( $sample_id, $class_id, $dbh );
	    ##build_classification_maps_by_sample is now integrated into calculate_abundances
	    #$self->Shotmap::Run::build_classification_maps_by_sample($sample_id, $class_id, $result_set, $dbh ); 
	    #$self->Shotmap::Run::calculate_abundances( $sample_id, $class_id, $self->abundance_type, $self->normalization_type, $result_set, $dbh );
	    #$self->Shotmap::DB::disconnect_dbh( $dbh );	
	    
	    #flat file classification and abundances
	    my $class_map = $self->Shotmap::Run::classify_reads_flatfile( $sample_id, $class_id, $algo );
	    #an added benefit: we can calculate abundances in a seperate routine....may move this to another step at later date
	    my $abundance_parameter_id = $self->Shotmap::DB::get_abundance_parameter_id( $self->abundance_type, $self->normalization_type )->abundance_parameter_id();
	    $self->Shotmap::Run::calculate_abundances_flatfile( $sample_id, $class_id, $abundance_parameter_id, $class_map );
	}
    }
    return $self;
}

sub grab_results{
    my( $self ) = @_;
    if ($self->remote){
	$self->Shotmap::Notify::printBanner("GETTING REMOTE RESULTS");
	foreach my $sample_id(@{ $self->get_sample_ids() }){
	    ($self->use_search_alg("hmmscan"))   && $self->Shotmap::Run::get_remote_search_results($sample_id, "hmmscan");
	    ($self->use_search_alg("blast"))     && $self->Shotmap::Run::get_remote_search_results($sample_id, "blast");
	    ($self->use_search_alg("hmmsearch")) && $self->Shotmap::Run::get_remote_search_results($sample_id, "hmmsearch");
	    ($self->use_search_alg("last"))      && $self->Shotmap::Run::get_remote_search_results($sample_id, "last");
	    ($self->use_search_alg("rapsearch")) && $self->Shotmap::Run::get_remote_search_results($sample_id, "rapsearch");
	    print "Progress report: finished ${sample_id} on " . `date` . "";
	}
    }
    return $self;
}

sub load_results{
    my( $self ) = @_;
    if ($self->remote){
	$self->Shotmap::Notify::printBanner("LOADING REMOTE SEARCH RESULTS");
	foreach my $sample_id(@{ $self->get_sample_ids() }){
	    print "Classifying reads for sample $sample_id\n";
	    my $path_to_split_orfs = File::Spec->catdir($self->get_sample_path($sample_id), "orfs");     
	    my @algosToRun = ();
	    if ($self->use_search_alg("hmmscan"))   { push(@algosToRun, "hmmscan"); }
	    if ($self->use_search_alg("hmmsearch")) { push(@algosToRun, "hmmsearch"); }
	    if ($self->use_search_alg("blast"))     { push(@algosToRun, "blast"); }
	    if ($self->use_search_alg("last"))      { push(@algosToRun, "last"); }
	    if ($self->use_search_alg("rapsearch")) { push(@algosToRun, "rapsearch"); }
	    foreach my $orf_split_file_name(@{ $self->Shotmap::DB::get_split_sequence_paths($path_to_split_orfs, 0) }) { # maybe could be glob("$path_to_split_orfs/*")
		foreach my $algo (@algosToRun) {
		    my ( $class_id, $db_name );
		    if( $algo eq "hmmsearch" || $algo eq "hmmscan" ){
			$db_name = $self->search_db_name( "hmm" );
		    }
		    if( $algo eq "blast" || $algo eq "last" || $algo eq "rapsearch" ){
			$db_name = $self->search_db_name( "blast" );
		    }
		    $class_id = $self->Shotmap::DB::get_classification_id(
			$self->parse_evalue, $self->parse_coverage, $self->parse_score, $self->db_name, $algo, $self->top_hit_type,
			)->classification_id();
		    print "Classification_id for this run using $algo is $class_id\n";    
		    #ONLY TAKES BULK-LOAD LIKE FILES NOW. OPTIONALLY DELETE PARSED RESULTS WHEN COMPLETED.
		    # NOTE THAT WE ONLY INSERT ALT_IDS INTO THIS TABLE! NEED TO USE SAMPLE_ID, ALT_ID FROM (metareads || orfs) TO UNIQUELY EXTRACT ORF/READ ID		
		    #$self->Shotmap::Run::classify_reads_old($sample_id, $orf_split_file_name, $class_id, $algo, $top_hit_type);
		    $self->Shotmap::Run::parse_and_load_search_results_bulk( $sample_id, $orf_split_file_name, $class_id, $algo ); #top_hit_type and strict clustering gets used in diversity calcs now
		}
	    }
	}
    } else{
	$self->Shotmap::Notify::printBanner("PARSING RESULTS LOCALLY");
	#this block is deprecated...
	foreach my $sample_id(@{ $self->get_sample_ids() }){
	    
	}
    }
    return $self;
}

sub parse_results{
    my( $self ) = @_;
    my $waittime     = $self->wait;
    my $verbose      = $self->verbose;
    my $force_search = $self->force_search;

    if( $self->remote ){
	$self->Shotmap::Notify::printBanner("PARSING REMOTE SEARCH RESULTS");
	my( $hmm_splits, $blast_splits );
	if( $self->use_search_alg("hmmscan") || $self->use_search_alg("hmmsearch") ){
	    $hmm_splits   = $self->Shotmap::DB::get_number_db_splits("hmm");
	}
	if( $self->use_search_alg("blast") || $self->use_search_alg("last") || $self->use_search_alg("rapsearch") ){
	    $blast_splits = $self->Shotmap::DB::get_number_db_splits("blast");
	}
	foreach my $sample_id(@{ $self->get_sample_ids() }) {
	    ($self->use_search_alg("hmmscan"))   && $self->Shotmap::Run::parse_results_remote($sample_id, "hmmscan",   $hmm_splits,   $waittime, $verbose, $force_search);
	    ($self->use_search_alg("hmmsearch")) && $self->Shotmap::Run::parse_results_remote($sample_id, "hmmsearch", $hmm_splits,   $waittime, $verbose, $force_search);
	    ($self->use_search_alg("blast"))     && $self->Shotmap::Run::parse_results_remote($sample_id, "blast",     $blast_splits, $waittime, $verbose, $force_search);
	    ($self->use_search_alg("last"))      && $self->Shotmap::Run::parse_results_remote($sample_id, "last",      $blast_splits, $waittime, $verbose, $force_search);
	    ($self->use_search_alg("rapsearch")) && $self->Shotmap::Run::parse_results_remote($sample_id, "rapsearch", $blast_splits, $waittime, $verbose, $force_search);
	    print "Progress report: finished ${sample_id} on " . `date` . "";
	}  
    } else {
	$self->Shotmap::Notify::printBanner("PARSING LOCAL SEARCH RESULTS"); 
	#force search is called from environment in spawn_local_threads
	foreach my $sample_id(@{ $self->get_sample_ids() }){
	    ($self->use_search_alg("hmmscan"))   && $self->Shotmap::Run::parse_results( $sample_id, "hmmscan",   $waittime, $verbose );
	    ($self->use_search_alg("hmmsearch")) && $self->Shotmap::Run::parse_results( $sample_id, "hmmsearch", $waittime, $verbose );
	    ($self->use_search_alg("blast"))     && $self->Shotmap::Run::parse_results( $sample_id, "blast",     $waittime, $verbose );
	    ($self->use_search_alg("last"))      && $self->Shotmap::Run::parse_results( $sample_id, "last",      $waittime, $verbose );
	    ($self->use_search_alg("rapsearch")) && $self->Shotmap::Run::parse_results( $sample_id, "rapsearch", $waittime, $verbose );
	}
    }
    return $self;
}

1;
