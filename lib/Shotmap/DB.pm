#!/usr/bin/perl -w

#Shotmap::DB.pm - Database Interfacer
#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gladstone.ucsf.edu
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#    
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#    
#You should have received a copy of the GNU General Public License
#along with this program (see LICENSE.txt).  If not, see 
#<http://www.gnu.org/licenses/>.

package Shotmap::DB;

use strict;

use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Path qw(make_path rmtree);
#use DBIx::Class::ResultClass::HashRefInflator;
use DBI; #used only for DBIx::BulkLoader::Mysql
use DBD::mysql;
use DBIx::BulkLoader::Mysql; #Used only for multi-row inserts
use POSIX qw(ceil);
use XML::DOM;

#
# CONNECTION
#

#some DBI for speed
sub build_dbh{
    my( $self ) = @_;
    my $dbh = DBI->connect( $self->dbi_connection(), $self->db_user, $self->db_pass ) || die "Can't connect to database: " . $DBI::errstr;
    return $dbh; # <-- this return value actually gets used
}

sub disconnect_dbh{
    my( $self, $dbh ) = @_;
    $dbh->disconnect();
}

#
# SELECTS 
#

sub get_orf_from_alt_id{
    my $self = shift;
    my $orf_alt_id = shift;
    my $sample_id  = shift;
    my $orf = $self->get_schema->resultset('Orf')->find(
	{
	    orf_alt_id => $orf_alt_id,
	    sample_id  => $sample_id,
	},
#	{
#	    result_class => 'DBIx::Class::ResultClass::HashRefInflator',
#	}
    );
    return $orf;
}

sub get_family_from_famid{
    my $self = shift;
    my $famid = shift;
    my $family = $self->get_schema->resultset("Family")->find(
	{
	    famid => $famid,
	}	
	);
    return $family;
}

sub get_projects{
    my $self = shift;
    my $projects = $self->get_schema->resultset("Project");		    
    return $projects;
}

sub get_classification_id{
    my ( $self, $evalue, $coverage, $score, $ref_db_name, $algo, $top_hit_type ) = @_;
    my $method = $algo . ";" . "best_${top_hit_type}";
    my $inserted = $self->get_schema->resultset( "ClassificationParameter" )->find_or_create(
	{
	    evalue_threshold        => $evalue,
	    coverage_threshold      => $coverage,
	    score_threshold         => $score,
	    method                  => $method,
	    reference_database_name => $ref_db_name,
	}
	);
    return $inserted;
}

sub get_searchdb_id{
    my ( $self, $db_type, $db_name ) = @_;
    my $inserted = $self->get_schema->resultset( "Searchdatabase" )->find_or_create(
	{
	    db_type => $db_type,
	    db_name => $db_name,
	}
	);
    return $inserted;
}

sub get_families_by_searchdb_id{
    my( $self, $searchdb_id ) = @_;
    my $fams = $self->get_schema->resultset( "Family" )->search(
	{
	    searchdb_id => $searchdb_id,
	}
	);
    return $fams;    
}

sub get_familymembers_by_searchdb_id{
    my( $self, $searchdb_id ) = @_;
    my $fams = $self->get_schema->resultset( "Familymember" )->search(
	{
	    searchdb_id => $searchdb_id,
	}
	);
    return $fams;    
}

sub get_classification_parameters{
    my( $self, $class_id ) = @_;
    my $params = $self->get_schema->resultset( "ClassificationParameter" )->find(
	{
	    classification_id => $class_id,
	}
	);
    return $params;
}

sub get_number_orfs_by_project{
    my ($self, $project_id) = @_;
    my $samples = $self->get_schema->resultset('Sample')->search( { project_id => $project_id } );
    my $total      = 0;
    while( my $theSample = $samples->next() ){
	$self->Shotmap::Notify::notify("getting n_classified orfs from sample ID " . $theSample->id());
	my $count = $self->Shotmap::DB::get_number_orfs_by_samples( $theSample->id() );
	$total    += $count;
    }
    return $total;
}

sub get_number_orfs_by_samples{
    my ( $self, $sample_id ) = @_;
    my $orfs = $self->get_schema->resultset("Orf")->search(
	{
	    sample_id => $sample_id,
	}
    );
    return $orfs->count();

}

sub get_family_by_famid{
    my ( $self, $famid ) = @_;
    my $family = $self->get_schema->resultset("Family")->find(
	{
	    famid => $famid,
	}
	);
    return $family;
}

sub get_family_length{
    my( $self, $famid ) = @_;
    my $family_length = $self->get_schema->resultset("Annotation")->find(
	{
	    famid => $famid,
	}
	)->family_length;
    return $family_length;
}

sub get_target_length{
    my( $self, $target_id ) = @_;
    my $target_length = $self->get_schema->resultset("Familymember")->find(
	{
	    target_id => $target_id,
	}
	)->target_length;
    return $target_length;
}

sub get_sample_by_sample_id{
    my ($self, $sample_id) = @_;
    my $sample = $self->get_schema->resultset('Sample')->find(
	{
	  sample_id => $sample_id  
	}
    );
    return $sample;
}

sub get_orfs_by_sample_dbi{
    my( $self, $dbh, $sample_id ) = @_;
    my $sth = $dbh->prepare( 'SELECT orf_id, orf_alt_id, read_id FROM orfs WHERE sample_id = ?') || die "Can't prepare statement: " . $dbh->errstr;
    $sth->execute( $sample_id );
    return $sth;
}

sub get_orf_from_alt_id_dbi{
    my( $self, $dbh, $alt_id, $sample_id ) = @_;
    my $sth = $dbh->prepare( 'SELECT orf_id, orf_alt_id, read_id FROM orfs WHERE orf_alt_id = ? AND sample_id = ?') || die "Can't prepare statement: " . $dbh->errstr;
    $sth->execute( $alt_id, $sample_id );
    return $sth;
}

#
sub get_classified_orfs_by_sample{
    my ( $self, $sample_id, $class_id, $dbh, $count ) = @_; #if count is defined, subsample using the metareads table
    my $sql;
    if( !defined( $count) ){
	$sql = "SELECT * FROM classifications WHERE sample_id = ${sample_id} and classification_id = ${class_id}";
    }
    else{
	#rarefy based on metareads
	$sql = "SELECT b.result_id, b.orf_alt_id, b.read_alt_id, b.sample_id, " .
	    "b.target_id, b.famid, b.classification_id, b.aln_length, b.score " .
	    "FROM " .
	    "(SELECT * FROM metareads WHERE sample_id = ${sample_id} order by rand() limit ${count}) a " .
	    "JOIN classifications b ON a.read_alt_id=b.read_alt_id " .
	    "WHERE b.sample_id = ${sample_id} and classification_id = ${class_id}";
	#can add rarefaction based on orfs or classified orfs below, if desired
    }
    $self->Shotmap::Notify::print_verbose( "$sql\n" );
    my $sth = $dbh->prepare($sql) || die "SQL Error: $DBI::errstr\n";
    $sth->execute();
    return $sth;
}

sub get_orf_by_orf_id{
    my ($self, $orf_id) = @_;
    my $orf = $self->get_schema->resultset('Orf')->find(
	{
	    orf_id => $orf_id,
	}
	);
    return $orf;
}

sub get_reads_by_sample_id{
    my $self = shift;
    my $sample_id = shift;
    my $get_random = shift; #1 or 0, may be undef
    my $rand_row_num = shift; #num rows to grab if get_random is set
    my $reads;
    if( defined( $get_random ) && $get_random ){
	if( !defined( $rand_row_num ) ){
	    $rand_row_num = 1;
	}
	$reads = $self->get_schema->resultset('Metaread')->search(
	    {
		sample_id => $sample_id,
	    }
	    )->rand( $rand_row_num );
    }
    else{
	$reads = $self->get_schema->resultset('Metaread')->search(
	    {
		sample_id => $sample_id,
	    }
	    );
    }	
    return $reads;
}

sub get_read_alt_id_by_read_id{
    my $self = shift;
    my $read_id = shift;
    my $read = $self->get_schema->resultset('Metaread')->find(
	{
	    read_id => $read_id,
	}
    );
    my $read_alt_id = $read->read_alt_id();
    return $read_alt_id;
}

sub get_orfs_by_read_id{ 
    my $self = shift;
    my $read_id = shift;
    my $orfs = $self->get_schema->resultset("Orf")->search(
	{
	    read_id => $read_id,
	}
    );
    return $orfs;
}

sub get_orfs_by_sample{
    my ( $self, $sample_id, $page ) = @_;
    my $orfs = $self->get_schema->resultset("Orf")->search( 
	{
	    sample_id => $sample_id,

	},
	);    
    return $orfs;
}

sub get_sample_by_alt_id{
    my $self = shift;
    my $sample_alt_id = shift;
    my $sample = $self->get_schema->resultset('Sample')->find( { sample_alt_id => $sample_alt_id } );
    return $sample;
}

sub get_samples_by_project_id{
    my $self    = shift;
    my $samples = $self->get_schema->resultset("Sample")->search(
	{
	    project_id => $self->project_id(),
	}
    );
    return $samples;
}

sub get_family_members_by_famid{
    my $self    = shift;
    my $famid   = shift;
    my $members = $self->get_schema->resultset("Familymember")->search(
	{
	    famid => $famid,
	}
    );
    return $members;
}


sub get_abundance_parameter_id{
    my ( $self, $abund_type, $norm_type ) = @_; 
    my ( $rarefaction_depth);
    my $rarefaction_type = $self->rarefaction_type;
    if( defined( $self->postrarefy_samples ) ){ #post rarefaction is always smallest
	$rarefaction_depth = $self->postrarefy_samples;
    } elsif( defined( $self->prerarefy_samples ) ){
	$rarefaction_depth = $self->prerarefy_samples;
    }
    my $inserted = $self->get_schema->resultset( "AbundanceParameter" )->find_or_create(
	{
	    abundance_type        => $abund_type,
	    normalization_type    => $norm_type,
	    rarefaction_depth     => $rarefaction_depth,
	    rarefaction_type      => $rarefaction_type,
	}
	);
    return $inserted;
}

sub get_sample_abundance{
    my( $self, $sample_id, $class_id, $abund_param_id ) = @_;
    my $inserted = $self->get_schema->resultset("Abundance")->search(
	{
	    sample_id               => $sample_id,
	    abundance_parameter_id  => $abund_param_id,
	    classification_id       => $class_id,
	}
	);
    return $inserted;
}    

sub get_sample_abundances_for_all_classed_fams{
    my ( $self, $dbh, $sample_id, $class_id, $abund_param_id ) = @_;
    my $sql = "SELECT a.famid, b.sample_id, b.abundance, b.relative_abundance FROM " .
	"(SELECT DISTINCT famid FROM abundances) a LEFT OUTER JOIN abundances b ON a.famid = b.famid AND b.sample_id = ${sample_id} " .
	"AND b.classification_id = ${class_id} AND b.abundance_parameter_id = ${abund_param_id} ";
    $self->Shotmap::Notify::print_verbose( $sql . "\n" );
    my $sth = $dbh->prepare($sql) || die "SQL Error: $DBI::errstr\n";
    $sth->execute();
    return $sth;
}

sub get_abundance_parameters{
    my( $self, $abund_param_id ) = @_;
    my $params = $self->get_schema->resultset("AbundanceParameter")->find(
	{
	    abundance_parameter_id => $abund_param_id,
	}
	);
    return $params
}

#
# INSERTS
#

sub insert_search_result{
    my ( $self, $orf_id, $famid, $evalue, $score, $coverage ) = @_;
    my $inserted = $self->get_schema->resultset("Searchresult")->create(
	{
	    orf_id => $orf_id,
	    famid => $famid,
	    evalue => $evalue,
	    score  => $score,
	    other_searchstats => "coverage=${coverage}",
	}
	);
    return $inserted;
}

sub load_annotations{

}

sub insert_abundance{
    my( $self, $sample_id, $famid, $abundance, $relative_abundance, $abundance_parameter_id, $class_id ) = @_;
    my $inserted = $self->get_schema->resultset("Abundance")->find_or_create(
	{
	    sample_id               => $sample_id,
	    famid                   => $famid,
	    abundance               => $abundance,
	    relative_abundance      => $relative_abundance,
	    abundance_parameter_id  => $abundance_parameter_id,
	    classification_id       => $class_id,
	},
	);
    return $inserted;
}

sub insert_sample_diversity{
    my( $self, $sample_id, $class_id, $abund_param_id, $richness, $shannon, $goods_coverage ) = @_;
    my $inserted = $self->get_schema->resultset("Diversity")->find_or_create(
	{
	    sample_id               => $sample_id,
	    class_id                => $class_id,
	    abundance_parameter_id  => $abund_param_id,
	    richness                => $richness,
	    shannon_entropy         => $shannon,
	    goods_coverage          => $goods_coverage,
	}
	);
    return $inserted;
}

sub create_multi_metareads{
    my $self          = shift;
    my $sample_id     = shift;
    my $ra_read_names = shift;
    $self->Shotmap::Notify::print_verbose( "Bulk loading reads from sample $sample_id\n" );
    my @read_names    = @{ $ra_read_names };
    my $sql_insert    = 'INSERT INTO metareads ( sample_id, read_alt_id ) values ';
    my $placeholders  = '(?,?)';
    my $dbh = DBI->connect( $self->dbi_connection(), $self->db_user, $self->db_pass );
    my( $bulk, $error ) = DBIx::BulkLoader::Mysql->new(
	dbh          => $dbh,
	sql_insert   => $sql_insert,
	placeholders => $placeholders
	);
    die $error unless $bulk;
    foreach my $read_name( @read_names ){
	$bulk->insert( $sample_id, $read_name );
    }
    $bulk->flush();
    if (defined $dbh->errstr) { die($dbh->errstr . " "); }
    return $self;
}

sub insert_orf{
    my $self       = shift;
    my $orf_alt_id = shift;
    my $read_id    = shift;
    my $sample_id  = shift;
    my $orf = $self->get_schema->resultset("Orf")->create(
	{
	    read_id    => $read_id,
	    sample_id  => $sample_id,
	    orf_alt_id => $orf_alt_id,
	}
    );
}

sub insert_multi_orfs{
    my $self          = shift;
    my $sample_id     = shift;
    my $rh_orf_map    = shift; #orf_alt_id -> read_id
    $self->Shotmap::Notify::notify("Bulk loading orfs from sample ID $sample_id");
    my %orf_map       = %{ $rh_orf_map };
    my $sql_insert    = 'INSERT INTO orfs ( sample_id, read_id, orf_alt_id ) values ';
    my $placeholders  = '(?,?,?)';
    my $dbh = DBI->connect( $self->dbi_connection(), $self->db_user, $self->db_pass );
    my( $bulk, $error ) = DBIx::BulkLoader::Mysql->new(
	dbh          => $dbh,
	sql_insert   => $sql_insert,
	placeholders => $placeholders
	);
    
    if (!$bulk) { die $error; }

    foreach my $orf_alt_id( keys( %orf_map ) ){
	$bulk->insert( $sample_id, $orf_map{ $orf_alt_id }, $orf_alt_id );
    }
    $bulk->flush();
    if (defined($dbh->errstr)) {
	die($dbh->errstr . " ");
    }    
}

sub create_project{
    my $self = shift;
    my $name = shift;
    my $text = shift;
    my $proj_rs = $self->get_schema->resultset("Project");
    my $inserted = $proj_rs->create(
	{
	    name => $name,
	    description => $text,
	}
	);
    return $inserted;
}

sub create_sample{
    my $self = shift;
    my $sample_name = shift;
    my $project_id  = shift;    
    my $metadata    = shift;
    my $proj_rs = $self->get_schema->resultset("Sample");
    my $inserted = $proj_rs->create(
	{
	    sample_alt_id => $sample_name,
	    project_id    => $project_id,
	    metadata      => $metadata,
	}
	);
    return $inserted;
}

sub create_metaread{
    my $self = shift;
    my $read_name = shift;
    my $sample_id = shift;
    my $proj_rs = $self->get_schema->resultset("Metaread");
    my $inserted = $proj_rs->create(
	{
	    sample_id => $sample_id,
	    read_alt_id => $read_name,
	}
	);
    return $inserted;
}

#
# DELETES
#

sub delete_project{
    my $self       = shift;
    my $project_id = shift;
    my $project   = $self->get_schema->resultset("Project")->search(
	{
	    project_id => $project_id,
	}
	);
    $project->delete();
    return $self;
}

sub delete_orfs_by_sample_id{
    my $self = shift;
    my $sample_id = shift;
    my $orfs = $self->get_schema->resultset("Orf")->search(
	{
	    sample_id => $sample_id,
	}
    );
    $orfs->delete();
    return $self;
}

sub delete_search_result_by_sample_id{
    my $self      = shift;
    my $sample_id = shift;
    my $orfs = $self->get_schema->resultset("Orf")->search(
	{
	    sample_id => $sample_id,
	}
    );
    while( my $orf = $orfs->next() ){
	my $orf_id = $orf->orf_id();
	$self->Shotmap::DB::delete_search_result_by_orf_id( $orf_id );	
    }
    return $self;
}

sub delete_search_result_by_orf_id{
    my $self   = shift;
    my $orf_id = shift;
    my $search_results  = $self->get_schema->resultset("Searchresult")->search(
	{
	    orf_id => $orf_id,
	}
	);
    while( my $search_result = $search_results->next() ){
	$search_result->delete();
    }
    return $self;
}

sub delete_reads_by_sample_id{
    my $self = shift;
    my $sample_id = shift;
    my $reads = $self->get_schema->resultset("Metaread")->search(
	{
	    sample_id => $sample_id,
	}
    );
    $reads->delete();
}

sub delete_sample{
    my $self = shift;
    my $sample_id = shift;
    my $sample = $self->get_schema->resultset("Sample")->search(
	{
	    sample_id => $sample_id,
	}
	);
    $sample->delete();
}

#
# FFDB METHODS
#

sub delete_ffdb_project{
    my $self       = shift;
    my $project_id = shift;
    my $ffdb = $self->ffdb();
    my $project_ffdb = "$ffdb/projects/$project_id";
    File::Path::rmtree($project_ffdb);
}

sub delete_unsplit_orfs{
    my $self       = shift;
    my $project_id = shift;
    my $ffdb       = $self->ffdb();
    my $samples    = $self->get_sample_ids();
    foreach my $sample( @$samples ){
	my $path = $self->get_sample_path( $sample ) . "/unsplit_orfs/";
	if( -d $path ){
	    $self->Shotmap::Notify::print( "Deleting $path\n" );
	    File::Path::rmtree($path);
	}
    }
}

#delete's a subdirectory within a sample's ffdb within a project
sub delete_sample_subpath{ 
    my $self       = shift;
    my $subpath    = shift; #e.g., "/unsplit_orfs/" or "/search_results/rapsearch/"
    my $project_id = $self->project_id;
    my $ffdb       = $self->ffdb();
    my $samples    = $self->get_sample_ids();
    foreach my $sample( @$samples ){
	my $path = $self->get_sample_path( $sample ) . $subpath;
	if( -d $path ){
	    $self->Shotmap::Notify::print( "Deleting ${path}\n" );
	    File::Path::rmtree($path);
	}
    }
}    

sub get_number_reads_in_sample{
    my ($self, $sample) = @_;
    my $reads  = $self->Shotmap::DB::get_reads_by_sample_id( $sample );
    return $reads->count();
}

sub get_read_ids_from_ffdb{
    my ( $self, $sample_id ) = @_;
    my @read_ids             = ();
    my $ffdb_reads_dir       = File::Spec->catfile($self->Shotmap::get_sample_path( $sample_id ), "raw" );
    my @read_files           = glob( $ffdb_reads_dir . "/*.fa" );
    foreach my $file( @read_files ){
	open( FILE, $file ) || die "Can't open $file for read: $!\n";
	while(<FILE>){
	    next unless( $_ =~ m/^\>(.*?)(\s|$)/ );
	    my $read_id = $1;
	    push( @read_ids, $read_id );
	}
	close FILE;
    }
    return \@read_ids;
}

sub build_db_ffdb {    # This appears not to actually BUILD anything, it just makes a directory.
    my ($self, $path) = @_;
    if (-d $path){
	$self->Shotmap::Notify::notify("For whatever reason, we are removing the entire directory in <$path>, in build_db_ffdb.");
	File::Path::rmtree( $path );
    }
    File::Path::make_path( $path );
}

sub get_number_db_splits{
    my ( $self, $type ) = @_;
    my $n_splits = 0;
    my $db_path;
    if( $type eq "hmm" ) {       $db_path = $self->search_db_path("hmm");
    } elsif( $type eq "blast" ){ $db_path = $self->search_db_path("blast");
    } else { die "invalid $type"; }

    opendir( DIR, $db_path ) || die "Can't opendir <$db_path> for readng: $! ";
    my @files = readdir( DIR );
    closedir( DIR );

    # Note that "@files" also includes the "fake" files '.' and '..'
    foreach my $file( @files ){
	#don't want to count both the uncompressed and the compressed, so look for the .gz ending on file name
	next unless($file =~ m/\.gz$/); # ONLY look for files that end in '.gz'
	$n_splits++;
    }
    #total number of sequences/models across the entire database (to correctly scale evalue)
    return $n_splits;
}

#for hmmscan -Z correction
sub get_number_hmmdb_scans{
    my ( $self, $n_seqs_per_db_split ) = @_;
    my $n_splits = 0;
    opendir( DIR, $self->search_db_path("hmm") ) || die "Can't opendir " . $self->search_db_path("hmm") . " for read: $! ";
    my @files = readdir( DIR );  # <-- Note that "@files" also includes the "fake" files '.' and '..'
    closedir( DIR );
    foreach my $file( @files ){
	#don't want to count both the uncompressed and the compressed, so look for the .gz ending on file name
	next unless( $file =~ m/\.gz$/ );
	$n_splits++;
    }
    #total number of sequences/models across the entire database (to correctly scale evalue)
    #want orfs, so multiply by 6 if using "transeq"
    my $n_seqs = $n_splits * $n_seqs_per_db_split * 6;
    return $n_seqs;
}

#for hmmsearch
sub get_number_sequences{
    my( $self, $n_sequences_per_split ) = @_;
    my $n_splits = 0;
    my $last_split_counts = 0;
    foreach my $sample_id( @{ $self->get_sample_ids() } ){
	my $orfDir = $self->ffdb() . "/projects/" . $self->project_id() . "/$sample_id/orfs";
	opendir( DIR, $orfDir ) || die "Can't opendir $orfDir for read: $! ";
	my @files = readdir( DIR );  # <-- Note that "@files" also includes the "fake" files '.' and '..'
	closedir( DIR );	
	my $max_split_filename; #points to last split's file name
	my $max_splitnum = 0; # no idea why this starts at zero
	foreach my $file( @files ){
	    next unless($file =~ m/split_(\d+)\.fa/); # only count things that match a very specific file pattern
	    my $splitnum      = $1; 	    #need to find the last split's file name
	    if($splitnum > $max_splitnum){
		$max_split_filename    = $file;
		$max_splitnum = $splitnum; # this is a weird way to do it but I guess it works!
	    }
	    $n_splits++;
	}
	open(MAX, "$orfDir/$max_split_filename") || die "Can't read max split file ${max_split_filename} for reading in get_number_sequences: $! ";
	my $caretCount = 0;
	while(<MAX>) {
	    if($_ =~ m/\>/) { $caretCount++; } # count number of lines with a > on them. Apparently not just ones that START with a >! Possibly should change this to require STARTING with a >, but maybe it doesn't actually matter.
	}
	close MAX;
	$last_split_counts = $last_split_counts + $caretCount;
    }
    #want orfs, so multiply by 6 if using "transeq". Last split needs to be counted for accuracy (may not have full split size).
    #the last split issue happens for each sample, so it is a sum of the number of seqs in each sample's last split. 
    my $n_samples = @{ $self->get_sample_ids() };
    my $n_seqs = ( ( ( $n_splits - ( 1 * $n_samples ) ) * $n_sequences_per_split )  * 6 ) + $last_split_counts; # what is up here
    return $n_seqs;
}

#for blast
sub get_blast_db_length{
    my($self, $db_name) = @_;
    my $length  = 0;
    my $db_path = $self->search_db_path("blast");
    my $db_length_filename = "$db_path/database_length.txt";
    if( -e $db_length_filename ){
	open( IN, $db_length_filename ) or die "Can't open ${db_length_filename} for reading: $! ";
	while(<IN>) {
	    chomp $_; ## mysterious
	    $length = $_;
	}
	close IN;
    } else {
	$length = $self->Shotmap::Run::calculate_blast_db_length();
    }
    return $length;
}

sub build_project_ffdb {
    my ($self) = @_;
    my $ffdb    = $self->{"ffdb"};
    my $db_name = $self->{"dbname"};
    my $pid     = $self->{"project_id"};
    my $proj_dir = "$ffdb/projects/$db_name/$pid";
    $self->project_dir($proj_dir);
    File::Path::make_path($proj_dir); 
    my $params_dir    = "$proj_dir/parameters";
    File::Path::make_path($params_dir); 
    $self->params_dir( $params_dir );
    $self->params_file( $params_dir . "/parameters.xml" );
    $self->Shotmap::DB::initialize_parameters_file( $self->params_file );

    #or die "Can't create new directory <$proj_dir> in build_project_ffdb: $! ";
}

sub build_sample_ffdb{
    my ($self)  = @_;
    my $ffdb    = $self->ffdb();
    my $pid     = $self->project_id();
    my $projDir = $self->project_dir;
    my $outDir  = "$projDir/output";
    my $logDir  = "$projDir/logs";
    my $searchlogs = "$logDir/" . $self->search_method;    
    #my $hmmscanlogs      = "$logDir/hmmscan";
    #my $hmmsearchlogs    = "$logDir/hmmsearch";
    #my $blastlogs        = "$logDir/blast";
    #my $lastlogs         = "$logDir/last";
    #my $rapsearchlogs    = "$logDir/rapsearch";
    my $formatdblogs;
    if( $self->search_method eq "rapsearch" ){
	$formatdblogs = "$logDir/prerapsearch";
    }
    if( $self->search_method eq "blast" ){
	$formatdblogs = "$logDir/formatdb";
    }
    if( $self->search_method eq "last" ){
	$formatdblogs = "$logDir/lastdb";
    }   
    #my $formatdblogs     = "$logDir/formatdb";
    #my $lastdblogs       = "$logDir/lastdb";
    #my $prerapsearchlogs = "$logDir/prerapsearch";
    my $transeqlogs      = "$logDir/transeq";
    my $parselogs        = "$logDir/parse_results";
    my @paths = ( $outDir, $logDir, $searchlogs, $transeqlogs, $parselogs );
    if( defined( $formatdblogs ) ){
	push( @paths, $formatdblogs );
    }
    foreach my $path (@paths) {
	File::Path::make_path($path);
    }
    foreach my $sampleName (keys(%{$self->get_sample_hashref()})) {
	my $thisSampleID = $self->get_sample_hashref()->{$sampleName}->{"id"};
	my $sampDir      = "$projDir/${thisSampleID}";
	my $raw_sample_dir  = "$sampDir/raw";
	my $orf_sample_dir  = "$sampDir/orfs";
	my $search_res      = "$sampDir/search_results";
	my $unsplit_orfs    = "$sampDir/unsplit_orfs"; #not always used, always created in case used in alternative run

	my $results_dir     = $search_res . "/" . $self->search_method;

	#my $hmmscan_results   = "$search_res/hmmscan";
	#my $hmmsearch_results = "$search_res/hmmsearch";
	#my $blast_results     = "$search_res/blast";
	#my $last_results      = "$search_res/last";
	#my $rapsearch_results = "$search_res/rapsearch";

	if (-d $raw_sample_dir) {
	    warn("The directory \"$raw_sample_dir\" already existed!");
	    if ($self->{"clobber"}) { warn("But you specified the CLOBBER option, so we will brutally overwrite it anyway!"); }
	    else { die("Since the data already exists in $raw_sample_dir , we will not overwrite it! Unless you specify the flag --clobber to brutally clobber those directories anyway. NOT RECOMMENDED unless you know what you're doing."); }
	}

	foreach my $dirToMake ($sampDir, $search_res, $results_dir, $raw_sample_dir, $orf_sample_dir, $unsplit_orfs) {
	#foreach my $dirToMake ($sampDir, $search_res, $hmmscan_results, $hmmsearch_results, $blast_results, $last_results, $rapsearch_results, $raw_sample_dir, $orf_sample_dir, $unsplit_orfs) {
	    File::Path::make_path($dirToMake); # <-- make_path ALREADY dies on "severe" errors, so no need to check for them. See http://search.cpan.org/~dland/File-Path-2.09/Path.pm#ERROR_HANDLING
	}
	my $nameprefix = "${sampleName}_raw_split_"; # the "base name" here.
	$self->Shotmap::DB::split_sequence_file( $self->get_sample_hashref()->{$sampleName}->{"path"}, $raw_sample_dir, $nameprefix );
    }
}

sub split_sequence_file{
    my $self             = shift;
    my $full_seq_file    = shift;
    my $split_dir        = shift;
    my $basename         = shift;
    my $nseqs_per_split;
    if( $self->remote ){
	$nseqs_per_split  = $self->read_split_size();
    } else {
	my $total_reads  = $self->Shotmap::Run::count_seqs_in_file( $full_seq_file );
	$nseqs_per_split = ceil($total_reads / $self->nprocs()  ); #round up to nearest integer to be sure we get all reads
    }
    #a list of filenames
    my @output_names = ();
    open( SEQS, $full_seq_file ) || die "Can't open $full_seq_file for read in Shotmap::DB::split_sequence_file_no_bp\n";
    my $counter  = 1;
    my $outname  = $basename . $counter . ".fa";
    my $splitout = $split_dir . "/" . $outname;
    open( OUT, ">$splitout" ) || die "Can't open $splitout for write in Shotmap::DB::split_sequence_file_no_bp\n";
    push( @output_names, $outname );
    $self->Shotmap::Notify::print_verbose( "Will dump to split $splitout\n" );
    my $seq_ct   = 0;
    my $header   = ();
    my $sequence = ();
    my $seq_count_across_splits = 0;
    while( <SEQS> ){
	#have we reached the prerarefy sequence count, if that is set?
	if( defined( $self->Shotmap::prerarefy_samples() ) && $seq_count_across_splits == $self->Shotmap::prerarefy_samples() ){
	    last;
	}	   
	chomp $_;
	if( $_ =~ m/^(\>.*)/ ){
	    if( defined( $header ) ){
		print OUT "$header\n$sequence\n";
		$seq_ct++;
		$seq_count_across_splits++;
		$sequence = ();
	    }
	    $header = $1;
	}
	else{
	    $sequence = $sequence . $_;
	}
	if( eof ) {
	    print OUT "$header\n$sequence\n";	    
	}
	if( $seq_ct == $nseqs_per_split ){	
	    close OUT;
	    $counter++;
	    my $outname  = $basename . $counter . ".fa";
	    my $splitout = $split_dir . "/" . $outname;
	    unless( eof ){
		open( OUT, ">$splitout" ) || die "Can't open $splitout for write in Shotmap::DB::split_sequence_file_no_bp\n";
		push( @output_names, $outname );
		$self->Shotmap::Notify::print_verbose( "Will dump to split $splitout\n" );
		$seq_ct = 0;
	    }
	}
    }    
    close OUT;
    close SEQS;
    return \@output_names;
}

sub get_split_sequence_paths {
    # this could probably be a call to "glob(...)"
    my ($self, $base_directory, $should_use_full_path) = @_;
    my @paths = ();
    opendir(DIR, $base_directory) or die "Error in Shotmap::DB::get_split_sequence_paths: Can't opendir $base_directory for read: $! ";
    my @files = readdir( DIR );
    closedir( DIR );
    foreach my $file( @files ){
	next if( $file =~ m/^\./ ); # don't include '.' and '..' files (or any other dot-whatever file)
	my $newPath = (defined($should_use_full_path) && $should_use_full_path) ? "$base_directory/$file" : "$file"; # use the FULL path, or just the filename?
	push(@paths, $newPath);
    }
    return \@paths; # apparently returns an array to all the ... paths
}

sub get_hmmdbs{
    my $is_remote  = 0; # what is up with this. This is a default value I guess?
    my $self       = shift;
    my $hmmdb_name = shift;
    $is_remote = shift;

    my $ffdb = $self->ffdb();
    my $hmmdb_local_path = "$ffdb/HMMdbs/$hmmdb_name";
    opendir( HMMS, $hmmdb_local_path ) || die "Can't opendir $hmmdb_local_path for read: $! ";
    my @files = readdir(HMMS);
    closedir( HMMS );
    my %hmmdbs = ();
    foreach my $file ( @files ){
	next if( $file =~ m/^\./ ); # skip the fake "." and ".." files
	next if( $file =~ m/\.h3[i|m|p|f]/ );
	#if grabbing from remote server, use the fact that HMMdb is a mirror to get proper remote path
	if ($is_remote) {
	    $hmmdbs{$file} = $self->remote_ffdb() . "/HMMdbs/$hmmdb_name/$file";
	} else {
	    $hmmdbs{$file} = "$hmmdb_local_path/$file";
	}
    }
    $self->Shotmap::Notify::notify("Grabbed " . scalar(keys(%hmmdbs)) . " HMM dbs from $hmmdb_local_path");
    return \%hmmdbs;
}


#
# METHODS
#

sub get_max_column_value{
    my( $self, $table, $column ) = @_;
    my $maxvalue = $self->get_schema->resultset($table)->get_column($column)->max;
    return $maxvalue;
}


#This is a complicated series of queries for DBIx. I'm sure someone knows how to do this efficiently in DBIx, but I don't. So, I'll use DBI.
sub classify_orfs_by_sample{
    my ( $self, $sample_id, $class_id, $dbh, $count ) = @_; #if count is defined, subsample using the metareads table
    #get the classification parameters
    my $class_params = $self->Shotmap::DB::get_classification_parameters( $class_id );
    my $class_method = $class_params->method;
    my ($algo, $best_type);
    if( $class_method =~ m/^(.*?);(.*?)$/ ){
	$algo         = $1;
	$best_type    = $2;
    } else{
	die( "Could not parse the classification method string from classification_parameters table. Got <${class_method}>\n" );
    }
    my $sql; #will differ depending on what we want to grab.
    $sql = "INSERT IGNORE INTO classifications ( score, orf_alt_id, read_alt_id, sample_id, target_id, famid, aln_length, classification_id ) ";
    if( !defined( $count ) ){ #grab results for all read
	$sql .= "SELECT MAX( score ) AS score, orf_alt_id, read_alt_id, sample_id, target_id, famid, aln_length, ${class_id} FROM searchresults WHERE sample_id = ${sample_id} "; #note that we want the proper class_id, not the one from searchresults
	if( defined( $class_params->evalue_threshold ) ){
	    $sql .= " AND evalue <= " . $class_params->evalue_threshold . " ";
	}

	if( defined( $class_params->score_threshold ) ){
	    $sql .= " AND score >= " . $class_params->score_threshold . " ";
	}
	if( defined( $class_params->coverage_threshold) ){
	    $sql .= " AND orf_coverage >= " . $class_params->coverage_threshold . " ";
	}
	if( $best_type eq "best_read" ){
	    $sql .= " GROUP BY read_alt_id ORDER BY score DESC ";
	} elsif( $best_type eq "best_orf" ){
	    $sql .= " GROUP BY orf_alt_id ORDER BY score DESC ";
	} else {
	    die( "There seems to be a best_type in your database that I don't know about. We parsed <${best_type}> from the method string <{$class_method}> using class_id $class_id\n" );
	}
    } else{ #here we post-rare from metareads table. May not be necessary, since we can also do this in
	    # DB::get_classified_orfs_by_sample. But, also doin here keeps from classifying unnecessary data...OA
	$sql  .= "SELECT MAX( score ) AS score, orf_alt_id, tab2.read_alt_id, tab2.sample_id, target_id, famid, aln_length, ${class_id} FROM ";
	$sql .= "( SELECT * FROM metareads WHERE sample_id = ${sample_id} ORDER BY RAND() LIMIT ${count} ) tab1 ";
	$sql .= "JOIN searchresults tab2 on tab1.read_alt_id = tab2.read_alt_id ";
	$sql .= "WHERE tab2.sample_id = ${sample_id} "; #redundant, but enable easy extension of the clauses below
	if( defined( $class_params->evalue_threshold ) ){
	    $sql .= " AND evalue <= " . $class_params->evalue_threshold . " ";
	}
	if( defined( $class_params->score_threshold ) ){
	    $sql .= " AND score >= " . $class_params->score_threshold . " ";
	}
	if( defined( $class_params->coverage_threshold) ){
	    $sql .= " AND orf_coverage >= " . $class_params->coverage_threshold . " ";
	}
	if( $best_type eq "best_read" ){
	    $sql .= " GROUP BY read_alt_id ORDER BY score DESC ";
	} elsif( $best_type eq "best_orf" ){
	    $sql .= " GROUP BY orf_alt_id ORDER BY score DESC ";
	} else {
	    die( "There seems to be a best_type in your database that I don't know about. We parsed <${best_type}> from the method string <{$class_method}> using class_id $class_id\n" );
	}
    }
    $self->Shotmap::Notify::print_verbose( "$sql\n" );
    my $sth = $dbh->prepare($sql) || die "SQL Error: $DBI::errstr\n";
    $sth->execute();
    return $sth;
}


#
# BULK IMPORT
#

#note, must have local import permissions in mysql. 
#also, server AND client must have local_infile=1
sub bulk_import{
    my $self   = shift;
    my $table  = shift;
    my $file   = shift;
    my $out    = shift;
    my $nrows  = shift;
    my $fks    = shift; #hash ref of foreign keys
    my $ra_fields    = shift;
    my @fields       = @{ $ra_fields };
    my $field_string = join(",", @fields );
    $field_string    =~ s/\,$//;
    #get a connection
    my $dbh  = DBI->connect( $self->dbi_connection() . ";mysql_local_infile=1", $self->db_user, $self->db_pass )
	|| die "Couldn't connect to the database: " . DBI->errstr;

    #split the file into batches of $nrow and insert
    if( $table eq "metareads" ){
	my $sample_id = $fks->{"sample_id"};
	my $count = 0;
	my $inserts = 0;
	my @rows  = ();
	open( SEQS, "$file" ) || die "Can't open $file for read in Shotmap::DB::bulk_import\n";
	my $run = 0;
	while( <SEQS> ){
	    chomp $_;
	    if( $_ =~ m/^\>(.*?)(\s|$)/ ){
		my $read_alt_id = $1;
		my $tot_chars   = (); #need to keep track of the raw sequence string for seeking
		my $seq         = ();
		my $in          = 0; #have we moved past current sequence header and into seq?
		while( <SEQS> ){ #let's get the sequence for this header
		    if( $in && ( $_ =~ m/^\>/ || eof ) ){ #check to see if current line is the next seq. if so, break loop.
			$seq =~ s/\n//g;
			seek( SEQS, -length( $tot_chars ), 1 );
			last;
		    }
		    $in = 1;
		    $tot_chars = $tot_chars . $_; #keep track of the file bits
		    $seq       = $seq . $_; #append the sequence
		}
		push ( @rows, "$sample_id,$read_alt_id,$seq" );
		$count++;
	    }
	    if( eof || $count == $nrows ){
		$run++;
		open( OUT,  ">$out" ) || die "Can't open $out for write in Shotmap::DB::bulk_import\n";
		print OUT join( "\n", @rows );
		close OUT;
		my $sql = "LOAD DATA LOCAL INFILE '" . $out . "' INTO TABLE " . $table . " FIELDS TERMINATED BY ',' " . 
		    "LINES TERMINATED BY '\\n' ( sample_id, read_alt_id, seq )";
		#join(",", @fields) . ")";
		my $sth = $dbh->do($sql) || die "SQL Error: $DBI::errstr\n";
		$inserts = $inserts + $sth;
		$count = 0;
		@rows  = ();
		unlink( $out );
	    }
	}
	close SEQS;
	$self->Shotmap::Notify::print_verbose( $inserts . " records inserted\n" );
    }	
    if( $table eq "orfs" ){
	my $sample_id = $fks->{"sample_id"};
	my $count = 0;
	my $inserts = 0;
	my @rows  = ();
	open( SEQS, "$file" ) || die "Can't open $file for read in Shotmap::DB::bulk_import\n";
	my $run = 0;
	my $read_map = {}; #use to decrease the number of DB lookups
	while( <SEQS> ){
	    chomp $_;
	    if( $_ =~ m/^\>(.*)(\s|$)/ ){ 
		my $orf_alt_id = $1;
		my $read_alt_id = $self->Shotmap::Run::parse_orf_id( $orf_alt_id, $fks->{"method"} );
		my $read_id     = $self->Shotmap::Run::read_alt_id_to_read_id( $read_alt_id, $sample_id, $read_map ); 
		$read_map->{ $read_alt_id } = $read_id;
		push ( @rows, "$sample_id,$read_id,$orf_alt_id" );
		$count++;
	    }
	    if( eof || $count == $nrows ){
		$run++;
		open( OUT,  ">$out" ) || die "Can't open $out for write in Shotmap::DB::bulk_import\n";
		print OUT join( "\n", @rows );
		close OUT;
		my $sql = "LOAD DATA LOCAL INFILE '" . $out . "' INTO TABLE " . $table . " FIELDS TERMINATED BY ',' " . 
		    "LINES TERMINATED BY '\\n' ( sample_id, read_alt_id, orf_alt_id )";
		my $sth = $dbh->do($sql) || die "SQL Error: $DBI::errstr\n";
		$inserts = $inserts + $sth;
		$count = 0;
		@rows  = ();
		unlink( $out );
	    }
	}
	close SEQS;
	$self->Shotmap::Notify::print( $inserts . " records inserted\n" );
    }    
    if( $table eq "familymembers_slim" ){
	#here, $file is actually the hit_map hashref from 
	my $orf_hits          = $file;
	my $sample_id         = $fks->{"sample_id"};
	my $classification_id = $fks->{"classification_id"};
	my $count = 0;
	my $inserts = 0;
	my @rows  = ();
	foreach my $orf_alt_id( keys( %$orf_hits ) ){
	    my $famid = $orf_hits->{$orf_alt_id};
	    push ( @rows, "$famid,$orf_alt_id,$sample_id,$classification_id" );
	    $count++;
	    
	    if( eof || $count == $nrows ){
		open( OUT,  ">$out" ) || die "Can't open $out for write in Shotmap::DB::bulk_import\n";
		print OUT join( "\n", @rows );
		close OUT;
		my $sql = "LOAD DATA LOCAL INFILE '" . $out . "' INTO TABLE " . $table . " FIELDS TERMINATED BY ',' " . 
		    "LINES TERMINATED BY '\\n' ( famid_slim, orf_alt_id_slim, sample_id, classification_id )";
		my $sth = $dbh->do($sql) || die "SQL Error: $DBI::errstr\n";
		$inserts = $inserts + $sth;
		$count = 0;
		@rows  = ();
		unlink( $out );
	    }
	}
    }
    if( $table eq "searchresults" ){ #THE TABLE DATA IS ASSEMBLED ELSEWHERE, WE SIMPLY OPTIMIZE DB PINGS WITH THIS ROUTINE
	my $count    = 0;
	my $inserts  = 0;
	my @rows     = ();
	my $class_id = $fks->{"classification_id"};
	open( TAB, "$file" ) || die "Can't open $file for read in Shotmap::DB::bulk_import\n";
	my $run = 0;
	$self->Shotmap::Notify::print_verbose( "Loading data from $file\n" );
	while( <TAB> ){
	    chomp $_;
	    my $row   = $_ . "," . $class_id;
	    my $col_count = ($row =~ tr/\,//);
	    if( $col_count < scalar(@fields) - 2 ){
		warn( "Didn't have enough elements to load data from $row when analyzing $file\n" );
		die;
	    }
	    push ( @rows, $row );
	    $count++;
	    if( eof || $count == $nrows ){
		$run++;
		open( OUT,  ">$out" ) || die "Can't open $out for write in Shotmap::DB::bulk_import\n";
		print OUT join( "\n", @rows );
		close OUT;
		my $sql = "LOAD DATA LOCAL INFILE '" . $out . "' INTO TABLE " . $table . " FIELDS TERMINATED BY ',' " . 
		    "LINES TERMINATED BY '\\n' ( " . $field_string . " )";
		#join(",", @fields) . ")";
		my $sth  = $dbh->do($sql) || die "SQL Error: $DBI::errstr\n";
		$inserts = $inserts + $sth;
		$count   = 0;
		@rows    = ();
		unlink( $out );
	    }
	}
	close TAB;
	$self->Shotmap::Notify::print_verbose( $inserts . " records inserted.\n" );
    }	
    if( $table eq "families" || $table eq "familymembers" ){ #THE TABLE DATA IS ASSEMBLED ELSEWHERE, WE SIMPLY OPTIMIZE DB PINGS WITH THIS ROUTINE
	my $count    = 0;
	my $inserts  = 0;
	my @rows     = ();
	my $searchdb_id  = $fks->{"searchdb_id"};
	open( TAB, "$file" ) || die "Can't open $file for read in Shotmap::DB::bulk_import\n";
	my $run = 0;
	$self->Shotmap::Notify::print_verbose( "Loading data from $file\n" );
	while( <TAB> ){
	    chomp $_;
	    my $row   = $_ . "," . $searchdb_id;
	    my $col_count = ($row =~ tr/\,//);
	    if( $col_count < scalar(@fields) - 2 ){
		warn( "Didn't have enough elements to load data from $row when analyzing $file\n" );
		die;
	    }
	    push ( @rows, $row );
	    $count++;
	    if( eof || $count == $nrows ){
		$run++;
		open( OUT,  ">$out" ) || die "Can't open $out for write in Shotmap::DB::bulk_import\n";
		print OUT join( "\n", @rows );
		close OUT;
		my $sql = "LOAD DATA LOCAL INFILE '" . $out . "' INTO TABLE " . $table . " FIELDS TERMINATED BY '\t' " . 
		    "LINES TERMINATED BY '\\n' ( " . $field_string . " )";
		#join(",", @fields) . ")";
		my $sth  = $dbh->do($sql) || die "SQL Error: $DBI::errstr\n";
		$inserts = $inserts + $sth;
		$count   = 0;
		@rows    = ();
		unlink( $out );
	    }
	}
	close TAB;
	$self->Shotmap::Notify::print_verbose( $inserts . " records inserted.\n" );
    }	

    #disconnect
    $dbh->disconnect;
    return $self;
}

sub create_flat_file_project{
    my( $self, $name, $desc ) = @_;
    my $ffdb    = $self->{"ffdb"};
    my $db_name = $self->{"dbname"};
    my $path    = "$ffdb/projects/$db_name/";
    my $pid     = $self->Shotmap::DB::create_flat_file_id( $path );
    return $pid;
}

sub create_flat_file_id{
    my( $self, $path ) = @_;
    my $id;
    #open the ffdb path
    if( ! -d $path ){
	$id = 1;
    } else {
	opendir( DIR, $path ) || die "Can't opendir: $path\n";
	my @files = readdir( DIR );
	closedir( DIR );
	my $max_id = 0;
	#what projects have been created so far?
	foreach my $file( @files ){
	    next if( $file =~ m/^\./ );
	    next unless( $file =~ m/^\d/ );
	    if( $file > $max_id ){
		$max_id = $file;
	    }	
	}       
	#get a new, unique pid
	$id = $max_id + 1;
	#return the pid
    }
    return $id;
}

sub get_flatfile_sample_id{
    my ( $self, $samp ) = @_;
    my $path = $self->project_dir();
    my $sid  = $self->Shotmap::DB::create_flat_file_id( $path );
    return $sid;
}

#####
# XML Functions
####

sub get_classification_id_flatfile{
    my( $self, $evalue, $coverage, $score, $db_name, $search_method, $hit_type ) = @_;
    $score     = _null_check( $score );
    $coverage  = _null_check( $coverage );
    $evalue    = _null_check( $evalue );
    my $method = $search_method . ";" . "best_${hit_type}";
    my $class_id;
    my $max_id = 0;
    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parsefile( $self->params_file() );
    #check if id already exists for these run-time settings
    foreach my $cid ( $doc->getElementsByTagName( 'classification_id' ) ){
	if( $cid->hasChildNodes ){
	    my $id       = _get_xml_value( $cid, "id" );
	    my $id_score = _get_xml_value( $cid, "score" );
	    my $id_eval  = _get_xml_value( $cid, "evalue" );
	    my $id_cov   = _get_xml_value( $cid, "coverage" ); 
	    my $id_meth  = _get_xml_value( $cid, "method" ); #e.g., rapsearch;best_read
	    my $id_db    = _get_xml_value( $cid, "search_database" ); #e.g., Test_families_nr_50000
	    if( $id > $max_id ){
		$max_id = $id;
	    }
	    if( $id_score eq $score     || ( $id_score eq "null" && $score    eq "null" ) &&
		$id_eval  eq $evalue    || ( $id_eval  eq "null" && $evalue   eq "null" ) &&
		$id_cov   eq $coverage  || ( $id_cov   eq "null" && $coverage eq "null" ) &&
		$id_meth  eq $method    &&
		$id_db    eq $db_name   ){
		$class_id = $id;
		last;		
	    }
	}
    }
    if( !defined( $class_id ) ){
	#if not, then let's create a new id
	my $new_id   = $max_id + 1;
	my $class_params = pop(@{$doc->getElementsByTagName('classification_parameters')});
	my $new_cid  = $doc->createElement('classification_id');
	
	$doc = _add_child_element( $doc, $new_cid, 'id',    $new_id );
	$doc = _add_child_element( $doc, $new_cid, 'score', _null_check( $score ) );
	$doc = _add_child_element( $doc, $new_cid, 'coverage', _null_check( $coverage ) );
	$doc = _add_child_element( $doc, $new_cid, 'evalue', _null_check( $evalue ) );
	$doc = _add_child_element( $doc, $new_cid, 'method', $method );
	$doc = _add_child_element( $doc, $new_cid, 'search_database', $db_name );

	$class_params->appendChild($new_cid);
	#print to file
	$doc->printToFile( $self->params_file() );
	$doc->dispose;
	$class_id = $new_id;
    }
    return $class_id;
}

sub set_sample_parameters{
    my( $self, $sample_id, $sample_alt_id ) = @_;
    if( !defined( $sample_id ) ){
	die "You did not provide a defined sample_id, so I cannot set the parameters xml file!\n";
    }
    if( !defined( $sample_alt_id ) ){
	die "You did not provide a defined sample_alt_id, so I cannot set the parameters xml file!\n";
    }
    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parsefile( $self->params_file() );
    my $has_hit = 0;
    #check if id already exists 
    foreach my $cid ( $doc->getElementsByTagName( 'sample_id' ) ){
	if( $cid->hasChildNodes ){
	    my $id       = _get_xml_value( $cid, "id" );
	    my $alt_id   = _get_xml_value( $cid, "sample_alt_id" );
	    if( $id == $sample_id && $alt_id eq $sample_alt_id ){
		$self->Shotmap::Notify::print_verbose( "Sample $sample_id has already been set in the parameters file\n" );
		$has_hit = 1;
	    }
	    if( $id == $sample_id && $alt_id ne $sample_alt_id ){
		die "Sample id $sample_id has a alt id <${sample_alt_id}> that disagrees with parameters file <${alt_id}>\n";
	    }
	    if( $sample_alt_id eq $alt_id && $sample_id != $id ){
		die "sample_alt_id <${sample_alt_id}> already has a conflicting sample id in parameters file: <${sample_id}> and <${id}>\n";
	    }
	}
    }
    if( !$has_hit ){
	#if not, then let's create a new id
	my $sample_params = pop(@{$doc->getElementsByTagName('samples')});
	my $new_sid  = $doc->createElement('sample_id');
	
	$doc = _add_child_element( $doc, $new_sid, 'id',    $sample_id );
	$doc = _add_child_element( $doc, $new_sid, 'sample_alt_id',    $sample_alt_id );

	$sample_params->appendChild($new_sid);
	#print to file
	$self->Shotmap::Notify::print_verbose( "Added sample $sample_id to the parameters file\n" );
	$doc->printToFile( $self->params_file() );
	$doc->dispose;
    }   
    return $self;
}

sub get_sample_by_id_flatfile{
    my( $self, $sample_id ) = @_;
    if( !defined( $sample_id ) ){
	die "You did not provide a defined sample_id, so I cannot parse the parameters xml file!\n";
    }
    my $sample_alt_id;
    my $sample = (); #hashref
    $sample->{"id"} = $sample_id;
    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parsefile( $self->params_file() );
    my $max_id = 0;
    #check if id already exists for these run-time settings
    foreach my $cid ( $doc->getElementsByTagName( 'sample_id' ) ){
	if( $cid->hasChildNodes ){
	    my $id       = _get_xml_value( $cid, "id" );
	    my $alt_id   = _get_xml_value( $cid, "sample_alt_id" );
	    if( $id > $max_id ){
		$max_id = $id;
	    }
	    if( $id == $sample_id ){
		$sample_alt_id = $alt_id;
		$sample->{"sample_alt_id"} = $alt_id;
		last;		
	    }
	}
    }
    if( !defined( $sample_alt_id ) ){
	die "Couldn't extract the sample_alt_id for sample id ${sample_id} from parameters file!\n";
    }
    return $sample;
}

sub _null_check{
    my( $value ) = @_;
    if( ! defined $value ){
	$value = "null";
    }
    return $value;
}

sub _add_child_element{
    my( $parent, $new_child, $key, $value ) = @_;
    my $new_element = $parent->createElement( $key );
    my $new_text    = $parent->createTextNode( $value );
    $new_element->appendChild($new_text);
    $new_child->appendChild($new_element);
    return $parent
}

sub get_abundance_parameter_id_flatfile{
    my( $self, $abund_type, $norm_type, $rare_depth, $rare_type ) = @_;
    
}


sub _get_xml_value{
    my( $node, $name ) = @_;
    my $value = $node->getElementsByTagName($name)->item(0)->getFirstChild->getNodeValue;
    return $value;
}

sub initialize_parameters_file{
    my( $self, $param_file ) = @_;
    if( ! -e $param_file ){ #don't reinitialize a file that has already been created!
	$self->Shotmap::Notify::notify( "Initialize a parameters xml file here: $param_file\n" );
	open( OUT, ">$param_file" ) || die "Can't open $param_file for write: $!\n";
	print OUT 
	    "<xml>\n" 
	    . "\t<samples>\n"
	    . "\t</samples>\n"
	    . "\t<classification_parameters>\n"
	    . "\t</classification_parameters>\n"
	    . "\t<abundance_parameters>\n"
	    . "\t</abundance_parameters>\n"
	    . "</xml>"
	    ;
	close OUT;
    }
    return $self;
}

1;
