#!/usr/bin/perl -w

#MRC.pm - The MRC workflow manager
#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gladstone.ucsf.edu
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program (see LICENSE.txt).  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

package Shotmap;

use Shotmap::Load;
use Shotmap::Notify;
use MRC::DB;
use MRC::Run;
use SFams::Schema;
use MRC::Schema;
use Data::Dumper;
use File::Basename;
use File::Path;
use File::Spec;
use IPC::System::Simple qw(capture $EXITVAL);
use Data::Dumper;


=head2 new
 Usage   : $project = MRC->new()
 Function: initializes a new MRC analysis object
 Example : $analysus = MRC->new();
 Returns : A MRC analysis object
=cut

sub new{
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    my $self  = {};
    warn "Setting default values: is_remote, is_strict, and multiload have default values.";
    $self->{"workdir"}     = undef; #master path to MRC scripts
    $self->{"ffdb"}        = undef; #master path to the flat file database
    $self->{"dbi"}         = undef; #DBI string to interact with DB
    $self->{"user"}        = undef; #username to interact with DB
    $self->{"pass"}        = undef; #password to interact with DB
    $self->{"dbname"}      = undef; #name of the mysql database to talk to
    $self->{"projectpath"} = undef; #path to the raw data
    $self->{"projectname"} = undef;
    $self->{"project_id"}  = undef;
    $self->{"proj_desc"}   = undef;
    $self->{"proj_dir"}    = undef; #path to project directory in ffdb
    $self->{"samples"}     = undef; #hash relating sample names to paths   
    $self->{"metadata"}    = undef; #string encoding the sample metadata table loaded from file
    $self->{"rusername"}   = undef;
    $self->{"r_ip"}        = undef;
    $self->{"remote_script_dir"}    = undef;
    $self->{"rffdb"}       = undef;
    $self->{"fid_subset"}  = undef; #an array of famids
    $self->{"schema"}      = undef; #current working DB schema object (DBIx)    
    $self->{"hmmdb"}       = undef; #name of the hmmdb to use in this analysis
    $self->{"blastdb"}     = undef; #name of the blastdb to use in this analysis
    $self->{"is_remote"}   = 0;     #does analysis include remote compute? 0 = no, 1 = yes
    $self->{"is_strict"}   = 1;     #strict (top hit) v. fuzzy (all hits passing thresholds) clustering. 1 = strict. 0 = fuzzy. Fuzzy not yet implemented!
    $self->{"t_evalue"}    = undef; #evalue threshold for clustering
    $self->{"t_coverage"}  = undef; #coverage threshold for clustering
    $self->{"r_hmmscan_script"}   = undef; #location of the remote hmmscan script. holds a path string.
    $self->{"r_hmmsearch_script"} = undef; #location of the remote hmmsearch script. holds a path string.
    $self->{"r_blast_script"}     = undef; #location of the remote blast script. holds a path string.
    $self->{"r_last_script"}      = undef; #location of the remote last script. holds a path string.
    $self->{"r_formatdb_script"}  = undef; #location of the remote formatdb script (for blast). holds a path string.
    $self->{"r_lastdb_script"}    = undef; #location of the remote lastdb script (for last). holds a path string.
    $self->{"r_project_logs"}     = undef; #location of the remote project logs directory. holds a path string.
    $self->{"multiload"}          = 0; #should we multiload our insert statements?
    $self->{"bulk_insert_count"}  = undef; #how many rows should be added at a time when using multi_load?
    $self->{"schema_name"}        = undef; #stores the schema module name, e.g., Sfams::Schema
    $self->{"slim"}               = 0; #are we processing a VERY, VERY large data set that requires a slim database?
    $self->{"bulk"}               = 0; #are we processing a VERY large data set that requires mysql data imports over inserts?
    $self->{"trans_method"}       = undef; #how are we translating the sequences?
    $self->{"prerarefy"}          = undef; #how many sequences should we retain per sample. If defined, will not analyze more seqs/sample than the value
    $self->{"postrarefy"}         = undef; #how many sequences should base diversity calculations on, per sample. If defined, will randomly rarefy reads from sample for diversity calcs
    $self->{"total_seq_count"}    = 0; #how many sequences are we analyzing per sample? Rolls back to zero for each sample, used in prerarefication
    $self->{"parse_score"}        = undef;
    $self->{"parse_evalue"}       = undef;
    $self->{"parse_threshold"}    = undef;
    $self->{"xfer_size"}          = 0; #threshold used in some data transfer processes
    $self->{"opts"}               = undef; #hashref that stores runtime options
    bless($self);
    return $self;
}

sub opts{
    my( $self, $value ) = @_; #value is a hashref
    if( defined( $value ) ){
	$self->{"opts"} = $value;
    }
    return $self->{"opts"};
}

sub get_sample_ids {
    my ($self) = @_;
    my @sample_ids = ();
    foreach my $samp (keys(%{$self->{"samples"}})) {
	my $this_sample_id = $self->{"samples"}->{$samp}->{"id"};
	(defined($this_sample_id)) or die "That's weird---the sample id for sample <$samp> was not defined! How is this even possible?";
	push(@sample_ids, $this_sample_id);
    }
    return \@sample_ids; # <-- array reference!
}

=head2 set_dbi_connection

 Title   : set_dbi_connection
 Usage   : $analysis->set_dbi_conection( "DBI:mysql:IMG" );
 Function: Create a connection with mysql (or other) database
 Example : my $connection = analysis->set_dbi_connection( "DBI:mysql:IMG" );
 Returns : A DBI connection string (scalar, optional)
 Args    : A DBI connection string (scalar)

=cut


sub get_db_name()        { my $self = shift; return $self->{"db_name"}; }
sub get_db_hostname()    { my $self = shift; return $self->{"db_hostname"}; }
sub get_dbi_connection() { my $self = shift; return $self->{"dbi"}; }

sub set_bulk_insert_count{
    my ($self, $count) = @_;
    $self->{"bulk_insert_count"} = $count;
}


=head2 set_project_path
 Usage   : $analysis->set_project_path( "~/data/metaprojects/project1/" );
 Function: Point to the raw project data directory (not the ffdb version)
=cut 

sub set_project_path{
    my $self = shift;
    my $path = shift;
    $self->{"projectpath"} = $path;
}
sub get_project_path{ my $self = shift;    return $self->{"projectpath"}; }



=head2 get_sample_path

 Title   : get_sample_path
 Usage   : $analysis->get_sample_path( $sample_id );
 Function: Retrieve a sample's ffdb filepath
 Example : my $path = analysis->get_sample_path( 7201 );
 Returns : A filepath (string)
 Args    : A sample_id

=cut 

sub get_sample_path($) { # note the mandatory (numeric?) argument!
    my ($self, $sample_id) = @_;
    (defined($self->get_ffdb())) or die "ffdb was not defined! This can't be called until AFTER you call set_ffdb.";
    (defined($sample_id)) or die "get_sample_path has ONE MANDATORY argument! It can NOT be called with an undefined input sample_id! In this case, Sample id was not defined!";
    (defined($self->get_project_id())) or die "Project ID was not defined!";
    (defined($self->db_name())) or die "Database name was not defined!";
    return(File::Spec->catfile($self->get_ffdb(), "projects", $self->db_name(), $self->get_project_id(), "$sample_id")); # concatenates items into a filesystem path
}

=head2 set_username 

 Title   : set_username
 Usage   : $analysis->set_username( $username );
 Function: Set the MySQL username
 Example : my $username = $analysis->set_username( "joebob" );
 Args    : A username (string)

=cut 

sub set_username { # note: this is the MYSQL username!
    my ($self, $user) = @_; $self->{"user"} = $user;
}
sub get_username() { my $self = shift; return $self->{"user"}; }

=head2 set_password

 Title   : set_password
 Usage   : $analysis->set_password( $password );
 Function: Set the MySQL password
 Example : my $username = $analysis->set_password( "123456abcde" );
 Args    : A password (string)

=cut 

#NOTE: This is pretty dubious! Need to add encryption/decryption function before official release

sub set_password{
    my $self = shift;
    my $path = shift;
    warn "In MRC.pm (function: set_password()): Note: we are setting the password in plain text here. This should ideally be eventually changed to involve encryption or something.";
    $self->{"pass"} = $path;
}
sub get_password { my $self = shift; return $self->{"pass"}; }


sub get_password_from_file{
    my ( $self, $passfile ) = @_;
    open( FILE, $passfile ) || die "Can't open $passfile for read:$!\n";
    my $pass;
    while(<FILE>){
	chomp $_;
	if( $_ =~ m/^dbpass\=(.*)$/ ){
	    $pass = $1;
	}
    }
    close FILE;
    return $pass;
}



=head2 build_schema

 Title   : build_schema
 Usage   : $analysis->build_schema();
 Function: Construct the DBIx schema for the DB that MRC interfaces with. Store it in the MRC object
 Example : my $schema = $analysis->build_schema();
 Returns : A DBIx schema
 Args    : None, but requires that set_username, set_password and set_dbi_connection have been called first

=cut


=head2 get_schema

 Title   : get_schema
 Usage   : $analysis->get_schema();
 Function: Obtain the DBIx schema for the database MRC interfaces with
 Example : my $schema = $analysis->get_schema( );
 Returns : A DBIx schema object
 Args    : None

=cut 



=head2 set_project_id

 Title   : set_project_id
 Usage   : $analysis->set_project_id( $project_id );
 Function: Store the project's database identifier (project_id) in the MRC object
 Example : my $project_id = MRC::DB::insert_project();
           $analysis->set_project_id( $project_id );
 Returns : The project_id (scalar)
 Args    : The project_id (scalar)

=cut 

#NOTE: Check that the MRC::DB::insert_project() function is named/called correctly above

sub project_id{
    my ($self, $pid) = @_;
    if( defined( $pid ) ){
	$self->{"project_id"} = $pid;
    }
    return $self->{"project_id"};
}




=head2 set_samples

 Title   : set_samples
 Usage   : $analysis->set_samples( $sample_paths_hash_ref );
 Function: Store a hash that relates sample names to sample ffdb paths in the MRC object   
 Example : my $hash_ref = $analysis->set_samples( \%sample_paths );
 Returns : A hash_ref of sample names to sample ffdb paths (hash reference)
 Args    : A hash_ref of sample names to sample ffdb paths (hash reference)

=cut 

sub set_samples{
    my $self = shift;
    my $samples = shift;
    $self->{"samples"} = $samples;
    return $self->{"samples"};
}

=head2 get_sample_hashref

 Title   : get_sample_hashref
 Usage   : $analysis->get_sample_hashref()
 Function: Retrieve a hash reference that relates sample names to sample ffdb path from the MRC object
 Example : my %samples = %{ $analysis->get_sample_hashref() };
 Returns : A hash_ref of sample names to sample ffdb paths (hash reference)
 Args    : None

=cut 

sub get_sample_hashref {
    my $self = shift;
    my $samples = $self->{"samples"}; #a hash reference
    return $samples;
}

=head2 project_desc

 Title   : project_desc
 Usage   : $analysis->project_desc( $projet_description_text );
 Function: Obtain or retrieve the project description and store in the MRC object
 Example : my $description = $analysis->project_description( "A metagenomic study of the Global Open Ocean, 28 samples total" );
 Returns : The project description (string)
 Args    : The project description (string)

=cut 

sub project_desc{
    my $self = shift;
    my $text = shift;
    if( defined( $text ) ){
	$self->{"proj_desc"} = $text;
    }
    return $self->{"proj_desc"};    
}

=head2 sample_metadata

 Title   : sample_metadta
 Usage   : $analysis->sample_metadata( $sample_metadata_table_text );
 Function: Obtain or retrieve the sample metadata table associated with the project and store in the MRC object. 
 Example : my $metadata_table_string = $analysis->sample_metadata()
 Returns : The sample metadata tab delimited table (string)
 Args    : The sample metadata tab delimited table (string)

=cut 

sub sample_metadata{
    my $self = shift;
    my $text = shift;
    if( defined( $text ) ){
	$self->{"metadata"} = $text;
    }
    return $self->{"metadata"};    
}


#this does not do the building, but sets whether we need to
sub build_search_db{
    my( $self, $type, $value ) = @_;
    my $string = "build_" . $type;
    if( defined( $value ) ){
	$self->{$string} = $value;
    }
    return $self->{$string};
}

sub search_db_split_size{
    my( $self, $type, $value ) = @_;
    my $string = "split_size_" . $type;
    if( defined( $value ) ){
	$self->{$string} = $value;
    }
    return $self->{$string};
}

sub nr{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"nr"} = $value;
    }
    return $self->{"nr"};
}

sub reps{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"reps"} = $value;
    }
    return $self->{"reps"};
}

sub search_db_name{
    my( $self, $type, $value ) = @_;
    my $string = "search_db_name_" . $type;
    if( defined( $value ) ){
	$self->{$string} = $value;
    }
    return $self->{$string};
}

# Remote EXE path
sub remote_exe_path{ 
    my ($self, $path) = @_; 
    if( defined( $path ) ){
	$self->{"remote_exe_path"} = $path; 
    }
    return $self->{"remote_exe_path"};
}

sub remote_ffdb{
    my( $self, $value ) = shift;
    if( defined( $value ) ){
	$self->{"rffdb"} = $value;
    }
    return $self->{"rffdb"};
}

sub remote_project_path{
   my ($self) = @_;
   (defined($self->get_remote_ffdb())) or warn "get_remote_project_path: Remote ffdb path was NOT defined at this point, but we requested it anyway!\n";
   (defined($self->get_project_id())) or warn "get_remote_project_path: Project ID was NOT defined at this point, but we requested it anyway!.\n";
   (defined($self->db_name())) or warn "get_remote_project_path: Database name was NOT defined at this point, but we requested it anyway!.\n";
   my $path = $self->get_remote_ffdb() . "/projects/" . $self->db_name . "/" . $self->get_project_id() . "/";
   return $path;
}

sub remote_sample_path{
    my ( $self, $sample_id ) = @_;    
    my $path = $self->get_remote_ffdb() . "/projects/" . $self->db_name() . "/" . $self->get_project_id() . "/" . $sample_id . "/";
    return $path;
}

=head2 get_remote_connection

 Title   : get_remote_connection
 Function: Get the connection string to the remote host (i.e., username@hostname). Must have set remote_username and
           remote_server before running this command
 Returns : A connection string(string) 
=cut 
sub remote_connection{
    my ($self) = @_;
    return($self->get_remote_username() . "@" . $self->get_remote_server());
}



=head is_strict_clustering

 Title   : is_strict_clustering
 Usage   : $analysis->is_strict_clustering( 1 );
 Function: If the project uses strict clustering, set this switch. Future implementation may alternatively enable
           fuzzy clustering. Maybe.
 Example : my $is_strict = $analysis->is_strict_clustering( 1 );
 Returns : A binary of whether the project uses strict clusterting (binary)
 Args    : A binary of whether the project uses strict clusterting (binary)

=cut 


=head set_evalue_threshold

 Title   : set_evalue_threshold
 Usage   : $analysis->set_evalue_threshold( 0.001 );
 Function: What evalue threshold should be used to assess classification of reads into families?
 Example : my $e_value = $analysis->set_evalue_threshold( 0.001 );
 Returns : An evalue (float)
 Args    : An evalue (float)

=cut 

sub class_evalue{
    my ( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"c_evalue"} = $value;
    }
    return $self->{"c_evalue"};
}

sub class_coverage{
    my ( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"c_coverage"} = $value;
    }
    return $self->{"c_coverage"};
}

sub class_score{
    my ( $self, $value ) = @_;    
    if( defined( $value ) ){
	$self->{"c_score"} = $value;
    }
    return $self->{"c_score"};
}

sub prerarefy_samples{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"prerarefy"} = $value;
    }
    return $self->{"prerarefy"};    
}

sub postrarefy_samples{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"postrarefy"} = $value;
    }
    return $self->{"postrarefy"};    
}

sub parse_score{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"parse_score"} = $value;
    }
    return $self->{"parse_score"};
}

sub parse_coverage{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"parse_coverage"} = $value;
    }
    return $self->{"parse_coverage"};
}

sub parse_evalue{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"parse_evalue"} = $value;
    }
    return $self->{"parse_evalue"};
}

sub small_transfer{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"xfer_size"} = $value;
    }
    return $self->{"xfer_size"};
}

sub remote_scripts{
    my ($self, $path) = @_;
    if( defined( $path ) ){
	$self->{"remote_script_dir"} = $path;
    }
    return $self->{"remote_script_dir"};
}

sub use_search_alg{
    my( $self, $alg, $value ) = @_;
    if( defined( $value ) ){
	$self->{$alg} = $value;
    }
    return $self->{$alg};
}

sub local_script_dir{
  my $self = shift;
  my $path = shift;
  if(defined($path)){ 
      (-e $path && -d $path) or die "The method set_scripts_dir cannot access scripts path $path. Maybe it isn't a directory or something. Cannot continue!";
      $self->{"scripts_dir"} = $path;
  }
  return $self->{"scripts_dir"};
}

sub multi_load{
    my $self = shift;
    my $is_multi = shift;
    if( defined( $is_multi ) ){
	$self->{"multiload"} = $is_multi;
    }
    return $self->{"multiload"};
}


sub ffdb{ # Function: Indicates where the MRC flat file database is located
    my $self = shift;  
    my $path = shift;
    if( defined( $path ) ){
	if( !( -e $path ) ){
	    warn "In ffdb, $path does not exist, so I'll create it.\n";
	    mkpath( $path );
	}
	if( ! -d $path ){
	    warn "For some reason, the method ffdb can't access $path\n";
	    die;
	}
	$self->{"ffdb"} = $path;
    }
    return $self->{"ffdb"};
}

sub ref_ffdb{
    my $self = shift;
    my $path = shift;
    if( defined( $path ) ){
	if( !( -d $path )  ){
	    warn "The method ref_ffdb cannot access ref_ffdb path $path. Cannot continue!\n";
	    die;
	}
	$self->{"ref_ffdb"} = $path;
    }
    return $self->{"ref_ffdb"};
}

sub bulk_load{
    my $self = shift;
    my $bulk = shift;
    if( defined( $bulk ) ){
	$self->{"bulk"} = $bulk;
    }
    return $self->{"bulk"};
}

sub trans_method{
   my $self = shift;
   my $method = shift;
   if( defined( $method ) ){
       $self->{"trans_method"} = $method;
   }
   return $self->{"trans_method"};
}

sub split_orfs{
   my $self  = shift;
   my $value = shift;
   if( defined( $value ) ){
       $self->{"split_orfs"} = $value;
   }
   return $self->{"split_orfs"};
}

sub orf_filter_length{
   my $self  = shift;
   my $value = shift;
   if( defined( $value ) ){
       $self->{"min_orf_len"} = $value;
   }
   return $self->{"min_orf_len"};    
}

sub project_dir{
    my $self = shift;
    my $path = shift;
    if( defined( $path ) ){
	$self->{"proj_dir"} = $path;
    }
    return $self->{"proj_dir"};
}

sub db_name{
    my $self = shift;
    my $text = shift;
    if( defined( $text ) ){
	$self->{"dbname"} = $text;      
    }
    return $self->{"dbname"};
}

sub db_host{
    my $self = shift;
    my $text = shift;
    if( defined( $text ) ){
	$self->{"dbhost"} = $text;      
    }
    return $self->{"dbhost"};
}

sub db_user{
    my $self = shift;
    my $text = shift;
    if( defined( $text ) ){
	$self->{"dbuser"} = $text;      
    }
    return $self->{"dbuser"};
}

sub db_pass{
    my $self = shift;
    my $text = shift;
    if( defined( $text ) ){
	$self->{"dbpass"} = $text;      
    }
    return $self->{"dbpass"};
}

sub build_schema{
    my $self   = shift;
    if( !defined( $self->{"schema_name"} ) ){
	warn( "You did not specify a schema name, so I'm defaulting to ShotDB\n" ); 
	$self->set_schema_name( "ShotDB" );
    }
    my $schema = $self->{"schema_name"}->connect( $self->{"dbi"}, $self->{"user"}, $self->{"pass"},
						  #since we have terms in DB that are reserved words in mysql (e.g., order)
						  #we need to put quotes around those field ids when calling SQL
						  {
						      quote_char => '`', #backtick is quote in sql
						      name_sep   => '.'  #allows SQL generator to put quotes in right place
						  }
	);
    $self->{"schema"} = $schema;
    return $self->{"schema"}; ## return the schema too! this gets used!
}

sub get_schema{    my $self = shift;    return($self->{"schema"}); }

sub family_subset{
    my $self   = shift;
    my $subset = shift;
    if( defined( $subset ) ){
	open( SUBSET, $subset ) || die "Can't open $subset for read: $!\n";
	my @retained_ids = ();
	while( <SUBSET> ){
	    chomp $_;
	    push( @retained_ids, $_ );
	}
	close SUBSET;
	$self->{"fid_subset"} = \@retained_ids;
    }
    return $self->{"fid_subset"};
}

sub remote { 
    my ($self, $value) = @_;
    if( defined( $value ) ){
	$self->{"is_remote"} = $value;
    }
    return $self->{"is_remote"};
}

sub stage{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"stage"} = $value;
    }
    return $self->{"stage"};
}

sub remote_user{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"ruser"} = $value;
    }
    return $self->{"ruser"};    
}

sub remote_host{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"rhost"} = $value;
    }
    return $self->{"rhost"};
}

sub schema_name{
    my ($self, $name) = @_;
    if( defined( $name ) ){
	if ($name =~ m/::Schema$/) { ## <-- does the new schema end in the literal text '::Schema'?
	    $self->{"schema_name"} = $name; # Should end in ::Schema . "::Schema";
	} else {
	    warn("Note: you passed the schema name in as \"$name\", but names should always end in the literal text \"::Schema\". So we have actually modified the input argument, now the schema name is being set to: " . $name . ":::Schema\" ");
	    $self->{"schema_name"} = $name . "::Schema"; # Append "::Schema" to the name.
	}
    }
    return $self->{"schema_name"};
}

sub set_multiload {
    my ($self, $multi) = @_;
    if( defined( $multi ) ){
	if ($multi != 0 && $multi != 1) { die "The multi variable must be either 0 or 1!"; }
	$self->{"multiload"} = $multi;
    }
    return $self->{"multiload"};
}

sub bulk_insert_count{
    my $self  = shift;
    my $value = shift;
    if( defined( $value ) ){
	$self->{"bulk_insert_count"} = $value;
    }
    return $self->{"bulk_insert_count"};
}

sub is_slim{
    my $self = shift;
    my $slim = shift;
    if( defined( $slim ) ){
	$self->{"slim"} = $slim;
    }
    return $self->{"slim"};
}

sub clustering_strictness() {
    my ($self, $strictness) = @_;
    if( defined( $strictness ) ){
	($strictness == 0 or $strictness == 1) or die "Bad value for is_strict!";
	$self->{"is_strict"} = $strictness;
    }
    return $self->{"is_strict"};
}

sub dbi_connection {
    my ($self, $dbipath ) = @_;
    if( defined( $dbipath ) ){
	$self->{"dbi"} = $dbipath;
    }
    return $dbipath;
}

sub remote_master_dir{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"rdir"} = $value;
    }
    return $self->{"rdir"};
}

#######
# NEED TO VALIDATE THESE
#######

=head build_remote_ffdb

 Title   : build_remote_ffdb
 Usage   : $analysis->build_remote_ffdb();
 Function: Makes some directories on the remote host. Build the ffdb on the remote host. Includes setting up projects/, HMMdbs/ dirs if they don't exist. Must have set
           the location of the remote ffdb and have a complete connection string to the remote host.
 Example : $analysis->build_remote_ffdb();
 Args    : (optional) $verbose: true/false (whether or not to print verbose output)

=cut 

sub build_remote_ffdb {
    my ($self, $verbose) = @_;
    my $rffdb      = $self->{"rffdb"};
    my $connection = $self->get_remote_connection();
    MRC::Run::execute_ssh_cmd( $connection, "mkdir -p $rffdb"          , $verbose); # <-- 'mkdir' with the '-p' flag won't produce errors or overwrite if existing, so simply always run this.
    MRC::Run::execute_ssh_cmd( $connection, "mkdir -p $rffdb/projects", $verbose);
    MRC::Run::execute_ssh_cmd( $connection, "mkdir -p $rffdb/HMMdbs"  , $verbose);   
    MRC::Run::execute_ssh_cmd( $connection, "mkdir -p $rffdb/BLASTdbs", $verbose);
}

sub build_remote_script_dir {
    my ($self, $verbose) = @_;
    my $rscripts      = $self->{"remote_script_dir"};
    ( defined($rscripts) ) || die "The remote scripts directory was not defined, so we cannot create it!\n";
    my $connection = $self->get_remote_connection();
    MRC::Run::execute_ssh_cmd( $connection, "mkdir -p $rscripts"          , $verbose); # <-- 'mkdir' with the '-p' flag won't produce errors or overwrite if existing, so simply always run this.
}

=head set_remote_hmmscan_script

 Title   : set_remote_hmmscan_script
 Usage   : $analysis->set_remote_hmmscan_script();
 Function: Set the location of the script that is located on the remote server that runs the hmmscan jobs
 Example : my $filepath = $analysis->set_remote_hmmscan_script( "~/projects/MRC/scripts/run_hmmscan.sh" )
 Returns : nothing
 Args    : A filepath to the script (string)

=cut 

sub set_remote_hmmscan_script{
    my $self     = shift;
    my $filepath = shift; 
    $self->{"r_hmmscan_script"} = $filepath;
}

sub set_remote_hmmsearch_script{
    my $self     = shift;
    my $filepath = shift; 
    $self->{"r_hmmsearch_script"} = $filepath;
}


sub set_remote_blast_script{
    my $self     = shift;
    my $filepath = shift; 
    $self->{"r_blast_script"} = $filepath;
}

sub set_remote_last_script{
    my $self     = shift;
    my $filepath = shift; 
    $self->{"r_last_script"} = $filepath;
}


sub set_remote_formatdb_script{
    my $self     = shift;
    my $filepath = shift; 
    $self->{"r_formatdb_script"} = $filepath;
}

sub set_remote_lastdb_script{
    my $self     = shift;
    my $filepath = shift; 
    $self->{"r_lastdb_script"} = $filepath;
}

sub set_remote_rapsearch_script{
    my $self     = shift;
    my $filepath = shift; 
    $self->{"r_rapsearch_script"} = $filepath;
}

sub set_remote_prerapsearch_script{
    my $self     = shift;
    my $filepath = shift; 
    $self->{"r_prerapsearch_script"} = $filepath;
}

# Function: Get the location of the script that is located on the remote server
sub get_remote_hmmscan_script{      my $self = shift;   return $self->{"r_hmmscan_script"}; }
sub get_remote_hmmsearch_script{    my $self = shift;   return $self->{"r_hmmsearch_script"}; }
sub get_remote_blast_script{        my $self = shift;   return $self->{"r_blast_script"}; }
sub get_remote_last_script{         my $self = shift;   return $self->{"r_last_script"}; }
sub get_remote_lastdb_script{       my $self = shift;   return $self->{"r_lastdb_script"}; }
sub get_remote_prerapsearch_script{ my $self = shift;   return $self->{"r_prerapsearch_script"}; }
sub get_remote_rapsearch_script{    my $self = shift;   return $self->{"r_rapsearch_script"}; }

=head set_remote_project_log_dir

 Title   : set_remote_project_log_dir
 Usage   : $analysis->set_remote_project_log_dir();
 Function: Set the location of the directory that is located on the remote server that will contain the run logs
 Example : my $filepath = $analysis->set_remote_project_log_dir( "~/projects/MRC/scripts/logs" );
 Returns : A filepath to the directory (string)
 Args    : A filepath to the directory (string)

=cut 

sub set_remote_project_log_dir{
    my $self     = shift;
    my $filepath = shift;
    $self->{"r_project_logs"} = $filepath;
}
sub get_remote_project_log_dir{    my $self = shift;    return $self->{"r_project_logs"}; }

1;

