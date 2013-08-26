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
use DBIx::Class::ResultClass::HashRefInflator;
use DBI; #used only for DBIx::BulkLoader::Mysql
use DBD::mysql;
use DBIx::BulkLoader::Mysql; #Used only for multi-row inserts

#returns samples result set
sub get_samples_by_project_id{
    my $self    = shift;
    my $samples = $self->get_schema->resultset("Sample")->search(
	{
	    project_id => $self->project_id(),
	}
    );
    return $samples; # <-- what the heck kind of data type is this, anyway?
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

sub delete_family_member_by_sample_id{
    my $self = shift;
    my $sample_id = shift;
    my $orfs = $self->get_schema->resultset("Orf")->search(
	{
	    sample_id => $sample_id,
	}
    );
    while( my $orf = $orfs->next() ){
	my $orf_id = $orf->orf_id();
	$self->Shotmap::DB::delete_family_member_by_orf_id( $orf_id );	
    }
    return $self;
}


sub delete_family_member_by_orf_id{
    my $self = shift;
    my $orf_id = shift;
    my $fam_members  = $self->get_schema->resultset("Familymember")->search(
	{
	    orf_id => $orf_id,
	}
	);
    while( my $fam_member = $fam_members->next() ){
	$fam_member->delete();
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

sub delete_ffdb_project{
    my $self       = shift;
    my $project_id = shift;
    my $ffdb = $self->ffdb();
    my $project_ffdb = "$ffdb/projects/$project_id";
    File::Path::rmtree($project_ffdb);
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
	print $inserts . " records inserted\n";
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
		    "LINES TERMINATED BY '\\n' ( sample_id, read_id, orf_alt_id )";
		my $sth = $dbh->do($sql) || die "SQL Error: $DBI::errstr\n";
		$inserts = $inserts + $sth;
		$count = 0;
		@rows  = ();
		unlink( $out );
	    }
	}
	close SEQS;
	print $inserts . " records inserted\n";
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
	print "Loading data from $file\n";
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
	print $inserts . " records inserted.\n";
    }	
    if( $table eq "families" || $table eq "familymembers" ){ #THE TABLE DATA IS ASSEMBLED ELSEWHERE, WE SIMPLY OPTIMIZE DB PINGS WITH THIS ROUTINE
	my $count    = 0;
	my $inserts  = 0;
	my @rows     = ();
	my $searchdb_id  = $fks->{"searchdb_id"};
	open( TAB, "$file" ) || die "Can't open $file for read in Shotmap::DB::bulk_import\n";
	my $run = 0;
	print "Loading data from $file\n";
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
	print $inserts . " records inserted.\n";
    }	

    #disconnect
    $dbh->disconnect;
    return $self;
}

sub create_multi_metareads{
    my $self          = shift;
    my $sample_id     = shift;
    my $ra_read_names = shift;
    print "Bulk loading reads from sample $sample_id\n";
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

sub create_multi_familymembers{
    my $self         = shift;
    my $class_id     = shift;
    my $rh_orf_hits  = shift;
    my %orf_hits     = %{ $rh_orf_hits };
    my $sql_insert   = 'INSERT INTO familymembers ( famid, classification_id, orf_id ) values ';
    my $placeholders = '(?,?,?)';
    my $dbh = DBI->connect( $self->dbi_connection(), $self->db_user, $self->db_pass );
    my( $bulk, $error ) = DBIx::BulkLoader::Mysql->new(
	dbh          => $dbh,
	sql_insert   => $sql_insert,
	placeholders => $placeholders
	);
    die $error unless $bulk;
    foreach my $orf_id( keys( %orf_hits ) ){
	my $famid = $orf_hits{$orf_id};
	$bulk->insert( $famid, $class_id, $orf_id );
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

sub get_sample_by_alt_id{
    my $self = shift;
    my $sample_alt_id = shift;
    my $sample = $self->get_schema->resultset('Sample')->find( { sample_alt_id => $sample_alt_id } );
    return $sample;
}

sub build_db_ffdb {    # This appears not to actually BUILD anything, it just makes a directory.
    my ($self, $path) = @_;
    if (-d $path){
	$self->Shotmap::Notify::notify("For whatever reason, we are removing the entire directory in <$path>, in build_db_ffdb.");
	File::Path::rmtree( $path );
    }
    File::Path::make_path( $path );
}

sub get_hmmdb_path{
    my ($self) = @_;
    (defined($self->ffdb())) or die("ffdb was not defined!");
    (defined($self->get_hmmdb_name())) or die("hmmdb name was not defined!");
    return($self->ffdb() . "/HMMdbs/" . $self->get_hmmdb_name());
}

sub get_blastdb_path{
    my $self = shift;
    (defined($self->ffdb())) or die("ffdb was not defined!");
    (defined($self->get_blastdb_name())) or die("blastdb name was not defined!");
    return($self->ffdb() . "/BLASTdbs/" . $self->get_blastdb_name());
}

sub get_number_db_splits{
    my ( $self, $type ) = @_;
    my $n_splits = 0;
    my $db_path;
    if( $type eq "hmm" ) {       $db_path = $self->Shotmap::DB::get_hmmdb_path();
    } elsif( $type eq "blast" ){ $db_path = $self->Shotmap::DB::get_blastdb_path();
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
    opendir( DIR, $self->Shotmap::DB::get_hmmdb_path ) || die "Can't opendir " . $self->get_hmmdb_path() . " for read: $! ";
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
    my $db_path = $self->Shotmap::DB::get_blastdb_path();
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
    File::Path::make_path($proj_dir); # make_path ALREADY dies on "severe" errors. See http://search.cpan.org/~dland/File-Path-2.09/Path.pm#ERROR_HANDLING
    #or die "Can't create new directory <$proj_dir> in build_project_ffdb: $! ";
}

sub build_sample_ffdb{
    my ($self, $nseqs_per_samp_split) = @_;
    my $ffdb = $self->ffdb();
    my $pid = $self->project_id();
    my $projDir = $self->project_dir; # no trailing slashes please!
    my $outDir  = "$projDir/output";
    my $logDir  = "$projDir/logs";
    my $hmmscanlogs      = "$logDir/hmmscan";
    my $hmmsearchlogs    = "$logDir/hmmsearch";
    my $blastlogs        = "$logDir/blast";
    my $lastlogs         = "$logDir/last";
    my $rapsearchlogs    = "$logDir/rapsearch";
    my $formatdblogs     = "$logDir/formatdb";
    my $lastdblogs       = "$logDir/lastdb";
    my $prerapsearchlogs = "$logDir/prerapsearch";
    my $transeqlogs      = "$logDir/transeq";
    my $parselogs        = "$logDir/parse_results";

    my @paths = ( $outDir, $logDir, $hmmscanlogs, $hmmsearchlogs, $blastlogs, 
		  $formatdblogs, $lastlogs, $lastdblogs, $rapsearchlogs,
		  $prerapsearchlogs, $transeqlogs, $parselogs );

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

	my $hmmscan_results   = "$search_res/hmmscan";
	my $hmmsearch_results = "$search_res/hmmsearch";
	my $blast_results     = "$search_res/blast";
	my $last_results      = "$search_res/last";
	my $rapsearch_results = "$search_res/rapsearch";

	if (-d $raw_sample_dir) {
	    warn("The directory \"$raw_sample_dir\" already existed!");
	    if ($self->{"clobber"}) { warn("But you specified the CLOBBER option, so we will brutally overwrite it anyway!"); }
	    else { die("Since the data already exists in $raw_sample_dir , we will not overwrite it! Unless you specify the flag --clobber to brutally clobber those directories anyway. NOT RECOMMENDED unless you know what you're doing."); }
	}

	foreach my $dirToMake ($sampDir, $search_res, $hmmscan_results, $hmmsearch_results, $blast_results, $last_results, $rapsearch_results, $raw_sample_dir, $orf_sample_dir, $unsplit_orfs) {
	    File::Path::make_path($dirToMake); # <-- make_path ALREADY dies on "severe" errors, so no need to check for them. See http://search.cpan.org/~dland/File-Path-2.09/Path.pm#ERROR_HANDLING
	}
	my $nameprefix = "${sampleName}_raw_split_"; # the "base name" here.
	#might want to use the no_bp option to improve throughput of alex's call of split_sequence_file below
	#my @split_names = @{ 
	$self->Shotmap::DB::split_sequence_file_no_bp( $self->get_sample_hashref()->{$sampleName}->{"path"}, $raw_sample_dir, $nameprefix, $nseqs_per_samp_split );
	#$self->Shotmap::DB::split_sequence_file(       $self->get_sample_hashref()->{$sampleName}->{"path"}, $raw_sample_dir, $nameprefix, $nseqs_per_samp_split);
    }
}

sub split_sequence_file{
    my ($self, $full_seq_file, $split_dir, $base_filename, $nseqs_per_split) = @_;
    my @output_names = ();    #a list of filenames
    my $seqs = Bio::SeqIO->new( -file => "$full_seq_file", -format => "fasta" );

    ## $counter == 1 is handled specifically here for some reason
    my $counter = 1;
    my $outname  = "${base_filename}${counter}.fa";
    my $output = Bio::SeqIO->new( -file => ">$split_dir/$outname", -format => "fasta" );
    push(@output_names, $outname);
    $self->Shotmap::Notify::notify("Will dump to split $split_dir/$outname");

    my $seq_ct = 0;
    my $seq_count_across_splits = 0; 
    while(my $seq = $seqs->next_seq()) {
	#have we reached the prerarefy sequence count, if that is set?
	if( defined( $self->prerarefy_samples() ) && $seq_count_across_splits == $self->prerarefy_samples() ){
	    last;
	}	   
	if ($seq_ct == $nseqs_per_split) {
	    $seq_ct = 0; # reset to 0
	    $counter++; # weirdly this situation (counter == 2) gets handled separately from the stuff above.
	    my $outname  = "${base_filename}${counter}.fa";
	    $output      = Bio::SeqIO->new(-file => ">$split_dir/$outname", -format => "fasta" );	
	    push( @output_names, $outname );
	    $self->Shotmap::Notify::notify("Will dump to split $split_dir/$outname");
	}
	$output->write_seq($seq);

	#$self->Shotmap::Notify::notify("Output file $split_dir/$outname is now of size " . (-s "$split_dir/$outname") . "...");

	$seq_ct++;
	$seq_count_across_splits++;
    }    
    return \@output_names;
}

sub split_sequence_file_no_bp{
    my $self             = shift;
    my $full_seq_file    = shift;
    my $split_dir        = shift;
    my $basename         = shift;
    my $nseqs_per_split  = shift;
    #a list of filenames
    my @output_names = ();
    open( SEQS, $full_seq_file ) || die "Can't open $full_seq_file for read in Shotmap::DB::split_sequence_file_no_bp\n";
    my $counter  = 1;
    my $outname  = $basename . $counter . ".fa";
    my $splitout = $split_dir . "/" . $outname;
    open( OUT, ">$splitout" ) || die "Can't open $splitout for write in Shotmap::DB::split_sequence_file_no_bp\n";
    push( @output_names, $outname );
    print "Will dump to split $splitout\n";
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
		print "Will dump to split $splitout\n";
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
	    $hmmdbs{$file} = $self->get_remote_ffdb() . "/HMMdbs/$hmmdb_name/$file";
	} else {
	    $hmmdbs{$file} = "$hmmdb_local_path/$file";
	}
    }
    $self->Shotmap::Notify::notify("Grabbed " . scalar(keys(%hmmdbs)) . " HMM dbs from $hmmdb_local_path");
    return \%hmmdbs;
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

sub get_orf_by_orf_id{
    my ($self, $orf_id) = @_;
    my $orf = $self->get_schema->resultset('Orf')->find(
	{
	    orf_id => $orf_id,
	}
	);
    return $orf;
}

sub get_number_reads_in_sample{
    my ($self, $sample) = @_;
    my $reads  = $self->Shotmap::DB::get_reads_by_sample_id( $sample );
    return $reads->count();
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
	#paging for management
#	{
#	    rows => 10,
#	    page => $page,
#	}
#	{
#	    result_class => 'DBIx::Class::ResultClass::HashRefInflator',
#	}
	);
    
    return $orfs;

#    $orfs->result_class('DBIx::Class::ResultClass::HashRefInflator');
#    return $orfs;
#    my $cursor = $orfs->cursor;
#    return $cursor;
}

#some DBI for speed
sub build_dbh{
    my( $self ) = @_;
    my $dbh = DBI->connect( $self->dbi_connection(), $self->db_user, $self->db_pass ) || die "Can't connect to database: " . $DBI::errstr;
    return $dbh; # <-- this return value actually gets used
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


sub disconnect_dbh{
    my( $self, $dbh ) = @_;
    $dbh->disconnect();
}

sub get_families_with_orfs_by_project{
    my $self = shift;
    my $project_id = shift;
    if( !defined( $project_id ) ){
	$project_id =  $self->project_id();
    }
#    my $fams = $self->get_schema->resultset('Familymember')->search(
#	{
#	    project_id => $project_id
#	},
#	{
#	    join      => { 'orf' => 'sample' },	
#	}
#	);
    my $inside_samps = $self->get_schema->resultset('Sample')->search(
	{
	    project_id => $project_id,
	}
	);
    my $inside_orfs =  $self->get_schema->resultset('Orf')->search(
	{
	    sample_id => { -in => $inside_samps->get_column('sample_id')->as_query },
	}
	);
    my $fams =  $self->get_schema->resultset('Familymember')->search(
	{
	    orf_id => { -in => $inside_orfs->get_column('orf_id')->as_query },
	}
	);	    
    return $fams;
}    


sub get_families_with_orfs_by_sample{
    my ( $self, $sample_id ) = @_;
#    my $fams = $self->get_schema->resultset('Familymember')->search(
#	{
#	    sample_id => $sample_id
#	},
#	{
#	    join      => 'orf'
#	}
#	);
    my $inside_orfs =  $self->get_schema->resultset('Orf')->search(
	    {
		sample_id => $sample_id,
	    }
	    );
    my $fams =  $self->get_schema->resultset('Familymember')->search(
	{
	    orf_id => { -in => $inside_orfs->get_column('orf_id')->as_query },
	}
	);	    
    return $fams;
}

#This is a complicated series of queries for DBIx. I'm sure someone knows how to do this efficiently in DBIx, but I don't. So, I'll use DBI.
sub get_classified_orfs_by_sample_old{
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
    if( !defined( $count ) ){ #grab results for all reads
	$sql = "SELECT MAX( score ) AS score, orf_alt_id, read_alt_id, sample_id, target_id, famid, aln_length FROM searchresults WHERE sample_id = ${sample_id} ";
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
    } else{
	$sql  = "SELECT MAX( score ) AS score, orf_alt_id, tab2.read_alt_id, tab2.sample_id, target_id, famid, aln_length FROM ";
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

    print "$sql\n";
    my $sth = $dbh->prepare($sql) || die "SQL Error: $DBI::errstr\n";
    $sth->execute();
    return $sth;
}

sub get_classified_orfs_by_sample{
    my ( $self, $sample_id, $class_id, $dbh, $count ) = @_; #if count is defined, subsample using the metareads table
    my $sql = "SELECT * FROM classifications WHERE sample_id = ${sample_id} and classification_id = ${class_id}";
    print "$sql\n";
    my $sth = $dbh->prepare($sql) || die "SQL Error: $DBI::errstr\n";
    $sth->execute();
    return $sth;
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
	$sql .= "SELECT MAX( score ) AS score, orf_alt_id, read_alt_id, sample_id, target_id, famid, aln_length, '${class_id}' FROM searchresults WHERE sample_id = ${sample_id} "; #note that we want the proper class_id, not the one from searchresults
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
    } else{
	$sql  .= "SELECT MAX( score ) AS score, orf_alt_id, tab2.read_alt_id, tab2.sample_id, target_id, famid, aln_length, '${class_id} FROM ";
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
    print "$sql\n";
    my $sth = $dbh->prepare($sql) || die "SQL Error: $DBI::errstr\n";
    $sth->execute();
    return $sth;
}


sub get_family_members_by_orf_id{
    my $self = shift;
    my $orf_id = shift; 
    my $fam_members = $self->get_schema->resultset('Familymember')->search(
	{
	    orf_id => $orf_id,
	}
    );
    return $fam_members;
}

#my $qorf_id = $self->Shotmap::DB::get_orf_id_from_alt_id( $qorf, $sample );
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

#$self->Shotmap::DB::insert_family_member_orf( $qorf_id, $hmm );
sub insert_familymember_orf{
    my $self     = shift;
    my $orf_id   = shift;
    my $famid    = shift;
    my $class_id = shift;
    my $inserted = $self->get_schema->resultset("Familymember")->create(
	{
	    famid  => $famid,
	    orf_id => $orf_id,
	    classification_id => $class_id,
	}
	);    
    return $inserted;
}

sub insert_familymember_slim{
    my $self            = shift;
    my $famid_slim      = shift;
    my $orf_alt_id_slim = shift;
    my $sample_id       = shift;
    my $class_id        = shift;
    my $inserted = $self->get_schema->resultset("Familymembers_slim")->create(
	{
	    famid_slim        => $famid_slim,
	    orf_alt_id_slim   => $orf_alt_id_slim,
	    sample_id         => $sample_id,
	    classification_id => $class_id,
	}
	);    
    return $inserted;
}


sub get_genomes_by_domain{
    my $self = shift;
    my $domain = shift;
    my $genomes = $self->get_schema->resultset("Genome")->search(
	{
	    domain => $domain,
	}
	);
    return $genomes;
}

sub get_genes{
    my $self  = shift;
    my $genes = $self->get_schema->resultset("Gene");
    return $genes;
}

sub get_genes_by_taxon_oid{
    my $self      = shift;
    my $taxon_oid = shift;
    my $genes     = $self->get_schema->resultset("Gene")->search(
	{
	    taxon_oid => $taxon_oid,
	}
	);
    return $genes;
}

sub get_gene_from_gene_oid{
    my $self = shift;
    my $gene_oid = shift;
    my $gene = $self->get_schema->resultset("Gene")->find(
	{
	    gene_oid => $gene_oid,
	}
	);
    return $gene;
}

sub get_genes_from_taxon_oid{
    my $self = shift;
    my $taxon_oid = shift;
    my $genes = $self->get_schema->resultset("Gene")->search(
	{
	    taxon_oid => $taxon_oid,
	}
	);
    return $genes;
}

sub get_genome_from_taxon_oid{
    my $self = shift;
    my $taxon_oid = shift;
    my $genome = $self->get_schema->resultset("Genome")->find(
	{
	    taxon_oid => $taxon_oid,
	}
	);
    return $genome;

}
sub get_genome_from_ncbi_taxon_oid{
    my $self = shift;
    my $taxon_oid = shift;
    my $genome = $self->get_schema->resultset("Genome")->find(
	{
	    ncbi_taxon_oid => $taxon_oid,
	}
	);
    return $genome;

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

sub get_family_by_fci{
    my $self = shift;
    my $fci  = shift;
    my $families = $self->get_schema->resultset("Family")->search(
	{
	    familyconstruction_id => $fci,
	}
    );
    return $families;
}

sub get_family_from_geneoid{
    my $self = shift;
    my $gene_oid = shift;
    my $rs = $self->get_schema->resultset("Familymember")->search(
	{
	    gene_oid => $gene_oid,
	}
	);
    return $rs;
}

#use if you are certain that your gene_oids map to a single family
sub get_famid_from_geneoid_fast{
    my $self     = shift;
    my $gene_oid = shift;
    my $familymember = $self->get_schema->resultset("Familymember")->find(
	{
	    gene_oid => $gene_oid,
	}
   );
   return $familymember->famid->famid; 
}

sub get_famid_from_geneoid{
    my $self = shift;
    my $gene_oid = shift;
    my @fcis     = @{ $self->get_fcis() };
    my $families = $self->get_schema->resultset("Familymember")->search(
	{
	    gene_oid => $gene_oid,
	}
    );

    if ($families->count() > 1  and  !(@fcis) ) {
	die("Got multiple families for gene_oid $gene_oid. Must use fci to determine which family to select!");
    }

    my @selected = ();
    while( my $family = $families->next() ){
	my $famid = $family->famid->famid;
	if( @fcis ){
	    my $family_rs = $self->Shotmap::DB::get_family_from_famid( $famid );
	    my $fam_fci   = $family_rs->familyconstruction_id();
	    my $is_fci    = 0;
	    foreach my $fci( @fcis ){
		if( $fam_fci == $fci ){
		    $is_fci = 1;
		    last;
		}
	    }
	    if( $is_fci ){
		push( @selected, $famid );
	    }
	}
    }

    if( scalar( @selected ) > 1 ){
	die("Even with fci selection, there are multiple family ids for gene_oid <$gene_oid>: " . join(" ", @selected, "\n") . " ");
    }
    
    return $selected[0];
}

sub get_famid_from_fam_alt_id{
    my( $self, $fam_alt_id ) = shift;
    my $famid = $self->get_schema->resultset("Family")->search(
	{
	    fam_alt_id => $fam_alt_id,
	}
	);
    return $famid;
}

sub get_family_sequences_by_fci{
    my $self = shift;
    my @fcis = @{ $_[0] };
    my $out  = $_[1]; #optional
    my %seqs = ();
    foreach my $fci( @fcis ){
	my $families = $self->get_schema->resultset("Family")->search(
	    {
		familyconstruction_id => $fci,
	    }
	);
	while( my $family = $families->next() ){
	    my $members = $self->Shotmap::DB::get_family_members_by_famid( $family->famid() );
	    while( my $member = $members->next() ){
		my $gene_oid_rs = $member->gene_oid;
		if( defined( $gene_oid_rs ) ){
		    my $gene_oid = $gene_oid_rs->gene_oid;
		    if( defined( $gene_oid ) ){
			if( defined( $out ) ){
			    print $out "$gene_oid\n";
			}
			else{
			    $seqs{$gene_oid}++;
			}
		    }
		}					    
	    }
	}
    }
    return \%seqs;
}

sub get_gene_length{
    my $self = shift;
    my $gene_oid = shift;
    my $genes = $self->get_schema->resultset("Gene")->search(
	{
	    gene_oid => $gene_oid,
	}
    );
    my $seqlen;
    while( my $gene = $genes->next() ){
	$seqlen = length( $gene->dna );
	last;
    }
    return $seqlen;
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

sub get_abundance_type_id{
    my ( $self, $abund_type, $norm_type ) = @_; 
    my $inserted = $self->get_schema->resultset( "AbundanceParameter" )->find_or_create(
	{
	    abundance_type        => $abund_type,
	    normalization_type    => $norm_type,
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

###
# DB LOADER FUNCTIONS
###

sub insert_family_construction{
    my $self        = shift;
    my $description = shift;
    my $name        = shift;    
    my $author      = shift;
    my $proj_rs     = $self->get_schema->resultset("Familyconstruction");
    my $inserted    = $proj_rs->create(
	{
	    description => $description,
	    name        => $name,
	    author      => $author,
	}
	);
    return $inserted;
}

sub insert_tree{
	my ($self, $treedesc, $treepath, $treetype) = @_;
	my $inserted = $self->get_schema->resultset("Trees")->create({
		treedesc => $treedesc,
		treepath => $treepath,
		treetype=> $treetype,
	}
	);
	return $inserted;
}

sub insert_tree_into_family{
	my ($self, $treeID, $famID) = @_;
	my $update_row = $self->get_schema->resultset( "Family" )->find({famid => $famID });
	if(defined $update_row){
		$update_row->update({alltree => $treeID});
	}else{
		warn "Couldn't find family $famID when trying to update the tree field\n";
	}
}

sub insert_alignment_into_family{
	my ($self, $alnpath, $famID) = @_;
	my $update_row = $self->get_schema->resultset( "Family" )->find({famid => $famID });
	if(defined $update_row){
		$update_row->update({alnpath => $alnpath});
	}else{
		warn "Couldn't find family $famID when trying to update the alnpath field\n";
	}
}
sub insert_seed_alignment_into_family{
	my ($self, $alnpath, $famID) = @_;
	my $update_row = $self->get_schema->resultset( "Family" )->find({famid => $famID });
	if(defined $update_row){
		$update_row->update({seed_alnpath => $alnpath});
	}else{
		warn "Couldn't find family $famID when trying to update the seed_alnpath field\n";
	}
}

sub insert_hmm_into_family{
	my ($self, $hmmpath, $famID) = @_;
	my $update_row = $self->get_schema->resultset( "Family" )->find({famid => $famID });
	if(defined $update_row){
		$update_row->update({hmmpath => $hmmpath});
	}else{
		warn "Couldn't find family $famID when trying to update the hmmpath field\n";
	}
}

sub insert_family{
    my( $self, $familyconstruction_id, $fam_alt_id, $name,
	$description, $alnpath, $seed_alnpath, $hmmpath,
	$reftree, $alltree, $size, $universality,
	$evenness, $arch_univ, $bact_univ, $euk_univ,
	$unknown_genes, $pathogen_percent, $aquatic_percent ) = @_;
    my $inserted = $self->get_schema->resultset( "Family" )->create(
	{
	    familyconstruction_id => $familyconstruction_id,
	    fam_alt_id => $fam_alt_id,
	    name => $name,
	    description => $description,
	    alnpath => $alnpath,
	    seed_alnpath => $seed_alnpath,
	    hmmpath => $hmmpath,
	    reftree => $reftree,
	    alltree => $alltree,
	    size => $size,
	    universality => $universality,
	    evenness => $evenness,
	    arch_univ => $arch_univ,
	    bact_univ => $bact_univ,
	    euk_univ => $euk_univ,
	    unknown_genes => $unknown_genes,
	    pathogen_percent => $pathogen_percent,
	    aquatic_percent => $aquatic_percent,
	}
	);
    return $inserted;
}

sub insert_protein_into_genes{
    my ( $self, $gene_oid, $taxon_oid, $id, $type, $protein, $protein_name, $protein_desc, $start, $end, $strand, $locus, $scaffold_name, $scaffold_id, $dna ) = @_;
    my $inserted = $self->get_schema->resultset("Gene")->find_or_create(
	{
	    gene_oid    => $gene_oid,
	    taxon_oid   => $taxon_oid,
	    protein_id  => $id,
	    type        => $type,
	    protein     => $protein,
	    name        => $protein_name,
	    description => $protein_desc,
	    start       => $start,
	    end         => $end,
	    strand      => $strand,
	    locus       => $locus,
	    dna         => $dna,
	    scaffold_name => $scaffold_name,
	    scaffold_id   => $scaffold_id,	    
	}
	);
    return $inserted,
}

sub insert_gene_into_family_members{
    my ( $self, $famid, $gene_oid ) = @_;
    my $inserted = $self->get_schema->resultset("Familymember")->create(
	{
	    famid    => $famid,
	    gene_oid => $gene_oid,
	}
	);
}

sub get_max_column_value{
    my( $self, $table, $column ) = @_;
    my $maxvalue = $self->get_schema->resultset($table)->get_column($column)->max;
    return $maxvalue;
}

#routines for database updates

sub insert_genome{
    my ( $self, $ncbi_taxon_id, $ncbi_project_id, $completion, $domain, $genome_name, $directory, 
	 $phylum, $class, $order, $family, $genus, $sequencing_center, $gene_count, 
	 $genome_size, $scaffold_count, $img_release, $add_date, $is_public ) = @_;
    my $inserted = $self->get_schema->resultset("Genome")->find_or_create(
	{
	    ncbi_taxon_id     => $ncbi_taxon_id,
	    ncbi_project_id   => $ncbi_project_id,
	    completion        => $completion,
	    domain            => $domain,
	    name              => $genome_name,
	    directory         => $directory,
	    phylum            => $phylum,
	    class             => $class,
	    order             => $order,
	    family            => $family,
	    genus             => $genus,
	    sequencing_center => $sequencing_center,
	    gene_count        => $gene_count,
	    genome_size       => $genome_size,
	    scaffold_count     => $scaffold_count,
	    img_release       => $img_release,
	    add_date          => $add_date,
	    is_public         => $is_public,
	}	
	);
    return $inserted;
}

sub insert_gene{
    my ( $self, $gene_oid, $taxon_oid, $protein_id, $type, $start, $end,
	 $strand, $locus, $name, $description, $scaffold_name,
	 $scaffold_id, $dna, $protein ) = @_;

#    print join( "\t", $gene_oid, $taxon_oid, $protein_id, $type, $start, $end,
#	 $strand, $locus, $name, $description, $scaffold_name,
#	 $scaffold_id, $dna, $protein, "\n" );
    my $inserted = $self->get_schema->resultset("Gene")->update_or_create(
	{
	    gene_oid      => $gene_oid,
	    taxon_oid     => $taxon_oid,
	    protein_id    => $protein_id,
	    type          => $type,
	    start         => $start,
	    end           => $end,
	    strand        => $strand,
	    locus         => $locus,
	    name          => $name,
	    description   => $description,
	    scaffold_name => $scaffold_name,
	    scaffold_id   => $scaffold_id,
	    dna           => $dna,
	    protein       => $protein,
	}
	);
    return $inserted;
}

sub insert_genome_from_hash{
    my $self           = shift;
    my $ra_genome_data = shift;
    my $force          = shift; #forces an update of a column for which a taxon_oid exists. BE CAREFUL WITH THIS!
    my %data = %{ $ra_genome_data };
    #unfortunately, there has to be some hard coding of IMG/JGI taxon table headers given that they don't
    #perfectly map to DB column names
    ##since we're inserting data from jgi, let's see if we will specify the taxon_oid (instead of an autoincrement).
    ##need to ensure the taxon_oid is unique to all over taxon_oids in the DB
    my $taxon_oid         = _check_value( $data{ "taxon_oid" } );
    my $is_unique         = $self->Shotmap::DB::check_taxon_oid_unique( $taxon_oid );
    my $ncbi_taxon_id     = _check_value( $data{ "NCBI_Taxon_ID" } );
    my $ncbi_project_id   = _check_value( $data{ "GenBank_Project_ID" } );
    my $completion        = _check_value( $data{ "Status" } );
    my $domain            = _check_value( $data{ "Domain"} );
    my $genome_name       = _check_value( $data{ "Genome_Name_/_Sample_Name" } );
    my $directory         = _check_value( $data{ "Genome_Name_/_Sample_Name" } );
    $directory            =~ s/\s/\_/g;
    $directory            =~ s/\//\_/g;
    $directory            =~ s/\(/\_/g;
    $directory            =~ s/\)/\_/g;
    $directory            =~ s/\,/\_/g;
    $directory            =~ s/\'/\_/g;
    $directory            =~ s/\"/\_/g;
    $directory            =~ s/\:/\_/g;
    $directory            =~ s/\.//g;
    my $phylum            = _check_value( $data{ "Phylum" } );
    my $class             = _check_value( $data{ "Class" } );
    my $order             = _check_value( $data{ "Order" } );
    my $family            = _check_value( $data{ "Family" } );
    my $genus             = _check_value( $data{ "Genus" } );
    my $sequencing_center = _check_value( $data{ "Sequencing_Center" } );
    my $gene_count        = _check_value( $data{ "Gene_Count" } );
    my $genome_size       = _check_value( $data{ "Genome_Size" } );
    my $scaffold_count    = _check_value( $data{ "Scaffold_Count" } );
    my $img_release       = _check_value( $data{ "IMG_Release" } );
    my $add_date          = _check_value( $data{ "Add_Date" } );
    my $is_public         = _check_value( $data{ "Is_Public" } );
    my $gc                = _check_value( $data{ "GC_%" } );
    $gc                   = $gc * 100;
    my $gram_stain        = _check_value( $data{ "Gram_Staining" } );
    if( defined( $gram_stain) ){
	$gram_stain           =~ s/Gram//;
    }
    my $shape             = _check_value( $data{ "Cell_Shape" } );
    my $arrangement       = _check_value( $data{ "Cell_Arrangement" } );
    my $endospores        = _check_value( $data{ "Sporulation" } );
    my $motility          = _check_value( $data{ "Motility" } );
    my $salinity          = _check_value( $data{ "Salinity" } );
    my $oxygen_req        = _check_value( $data{ "Oxygen_Requirement" } );
    my $habitat           = _check_value( $data{ "Ecosystem" } );
    my $temp_range        = _check_value( $data{ "Temperature_Range" } );
    #my $pathogenic_in     = _check_value( $data{ "Hosts" } );
    my $pathogenic_in     = _check_value( $data{ "Hosts" } );
    my $disease           = _check_value( $data{ "Diseases" } );
    if( defined $disease && $disease eq "None" ){
	$pathogenic_in = "No";
	$disease       = undef;
    }
    elsif( !defined($disease) ){
	$pathogenic_in = undef;
	$disease       = undef;
    }
    #build the row
    my $row = {
	    taxon_oid         => $taxon_oid,
	    ncbi_taxon_id     => $ncbi_taxon_id,
	    ncbi_project_id   => $ncbi_project_id,
	    completion        => $completion,
	    domain            => $domain,
	    name              => $genome_name,
	    directory         => $directory,
	    phylum            => $phylum,
	    class             => $class,
	    order             => $order,
	    family            => $family,
	    genus             => $genus,
	    sequencing_center => $sequencing_center,
	    gene_count        => $gene_count,
	    genome_size       => $genome_size,
	    scaffold_count    => $scaffold_count,
	    img_release       => $img_release,
	    add_date          => $add_date,
	    is_public         => $is_public,
	    gc                => $gc,
	    gram_stain        => $gram_stain,
	    shape             => $shape,
	    arrangement       => $arrangement,
	    endospores        => $endospores,
	    motility          => $motility,
	    salinity          => $salinity,
	    oxygen_req        => $oxygen_req,
	    habitat           => $habitat,
	    temp_range        => $temp_range,
	    pathogenic_in     => $pathogenic_in,
	    disease           => $disease,
    };	

    #check to see if taxon is in the db or not
    if( !$is_unique ){
	if( $force ){
	    my $updated = $self->get_schema->resultset("Genome")->update_or_create( $row, { key =>'primary' } );
	    warn("The taxon_oid $taxon_oid is NOT UNIQUE to the database. Updated row since force is ON!");
	    return $updated;
	}
	warn( "The taxon_oid $taxon_oid is NOT UNIQUE to the database. Passing on this entry!");
	
	warn "why do we return self here anyway";
	return $self; # why would this return "$self" anyway?
    }
    #insert the data to the database;
    my $inserted = $self->get_schema->resultset("Genome")->create( $row );
    return $inserted;
}

sub check_taxon_oid_unique{
    my( $self, $taxon_oid ) =@_;
    my $is_unique = 0;
    my $genome = $self->get_schema->resultset('Genome')->find( { taxon_oid => $taxon_oid } );    
    if( !defined( $genome ) ){
	$is_unique = 1;
    }
    return $is_unique;
}

sub get_max_treeid{
    my $self   = shift;
    my $treeid = $self->get_schema->resultset('Tree')->get_column('treeid')->max();
    return $treeid;
}

sub get_max_familyconstruction_id{
    my $self   = shift;
    my $treeid = $self->get_schema->resultset('Familyconstruction')->get_column('familyconstruction_id')->max();
    return $treeid;
}

sub get_max_famid{
    my $self   = shift;
    my $treeid = $self->get_schema->resultset('Family')->get_column('famid')->max();
    return $treeid;
}

sub find_or_create_tree{
    my( $self, $treepath, $treedesc, $treetype ) = @_;
    my $tree = $self->get_schema->resultset('Tree')->find_or_create(
	{
	    treepath => $treepath,
	    treedesc => $treedesc,
	    treetype => $treetype,
	},
	);
    return $tree;
}

sub find_gene_by_gene_oid{
    my( $self, $gene_oid ) = @_;
    my $gene = $self->get_schema->resultset( 'Gene' )->find(
	{
	    gene_oid => $gene_oid,
	}
	);
    return $gene;
}

sub insert_familymember{
    my( $self, $family, $gene_oid ) = @_;
    my $inserted = $self->get_schema->resultset( 'Familymember' )->find_or_create(
	{
	    famid    => $family,
	    gene_oid => $gene_oid,
	}
	);
    return $inserted;
}

sub _check_value{
    my $value = shift;
    if( !defined( $value ) ){
	$value = undef;
    }
    elsif( $value eq "_" ){
	$value = undef;
    }
    return $value;
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

sub get_family_by_fam_alt_id{
    my ( $self, $fam_alt_id ) = @_;
    my $family = $self->get_schema->resultset("Family")->find(
	{
	    fam_alt_id => $fam_alt_id,
	}
	);
    return $family;
}

sub get_gene_by_protein_id{
    my ( $self, $protein_id ) = @_;
    my $gene = $self->get_schema->resultset("Gene")->find(
	{
	    protein_id => $protein_id,
	}
	);
    return $gene;
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

#too slow. obsolete
sub load_families{
    my( $self, $type ) = @_;
    my $raw_db_path = undef;
    if ($type eq "hmm")   { $raw_db_path = $self->Shotmap::DB::get_hmmdb_path(); }
    if ($type eq "blast") { $raw_db_path = $self->Shotmap::DB::get_blastdb_path(); }
    open( FAMLENS, "${raw_db_path}/family_lengths.tab" ) || die "Can't open ${raw_db_path}/family_lengths.tab for read: $!\n";
    while( <FAMLENS> ){
	chomp $_;
	my( $famid, $famlen, $fam_size );
	if( $type eq "blast" ){
	    ( $famid, $famlen, $fam_size ) = split( "\t", $_ );
	} elsif( $type eq "hmm" ){
	    ( $famid, $famlen ) = split( "\t", $_ );
	}
	my $inserted = $self->get_schema->resultset("Family")->find_or_create(
	    {
		famid         => $famid,
		family_length => $famlen,
		family_size   => $fam_size,
	    }
	    );
    }
    close FAMLENS;
    return $self;
}

#too slow. obsolete
sub load_family_members{
    my( $self ) = @_;
    my $sequence_map = $self->Shotmap::DB::get_blastdb_path() . "/sequence_lengths.tab";
    open( SEQLENS, "$sequence_map" ) || die "Can't open $sequence_map for read: $!\n";
    while( <SEQLENS> ){
	chomp $_;
	my( $famid, $seqid, $seqlen ) = split( "\t", $_ );	
	my $inserted = $self->get_schema->resultset("Familymember")->find_or_create(
	    {
		famid         => $famid,
		target_id     => $seqid,
		target_length => $seqlen,
	    }
	    );
    }
    close SEQLENS;

}

sub load_annotations{


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

sub insert_abundance{
    my( $self, $sample_id, $famid, $abundance, $relative_abundance, $abundance_type_id ) = @_;
    my $inserted = $self->get_schema->resultset("Abundance")->find_or_create(
	{
	    sample_id => $sample_id,
	    famid     => $famid,
	    abundance => $abundance,
	    relative_abundance => $relative_abundance,
	    abundance_type_id  => $abundance_type_id,
	}
	);
    return $inserted;
}

1;
