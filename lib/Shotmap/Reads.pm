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
use Data::Dumper;

sub load_project{
    my( $self ) = @_;
    my $is_remote   = $self->remote();
    my $dryRun      = $self->dryrun();
    my $project_dir = $self->raw_data(); #note: could actually be a file
    #LOAD PROJECT, SAMPLES, METAREADS
    #Grab the samples associated with the project
    $self->Shotmap::Notify::printBanner("LOADING PROJECT");
    $self->Shotmap::Notify::print_verbose( "Project directory: $project_dir\n" );
    if (!$dryRun) { 
	if( $self->input_type eq "directory" ){
	    $self->Shotmap::Run::get_partitioned_samples( $project_dir ); 
	} else { #is actually a file
	    $self->Shotmap::Run::get_sample_from_file( $project_dir );
	}
    }
    else { $self->Shotmap::Notify::dryNotify("Skipped getting the samples for $project_dir."); }
        
    if( $self->use_db ) { 
        #have any of these samples been processed already? 
	$self->Shotmap::Run::check_prior_analyses( $self->opts->{"reload"} ); 
    }    
    if (!$dryRun) {
	$self->Shotmap::Run::load_project($project_dir );
	if(  $self->iso_db_build ){ #need to load db properties
	    $self->Shotmap::Run::cp_search_db_properties;
	}
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
	$self->remote_scripts_dir( $self->remote_project_path . "/scripts" ); 
	$self->remote_project_log_dir( File::Spec->catdir( $self->remote_project_path(), "logs") );
	
    }
}

1;
