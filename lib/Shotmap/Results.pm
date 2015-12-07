#!/usr/bin/perl -w

#MRC.pm - The MRC workflow manager
#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gladstone.ucsf.edu
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program (see LICENSE.txt).  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Data::Dumper;

package Shotmap::Results;

use lib ($ENV{'SHOTMAP_LOCAL'} . "/ext/lib/perl5");     
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
	    $self->class_evalue(), $self->class_coverage(), $self->class_score,
	    $db_name, $search_method, $self->top_hit_type,
	    )->classification_id();	
	$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id(
	    $self->abundance_type, $self->normalization_type
	    )->abundance_parameter_id;       
    } else {
	$class_id = $self->Shotmap::DB::get_classification_id_flatfile;	    
	$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id_flatfile(
	    $self->abundance_type, $self->normalization_type
	    );
    }
    #we might also not have the sample statistics, which we need for R and AGS correctiong
    if( !defined( $self->sample_stats ) ){
	$self->Shotmap::Run::load_sample_abundance_statistics( $class_id, $abund_param_id );
    }
    #if we used GOTO=D, then we may not have microbecensus data in memory. 
    #Parse it here, we want in metadata output
    if( $self->ags_method eq "microbecensus" ){
	foreach my $sample_alt_id (@{$self->get_sample_alt_ids()}){
	    last if( defined( $self->sample_ags( $sample_alt_id, "ags" ) ) );
	    my $ags_path = File::Spec->catdir(
		$self->get_sample_path($sample_alt_id), "ags", $self->ags_method
		);     
	    my $ags_output = File::Spec->catfile( $ags_path, $sample_alt_id . "_ags.mc" );
	    $self->Shotmap::Run::parse_microbecensus( $sample_alt_id, $ags_output );
	}
    }
    #now generate the output
    $self->classification_id( $class_id );
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
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, 
	    $db_name, $search_method, $self->top_hit_type,
	    )->classification_id();	
	#$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id(
	#    $self->abundance_type, $self->normalization_type
	#    )->abundance_parameter_id;       
    } else {
	$class_id = $self->Shotmap::DB::get_classification_id_flatfile;
	#$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id_flatfile(
	#    $self->abundance_type, $self->normalization_type
	#    );
    }
    $self->classification_id( $class_id );
    if( defined( $self->postrarefy_samples ) ){       
	$self->Shotmap::Notify::notify( "Rarefaction depth: " . $self->postrarefy_samples );
    }
    $self->Shotmap::Notify::notify( "Classification_id: ${class_id}\n" );    
    #$self->Shotmap::Notify::notify( "Abundance_id: ${abund_param_id}\n" );
    foreach my $sample_alt_id( @{ $self->get_sample_alt_ids() } ){
	next unless( $self->Shotmap::Run::check_sample_rarefaction_depth( $sample_alt_id ) ); 
       	#flat file classification and abundances
	my $class_map = $self->Shotmap::Run::classify_reads_flatfile( 
	    $sample_alt_id, $class_id, $search_method 
	    );
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
    #now calculate abundances and produce output
    my( $class_id, $abund_param_id );
    if( $self->use_db ){
	$class_id = $self->Shotmap::DB::get_classification_id(
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, 
	    $db_name, $search_method, $self->top_hit_type,
	    )->classification_id();	
	$abund_param_id = $self->Shotmap::DB::get_abundance_parameter_id(
	    $self->abundance_type, $self->normalization_type
	    )->abundance_parameter_id;       
    } else {
	$class_id = $self->Shotmap::DB::get_classification_id_flatfile;
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
    $self->Shotmap::Notify::notify( "Obtaining search database lengths" );	
    if( $norm_type eq 'family_length' ){
	$length_hash = $self->Shotmap::Run::parse_file_cols_into_hash( 
	    $self->params_dir . "/" . $self->search_db_name . "_family_lengths.tab", 0, 1 
	    );
    } elsif( $norm_type eq 'target_length' ){
	$length_hash = $self->Shotmap::Run::parse_file_cols_into_hash( 
	    $self->params_dir . "/" . $self->search_db_name . "_sequence_lengths.tab", 1, 2 
	    );
    }
    foreach my $sample_alt_id( @{ $self->get_sample_alt_ids() } ){
	if( defined( $self->postrarefy_samples ) ){
	    next unless( 
		$self->Shotmap::Run::get_post_rarefied_reads_flatfile( 
		    $sample_alt_id, $self->rarefaction_type, 1 
		) );
	}
	my( $outdir, $class_map );
	if( $self->filter_hits ){
	    #circle back and make this more generic
	    $outdir  = File::Spec->catdir( $self->project_dir . "/output/Classification_Maps_Filtered_Mammal/" );
	    if( $self->use_db || $self->iterate_output ){
		$outdir = File::Spec->catdir( $outdir, "class_id_${class_id}" );
	    }
	    $class_map    = $outdir . "/ClassificationMap_Sample_${sample_alt_id}.filtered.mammals.tab";
	} else {
	    $outdir  = File::Spec->catdir( $self->project_dir, "/output/Classification_Maps/" );
	    if( $self->use_db || $self->iterate_output ){
		$outdir = File::Spec->catdir( $outdir, "class_id_${class_id}/" );
	    }
	    $class_map    = $outdir . "/ClassificationMap_Sample_${sample_alt_id}.tab";
	    print "class map is $class_map\n";
	}
	if( ! -e $class_map ){
	    die( "I can't find a classification map at the targeted location, which is: " . 
		 $class_map . "\n" .
		 "Cannot continue calculating abundances." );
	}
	#calculate the sample's abundance and obtains sample abundance statistics
	$self->Shotmap::Run::calculate_abundances_flatfile( 
	    $sample_alt_id, $class_id, $abund_param_id, $class_map, $length_hash 
	    );
    }
    $self->Shotmap::Run::print_sample_abundance_statistics( $class_id, $abund_param_id );
}

sub grab_results{
    my( $self ) = @_;
    my $search_method = $self->search_method;    
    if ($self->remote){
	$self->Shotmap::Notify::printBanner("GETTING REMOTE RESULTS");
	foreach my $sample_alt_id(@{ $self->get_sample_alt_ids() }){
	    $self->Shotmap::Run::get_remote_search_results($sample_alt_id, $search_method);
	    print "Progress report: finished ${sample_alt_id} on " . `date` . "";
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
	    $self->class_evalue(), $self->class_coverage(), $self->class_score, 
	    $db_name, $search_method, $self->top_hit_type,
	    )->classification_id();	
    } else {
	$class_id = $self->Shotmap::DB::get_classification_id_flatfile;
    }
    $self->classification_id( $class_id );
    if ($self->remote){
	$self->Shotmap::Notify::printBanner("LOADING REMOTE SEARCH RESULTS");
	foreach my $sample_alt_id(@{ $self->get_sample_alt_ids() }){
	    $self->Shotmap::Notify::notify( "Processing results for sample ${sample_alt_id}");
	    my $path_to_split_orfs = File::Spec->catdir($self->get_sample_path($sample_alt_id), "orfs");     
	    foreach my $orf_split_file_name(
		# maybe could be glob("$path_to_split_orfs/*")
		@{ $self->Shotmap::DB::get_split_sequence_paths($path_to_split_orfs, 0) }) { 
		#ONLY TAKES BULK-LOAD LIKE FILES NOW. OPTIONALLY DELETE PARSED RESULTS WHEN COMPLETED.
		# NOTE THAT WE ONLY INSERT ALT_IDS INTO THIS TABLE!
		# NEED TO USE SAMPLE_ID, ALT_ID FROM (metareads || orfs) TO UNIQUELY EXTRACT ORF/READ ID		
		# $self->Shotmap::Run::classify_reads_old(
		#    $sample_id, $orf_split_file_name, $class_id, $algo, $top_hit_type);
		$self->Shotmap::Run::parse_and_load_search_results_bulk( 
		    $sample_alt_id, $orf_split_file_name, $class_id, $search_method 
		    ); #top_hit_type and strict clustering gets used in diversity calcs now
	    }
	}
    } else{
	if( $self->use_db ){
	    $self->Shotmap::Notify::printBanner("LOADING SEARCH RESULTS");
	    foreach my $sample_alt_id(@{ $self->get_sample_alt_ids() }){
		my $path_to_split_orfs = File::Spec->catdir($self->get_sample_path($sample_alt_id), "orfs");     
		foreach my $orf_split_file_name(
                    # maybe could be glob("$path_to_split_orfs/*")
		    @{ $self->Shotmap::DB::get_split_sequence_paths($path_to_split_orfs, 0) }) { 
		    $self->Shotmap::Run::parse_and_load_search_results_bulk( 
			$sample_alt_id, $orf_split_file_name, $class_id, $search_method 
			); #top_hit_type and strict clustering gets used in diversity calcs now
		}
	    }
	}
    }
    #once results are loaded in the database, we could wipe the raw db-split, 
    #orf-split mysqld files and only keep the orf-split catted results
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
	my $script = $self->Shotmap::Run::build_remote_script( "parse" );	
	$self->Shotmap::Run::transfer_file(
	    $script, $self->remote_connection() . ":" . $self->remote_script_path( "parse_results" ) 
	    );
	foreach my $sample_alt_id(@{ $self->get_sample_alt_ids() }) {
	    $self->Shotmap::Run::parse_results_remote( 
		$sample_alt_id, $db_splits, $waittime, $verbose, $force_search
		);
	    $self->Shotmap::Notify::print( "Progress report: finished ${sample_alt_id} on " . `date` );
	}  
    } else {
	$self->Shotmap::Notify::printBanner("PARSING SEARCH RESULTS"); 
	#force search is called from environment in spawn_local_threads
	foreach my $sample_alt_id(@{ $self->get_sample_alt_ids() }){
	    $self->Shotmap::Notify::notify("Parsing results for sample $sample_alt_id" );
	    $self->Shotmap::Run::parse_results( $sample_alt_id, $search_method, $waittime, $verbose );
	}
    }
    return $self;
}

sub parse_results_hack{
    my( $self ) = @_;
    my $waittime     = $self->wait;
    my $verbose      = $self->verbose;
    my $force_search = $self->force_search;
    my $search_method = $self->search_method;
    my $search_type   = $self->search_type;

    if( $self->remote ){
	$self->Shotmap::Notify::printBanner("PARSING REMOTE SEARCH RESULTS");
	my $db_splits = $self->Shotmap::DB::get_number_db_splits( $search_type );
	foreach my $sample_alt_id(@{ $self->get_sample_alt_ids() }) {
	    $self->Shotmap::Run::parse_results_remote(
		$sample_alt_id, $search_method, $db_splits, $waittime, $verbose, $force_search
		);
	    $self->Shotmap::Notify::print( "Progress report: finished ${sample_alt_id} on " . `date` );
	}  
    } else {
	$self->Shotmap::Notify::printBanner("PARSING SEARCH RESULTS"); 
	#force search is called from environment in spawn_local_threads
	foreach my $sample_alt_id(@{ $self->get_sample_alt_ids() }){
	    $self->Shotmap::Notify::notify("Parsing results for sample $sample_alt_id" );
	    $self->Shotmap::Run::parse_results_hack( 
		$sample_alt_id, $search_method, $waittime, $verbose 
		);
	}
    }
    return $self;
}

sub estimate_ags{
    my $self = shift;   
    my $ags_method = $self->ags_method;
    return if( $ags_method eq "none");
    $self->Shotmap::Notify::printBanner("ESTIMATING AVERAGE GENOME SIZE");
    my $samples = $self->get_sample_hashref;
    foreach my $sample_alt_id (@{$self->get_sample_alt_ids()}){
	my $reads_dir = File::Spec->catdir($self->get_sample_path($sample_alt_id), "raw" );
	if( ! -d $reads_dir ){
	    $self->Shotmap::Notify::warn( "I can't find the shotmap processed reads at $reads_dir, " .
					  "so I can't calculate average genome size. Are you sure you ".
					  "need to run this step? I'm passing\n"
		);
	    next;
	}
	#create a place for the ags output
	my $ags_path = File::Spec->catdir($self->get_sample_path($sample_alt_id), "ags", $ags_method);     
	if( ! -d $ags_path ){
	    File::Path::make_path($ags_path);
	}
	#build the input
	my @raw_files = glob( $reads_dir . "/*" );
	my $tmp       = File::Spec->catfile( $ags_path, "_mc.tmp.gz" );	
	$self->Shotmap::Run::cat_file_array( \@raw_files, $tmp );
	#get the input path       
	#my $in_file = $samples->{$sample_alt_id}->{"path"};
	my $in_file  = $tmp;
	if( $ags_method eq "microbecensus" ){
	    #need to create the log directory
	    my $log_dir    = File::Spec->catdir( $self->get_project_dir, "logs", "microbecensus");
	    File::Path::make_path( $log_dir );
	    my $log_file   = File::Spec->catfile( $log_dir, "microbecensus_" . $sample_alt_id . ".log" );
	    my $ags_output = File::Spec->catfile( $ags_path, $sample_alt_id . "_ags.mc" );
	    $self->Shotmap::Run::run_microbecensus( $in_file, $ags_output, $log_file );
	    $self->Shotmap::Run::parse_microbecensus( $sample_alt_id, $ags_output );
	}
	unlink( $tmp );
    }
}

1;
