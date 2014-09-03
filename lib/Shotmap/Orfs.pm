#!/usr/bin/perl -w

#MRC.pm - The MRC workflow manager
#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gladstone.ucsf.edu
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program (see LICENSE.txt).  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

package Shotmap::Orfs;

use lib ($ENV{'SHOTMAP_LOCAL'} . "/ext/lib/perl5");     

use Shotmap;
use Shotmap::Run;
use Shotmap::Notify;
use File::Spec;

sub load_orfs{
    my( $self )    = @_;
    my $dryRun     = $self->dryrun();
    my $dbname     = $self->db_name();
    my $projID     = $self->project_id();
    my $local_ffdb = $self->ffdb();
    if( $self->use_db ){
	unless( $self->is_slim ){
	    $self->Shotmap::Notify::printBanner("LOADING TRANSLATED READS");
	    foreach my $sample_id (@{ $self->get_sample_ids() }){
		my $projID     = $self->project_id();
		my $in_orf_dir = "$local_ffdb/projects/$dbname/$projID/$sample_id/orfs";
		my $orfCount   = 0;
		foreach my $in_orfs(@{ $self->Shotmap::DB::get_split_sequence_paths($in_orf_dir, 1) }){
		    warn "Processing orfs in <$in_orfs>...";

		    #Get out of Bioperl!
		    my $orfs = Bio::SeqIO->new(-file => $in_orfs, -format => 'fasta'); #we should move this out of bioperl for speed...

		    if( $self->bulk_load() ){
			if( !$dryRun) { $self->Shotmap::Run::bulk_load_orf( $in_orfs, $sample_id, $self->trans_method ); }
			else { $self->Shotmap::Notify::dryNotify(); }
		    }
		    elsif ($self->is_multiload()){
			if (!$dryRun) { $self->Shotmap::Run::load_multi_orfs($orfs, $sample_id, $self->trans_method); }
			else { $self->Shotmap::Notify::dryNotify(); }
		    }
		    else {
			while (my $orf = $orfs->next_seq()) {
			    my $orf_alt_id  = $orf->display_id();
			    my $read_alt_id = Shotmap::Run::parse_orf_id($orf_alt_id, $self->trans_method );
			    if (!$dryRun) { $self->Shotmap::Run::load_orf($orf_alt_id, $read_alt_id, $sample_id); }
			    else { $self->Shotmap::Notify::dryNotify(); }
			    $self->Shotmap::Notify::print_verbose( "Added " . ($orfCount++) . " orfs to the DB...\n" );
			}
		    }
		    
		}
	    }
	}
    }
    return $self;
}

sub translate_reads{
    my ( $self )          = @_;
    my $is_remote         = $self->remote();
    my $dryRun            = $self->dryrun();
    my $local_ffdb        = $self->ffdb();
    my $waittime          = $self->wait();
    my $should_split_orfs = $self->split_orfs();
    my $filter_length     = $self->orf_filter_length();
    $self->Shotmap::Notify::printBanner( "TRANSLATING READS" );
    if (!$dryRun) {
	if ($is_remote) {
	    # run transeq remotely, check on SGE job status, pull results back locally once job complete.
	    my $remoteLogDir = File::Spec->catdir($self->remote_project_path(), "logs");
	    $self->Shotmap::Run::translate_reads_remote($waittime, $remoteLogDir, $should_split_orfs, $filter_length);
	} else {
	    foreach my $sampleID (@{$self->get_sample_ids()}){
		my $raw_reads_dir   = File::Spec->catdir(${local_ffdb}, "projects", $self->db_name(), $self->project_id(), ${sampleID}, "raw");
		my $orfs_output_dir;
		if( $should_split_orfs ){
		    $orfs_output_dir = File::Spec->catdir(${local_ffdb}, "projects", $self->db_name(), $self->project_id(), ${sampleID}, "unsplit_orfs");
		} else {
		   $orfs_output_dir =  File::Spec->catdir(${local_ffdb}, "projects", $self->db_name(), $self->project_id(), ${sampleID}, "orfs");
		}
		$self->Shotmap::Notify::notify("Translating reads for sample ID $sampleID\n");
		$self->Shotmap::Notify::print_verbose( "$raw_reads_dir -> $orfs_output_dir\n");
		$self->Shotmap::Run::translate_reads($raw_reads_dir, $orfs_output_dir, $waittime); #make this function work...
		#no longer need the function below (or --split-orfs), as metatrans handles this set of functions internally
		if( 0 ){
		    if( $should_split_orfs ){
			my $split_out = File::Spec->catdir(${local_ffdb}, "projects", $self->db_name(), $self->project_id(), ${sampleID}, "orfs");
			$self->Shotmap::Notify::notify("Splitting orfs for sample ID $sampleID");
			$self->Shotmap::Notify::print_verbose( "$orfs_output_dir -> $split_out");
			$self->Shotmap::Run::split_orfs_local($orfs_output_dir, $split_out);
		    }
		}
	    }
	}
    } else {
	$self->Shotmap::Notify::dryNotify("Skipping translation of reads.");
    }    
    return $self;
}

1;
