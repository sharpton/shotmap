#!/usr/bin/perl -w

#MRC.pm - The MRC workflow manager
#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gladstone.ucsf.edu
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program (see LICENSE.txt).  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

package Shotmap::Reads;

use lib ($ENV{'SHOTMAP_LOCAL'} . "/ext/lib/perl5");     

use Shotmap;
use Shotmap::Run;
use Shotmap::DB;
use Getopt::Long qw(GetOptionsFromString GetOptionsFromArray);
use File::Basename;

sub load_project{
    my( $self ) = @_;
    my $is_remote   = $self->remote();
    my $dryRun      = $self->dryrun();
    my $project_dir = $self->raw_data();
    #LOAD PROJECT, SAMPLES, METAREADS
    #Grab the samples associated with the project
    $self->Shotmap::Notify::printBanner("LOADING PROJECT");
    $self->Shotmap::Notify::print_verbose( "Project directory: $project_dir\n" );
    #Partitioned samples project
    #get the samples associated with project. a project description can be left in DESCRIPT.txt    
    if (!$dryRun) { $self->Shotmap::Run::get_partitioned_samples($project_dir); }
    else { $self->Shotmap::Notify::dryNotify("Skipped getting the partitioned samples for $project_dir."); }
    
############
#come back and add a check that ensures sequences associated with samples
#are of the proper format. We should check data before loading.
############
#Load Data. Project id becomes a project var in load_project
    
    if( $self->use_db ) { 
	$self->Shotmap::Run::check_prior_analyses( $self->opts->{"reload"} ); #have any of these samples been processed already?
    }
    
    if (!$dryRun) {
	$self->Shotmap::Run::load_project($project_dir );
    } else {
	$self->set_project_id(-99); # Dummy project ID
	$self->Shotmap::Notify::dryNotify("Skipping the local load of the project.");
    }
    
    if ($is_remote){
	if (!$dryRun) {
	    $self->Shotmap::Run::load_project_remote($self->project_id());
	} else { #prepare cluster submission scripts
	    $self->Shotmap::Notify::dryNotify("Skipping the REMOTE loading of the project.");
	}
	#obsolete as we simply updated remote_script_path to auto generate these paths
	if( 0 ){
	    #hmmscan
	    if( $self->search_method eq "hmmscan" ){
		$self->remote_script_path( "hmmscan",      File::Spec->catfile($self->remote_project_path(), "run_hmmscan.sh"));
	    }
	    #hmmsearch
	    if( $self->search_method eq "hmmsearch" ){
		$self->remote_script_path( "hmmsearch",    File::Spec->catfile($self->remote_project_path(), "run_hmmsearch.sh"));
	    }
	    #blast
	    if( $self->search_method eq "blast" ){
		$self->remote_script_path( "blast",        File::Spec->catfile($self->remote_project_path(), "run_blast.sh"));
		$self->remote_script_path( "formatdb",     File::Spec->catfile($self->remote_project_path(), "run_formatdb.sh"));
	    }
	    #last
	    if( $self->search_method eq "last" ){
		$self->remote_script_path( "last",         File::Spec->catfile($self->remote_project_path(), "run_last.sh"));
		$self->remote_script_path( "lastdb",       File::Spec->catfile($self->remote_project_path(), "run_lastdb.sh"));
	    }
	    #rapsearch
	    if( $self->search_method eq "rapsearch" ){
		$self->remote_script_path( "rapsearch",    File::Spec->catfile($self->remote_project_path(), "run_rapsearch.sh"));
		$self->remote_script_path( "prerapsearch", File::Spec->catfile($self->remote_project_path(), "run_prerapsearch.sh"));
	    }      
	}
	$self->remote_scripts_dir( $self->remote_project_path . "/scripts" ); 
	$self->remote_project_log_dir( File::Spec->catdir( $self->remote_project_path(), "logs") );
    }
}

1;
