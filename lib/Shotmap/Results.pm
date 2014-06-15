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
    
    my $search_method = $self->search_method;
    my $search_type   = $self->search_type;
    my $db_name       = $self->search_db_name( $search_type );
    my( $class_id, $abund_param_id );
    if( $self->use_db ){
	$class_id = $self->Shotmap::DB::get_classification_id(
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, $db_name, $search_method, $self->top_hit_type,
	    )->classification_id();	
	$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id(
	    $self->abundance_type, $self->normalization_type
	    )->abundance_parameter_id;       
    } else {
	$class_id = $self->Shotmap::DB::get_classification_id_flatfile( 
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, $db_name, $search_method, $self->top_hit_type 
	    );
	$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id_flatfile(
	    $self->abundance_type, $self->normalization_type
	    );
    }
    $self->classification_id( $class_id );
    #$self->Shotmap::Run::build_intersample_abundance_map( $class_id, $abund_param_id );
    $self->Shotmap::Run::build_intersample_abundance_map_flatfile( $class_id, $abund_param_id );
    $self->Shotmap::Run::calculate_diversity( $class_id, $abund_param_id );
}

sub classify_reads{
    my( $self ) = @_;

    my $is_remote      = $self->remote;
    my $waitime        = $self->wait;
    my $search_method  = $self->search_method;
    my $search_type    = $self->search_type;
    my $db_name        = $self->search_db_name( $search_type );

    $self->Shotmap::Notify::printBanner("CLASSIFYING READS");
    my( $class_id, $abund_param_id );
    if( $self->use_db ){
	$class_id = $self->Shotmap::DB::get_classification_id(
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, $db_name, $search_method, $self->top_hit_type,
	    )->classification_id();	
	$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id(
	    $self->abundance_type, $self->normalization_type
	    )->abundance_parameter_id;       
    } else {
	$class_id = $self->Shotmap::DB::get_classification_id_flatfile( 
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, $db_name, $search_method, $self->top_hit_type 
	    );
	$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id_flatfile(
	    $self->abundance_type, $self->normalization_type
	    );
    }
    $self->classification_id( $class_id );
    if( defined( $self->postrarefy_samples ) ){       
	$self->Shotmap::Notify::notify( "Rarefaction depth: " . $self->postrarefy_samples );
    }
    $self->Shotmap::Notify::notify( "Classification_id: ${class_id}\n" );    
    $self->Shotmap::Notify::notify( "Abundance_id: ${abund_param_id}\n" );
    foreach my $sample_id( @{ $self->get_sample_ids() } ){
	next unless( $self->Shotmap::Run::check_sample_rarefaction_depth( $sample_id ) ); #NEW FUNCTION
	#The MySQL Way: worked well until we hit HiSeq sample depths. Now off by default
	#my $dbh  = $self->Shotmap::DB::build_dbh();
	#my $result_set = $self->Shotmap::Run::classify_reads( $sample_id, $class_id, $dbh );
	##build_classification_maps_by_sample is now integrated into calculate_abundances
	#$self->Shotmap::Run::build_classification_maps_by_sample($sample_id, $class_id, $result_set, $dbh ); 
	#$self->Shotmap::Run::calculate_abundances( $sample_id, $class_id, $self->abundance_type, $self->normalization_type, $result_set, $dbh );
	#$self->Shotmap::DB::disconnect_dbh( $dbh );	
	
	#flat file classification and abundances
	my $class_map = $self->Shotmap::Run::classify_reads_flatfile( $sample_id, $class_id, $search_method );
	#an added benefit: we can calculate abundances in a seperate routine....may move this to another step at later date

	#move all of this to a new subroutine
	#do some preprocessing for database-free analysis
#	my $length_hash = ();
#	if( ! $self->use_db ){
#	    my $norm_type  = $self->normalization_type;
#	    my $abund_type = $self->abundance_type; 
#	    if( $norm_type eq 'family_length' ){
#		$length_hash = $self->Shotmap::Run::parse_file_cols_into_hash( $self->params_dir . "/family_lengths.tab", 0, 1 );
#	    } elsif( $norm_type eq 'target_length' ){
#		$length_hash = $self->Shotmap::Run::parse_file_cols_into_hash( $self->params_dir . "/sequence_lengths.tab", 1, 2 );
#	    }
#	}
#	$self->Shotmap::Run::calculate_abundances_flatfile( $sample_id, $class_id, $abund_param_id, $class_map, $length_hash );
    }
    return $self;
}

sub calculate_abundances{
    my( $self ) = @_;
    
    my $is_remote      = $self->remote;
    my $waitime        = $self->wait;
    my $search_method  = $self->search_method;
    my $search_type    = $self->search_type;
    my $db_name        = $self->search_db_name( $search_type );
    
    $self->Shotmap::Notify::printBanner("CALCULATING ABUNDANCES");
    my( $class_id, $abund_param_id );
    if( $self->use_db ){
	$class_id = $self->Shotmap::DB::get_classification_id(
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, $db_name, $search_method, $self->top_hit_type,
	    )->classification_id();	
	$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id(
	    $self->abundance_type, $self->normalization_type
	    )->abundance_parameter_id;       
    } else {
	$class_id = $self->Shotmap::DB::get_classification_id_flatfile( 
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, $db_name, $search_method, $self->top_hit_type 
	    );
	$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id_flatfile(
	    $self->abundance_type, $self->normalization_type
	    );
    }
    $self->classification_id( $class_id );
    if( defined( $self->postrarefy_samples ) ){       
	$self->Shotmap::Notify::notify( "Rarefaction depth: " . $self->postrarefy_samples );
    }
    $self->Shotmap::Notify::notify( "Classification_id: ${class_id}\n" );    
    $self->Shotmap::Notify::notify( "Abundance_id: ${abund_param_id}\n" ); 
    my $norm_type  = $self->normalization_type;
    my $abund_type = $self->abundance_type;    
    my $length_hash = (); 
    if( 1 ){ #testing....
	$self->Shotmap::Notify::notify( "Obtaining search database lengths" );	
	if( $norm_type eq 'family_length' ){
	    $length_hash = $self->Shotmap::Run::parse_file_cols_into_hash( $self->params_dir . "/family_lengths.tab", 0, 1 );
	} elsif( $norm_type eq 'target_length' ){
	    $length_hash = $self->Shotmap::Run::parse_file_cols_into_hash( $self->params_dir . "/sequence_lengths.tab", 1, 2 );
	}
    }
    foreach my $sample_id( @{ $self->get_sample_ids() } ){
	next unless( $self->Shotmap::Run::check_sample_rarefaction_depth( $sample_id ) ); #NEW FUNCTION
	my $outdir         = File::Spec->catfile($self->project_dir . "/output" );
	my $class_map      = $outdir . "/ClassificationMap_Sample_${sample_id}_cid_${class_id}.tab";
	#do some preprocessing for database-free analysis
#	if( ! $self->use_db ){
	$self->Shotmap::Run::calculate_abundances_flatfile( $sample_id, $class_id, $abund_param_id, $class_map, $length_hash );
    }
}

sub grab_results{
    my( $self ) = @_;
    my $search_method = $self->search_method;    
    if ($self->remote){
	$self->Shotmap::Notify::printBanner("GETTING REMOTE RESULTS");
	foreach my $sample_id(@{ $self->get_sample_ids() }){
	    $self->Shotmap::Run::get_remote_search_results($sample_id, $search_method);
	    print "Progress report: finished ${sample_id} on " . `date` . "";
	}
    }
    return $self;
}

sub load_results{
    my( $self ) = @_;
    my $search_method = $self->search_method;
    my $search_type   = $self->search_type;
    my $db_name       = $self->search_db_name( $search_type );
    my( $class_id );
    if( $self->use_db ){
	$class_id = $self->Shotmap::DB::get_classification_id(
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, $db_name, $search_method, $self->top_hit_type,
	    )->classification_id();	
    } else {
	$class_id = $self->Shotmap::DB::get_classification_id_flatfile( 
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, $db_name, $search_method, $self->top_hit_type 
	    );
    }
    $self->classification_id( $class_id );
    if ($self->remote){
	$self->Shotmap::Notify::printBanner("LOADING REMOTE SEARCH RESULTS");
	foreach my $sample_id(@{ $self->get_sample_ids() }){
	    $self->Shotmap::Notify::notify( "Processing results for sample ID ${sample_id}");
	    my $path_to_split_orfs = File::Spec->catdir($self->get_sample_path($sample_id), "orfs");     
	    foreach my $orf_split_file_name(@{ $self->Shotmap::DB::get_split_sequence_paths($path_to_split_orfs, 0) }) { # maybe could be glob("$path_to_split_orfs/*")
		#ONLY TAKES BULK-LOAD LIKE FILES NOW. OPTIONALLY DELETE PARSED RESULTS WHEN COMPLETED.
		# NOTE THAT WE ONLY INSERT ALT_IDS INTO THIS TABLE! NEED TO USE SAMPLE_ID, ALT_ID FROM (metareads || orfs) TO UNIQUELY EXTRACT ORF/READ ID		
		#$self->Shotmap::Run::classify_reads_old($sample_id, $orf_split_file_name, $class_id, $algo, $top_hit_type);

		#we need to create a no-db remote search result parser....
		$self->Shotmap::Run::parse_and_load_search_results_bulk( $sample_id, $orf_split_file_name, $class_id, $search_method ); #top_hit_type and strict clustering gets used in diversity calcs now
	    }
	}
    } else{
	$self->Shotmap::Notify::printBanner("LOADING SEARCH RESULTS");
	foreach my $sample_id(@{ $self->get_sample_ids() }){
	    my $path_to_split_orfs = File::Spec->catdir($self->get_sample_path($sample_id), "orfs");     
	    foreach my $orf_split_file_name(@{ $self->Shotmap::DB::get_split_sequence_paths($path_to_split_orfs, 0) }) { # maybe could be glob("$path_to_split_orfs/*")
		$self->Shotmap::Run::parse_and_load_search_results_bulk( $sample_id, $orf_split_file_name, $class_id, $search_method ); #top_hit_type and strict clustering gets used in diversity calcs now
	    }
	}
    }
    #once results are loaded in the database, we could wipe the raw db-split, orf-split mysqld files and only keep the orf-split catted results
    return $self;
}

sub parse_results{
    my( $self ) = @_;
    my $waittime     = $self->wait;
    my $verbose      = $self->verbose;
    my $force_search = $self->force_search;
    my $search_method = $self->search_method;
    my $search_type   = $self->search_type;

    if( $self->remote ){
	$self->Shotmap::Notify::printBanner("PARSING REMOTE SEARCH RESULTS");
	my $db_splits = $self->Shotmap::DB::get_number_db_splits( $search_type );
	foreach my $sample_id(@{ $self->get_sample_ids() }) {
	    $self->Shotmap::Run::parse_results_remote($sample_id, $search_method,   $db_splits,   $waittime, $verbose, $force_search);
	    $self->Shotmap::Notify::print( "Progress report: finished ${sample_id} on " . `date` );
	}  
    } else {
	$self->Shotmap::Notify::printBanner("PARSING SEARCH RESULTS"); 
	#force search is called from environment in spawn_local_threads
	foreach my $sample_id(@{ $self->get_sample_ids() }){
	    $self->Shotmap::Notify::notify("Parsing results for sample ID $sample_id" );
	    $self->Shotmap::Run::parse_results( $sample_id, $search_method,   $waittime, $verbose );
	}
    }
    return $self;
}

1;
