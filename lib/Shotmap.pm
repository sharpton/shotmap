#!/usr/bin/perl -w

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
use Shotmap::DB;
use Shotmap::Run;
use Shotmap::Schema;
use Data::Dumper;
use File::Basename;
use File::Path;
use File::Spec;
use IPC::System::Simple qw(capture $EXITVAL);
use Data::Dumper;

sub new{
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    my $self  = {};
    $self->{"workdir"}     = undef; 
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
    $self->{"verbose"}            = 0;
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

sub wait{
    my( $self, $value ) = @_; 
    if( defined( $value ) ){
	$self->{"wait"} = $value;
    }
    return $self->{"wait"};    
}

sub project_path{
    my $self = shift;
    my $path = shift;
    if( defined( $path ) ){
	$self->{"projectpath"} = $path;
    }
    return $self->{"projectpath"};
}
sub get_project_path{ my $self = shift; return $self->project_path };

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

sub bulk_insert_count{
    my ($self, $count) = @_;
    if( defined( $count ) ){
	$self->{"bulk_insert_count"} = $count;
    }
    return $self->{"bulk_insert_count"};
}

sub force_search{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"forcesearch"} = $value;
    }
    return $self->{"forcesearch"};
}

sub force_build_search_db{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"forcedb"} = $value;
    }
    return $self->{"forcedb"};
}

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
    (defined($self->ffdb())) or die "ffdb was not defined! This can't be called until AFTER you call set_ffdb.";
    (defined($sample_id)) or die "get_sample_path has ONE MANDATORY argument! It can NOT be called with an undefined input sample_id! In this case, Sample id was not defined!";
    (defined($self->project_id())) or die "Project ID was not defined!";
    (defined($self->db_name())) or die "Database name was not defined!";
    return(File::Spec->catfile($self->ffdb(), "projects", $self->db_name(), $self->project_id(), "$sample_id")); # concatenates items into a filesystem path
}

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
 Function: Store a hash that relates sample names to sample ffdb paths in the Shotmap object   
 Example : my $hash_ref = $analysis->set_samples( \%sample_paths );
 Returns : A hash_ref of sample names to sample ffdb paths (hash reference)
 Args    : A hash_ref of sample names to sample ffdb paths (hash reference)

=cut 

sub set_samples{
    my $self = shift;
    my $samples = shift; #this is a hashref
    $self->{"samples"} = $samples;
    return $self->{"samples"};
}


=head2 get_sample_hashref

 Title   : get_sample_hashref
 Usage   : $analysis->get_sample_hashref()
 Function: Retrieve a hash reference that relates sample names to sample ffdb path from the Shotmap object
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
 Function: Obtain or retrieve the project description and store in the Shotmap object
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
 Function: Obtain or retrieve the sample metadata table associated with the project and store in the Shotmap object. 
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
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"rffdb"} = $value;
    }
    return $self->{"rffdb"};
}

sub remote_project_path{
   my ($self) = @_;
   (defined($self->remote_ffdb())) or warn "get_remote_project_path: Remote repository path was NOT defined at this point, but we requested it anyway!\n";
   (defined($self->project_id())) or warn "get_remote_project_path: Project ID was NOT defined at this point, but we requested it anyway!.\n";
   (defined($self->db_name())) or warn "get_remote_project_path: Database name was NOT defined at this point, but we requested it anyway!.\n";
   my $path = $self->remote_ffdb() . "/projects/" . $self->db_name . "/" . $self->project_id() . "/";
   return $path;
}

sub remote_sample_path{
    my ( $self, $sample_id ) = @_;    
    my $path = $self->remote_ffdb() . "/projects/" . $self->db_name() . "/" . $self->project_id() . "/" . $sample_id . "/";
    return $path;
}

sub remote_connection{
    my ($self) = @_;
    return($self->remote_user() . "@" . $self->remote_host());
}

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

sub remote_scripts_dir{
    my ($self, $path) = @_;
    if( defined( $path ) ){
	$self->{"remote_script_dir"} = $path;
    }
    return $self->{"remote_script_dir"};
}

sub use_search_alg{
    my( $self, $alg, $value ) = @_;
    if( defined( $value ) ){
	$self->{"search"}->{$alg} = $value;
    }
    return $self->{"search"}->{$alg};
}

sub local_scripts_dir{
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

sub scratch{
    my $self    = shift;
    my $scratch = shift;
    if( defined( $scratch ) ){
	$self->{"scratch"} = $scratch;
    }
    return $self->{"scratch"};
}

sub ffdb{ # Function: Indicates where the Shotmap flat file database is located
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
	$self->set_schema_name( "ShotDB::Schema" );
    }
    my $schema = $self->{"schema_name"}->connect( $self->dbi_connection, $self->db_user, $self->db_pass,
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
	    warn("Note: you passed the schema name in as \"$name\", but names should always end in the literal text \"::Schema\". So we have actually modified the input argument, now the schema name is being set to: " . $name . "::Schema\" ");
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
    return $self->{"dbi"};
}

sub remote_master_dir{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"rdir"} = $value;
    }
    return $self->{"rdir"};
}

sub dryrun{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"dryrun"} = $value;
    }
    return $self->{"dryrun"};
}

sub read_split_size{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"seq-split-size"} = $value;
    }
    return $self->{"seq-split-size"};
}

sub remote_script_path{
    my( $self, $type, $value ) = @_;
    if( defined( $value ) ){
	$self->{"type"} = $value;
    }
    return $self->{"type"};
}

#currently only used for rapsearch
sub search_db_name_suffix{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"db_suffix"} = $value;
    }
    return $self->{"db_suffix"};
}

sub family_annotations{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"annotations"} = $value;
    }
    return $self->{"annotations"};
}

sub remote_project_log_dir{
    my $self     = shift;
    my $filepath = shift;
    if( defined( $filepath ) ){
	$self->{"r_project_logs"} = $filepath;
    }
    $self->{"r_project_logs"};
}

sub verbose{
    my( $self, $value ) = @_; #value is binary 1/0
    if( defined( $value ) ){
	$self->{"verbose"} = $value;
    }
    return $self->{"verbose"};
}

sub search_db_path{
    my ($self, $type) = @_;
    (defined($type)) or die( "You didn't specify the type of db that you want the path of\n" );
    (defined($self->ffdb())) or die("ffdb was not defined!");
    (defined($self->search_db_name($type))) or die("db ${type} is not defined!");
    if( $type eq "hmm" ){
	return($self->ffdb() . "/HMMdbs/" . $self->search_db_name("hmm"));
    }
    if( $type eq "blast" ){
	return($self->ffdb() . "/BLASTdbs/" . $self->search_db_name("blast"));
    }
}

sub top_hit_type{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"top_hit_type"} = $value;
    }
    return $self->{"top_hit_type"};
}

sub abundance_type{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"abund_type"} = $value;
    }
    return $self->{"abund_type"};
}

sub normalization_type{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"norm_type"} = $value;
    }
    return $self->{"norm_type"};
}

sub search_db_name_suffix{
    my( $self, $value ) = @_;
    if( defined( $value ) ){
	$self->{"search_suffix"} = $value;
    }
    return $self->{"search_suffix"};
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
    my $connection = $self->remote_connection();
    Shotmap::Run::execute_ssh_cmd( $connection, "mkdir -p $rffdb"         , $verbose); # <-- 'mkdir' with the '-p' flag won't produce errors or overwrite if existing, so simply always run this.
    Shotmap::Run::execute_ssh_cmd( $connection, "mkdir -p $rffdb/projects", $verbose);
    Shotmap::Run::execute_ssh_cmd( $connection, "mkdir -p $rffdb/HMMdbs"  , $verbose);   
    Shotmap::Run::execute_ssh_cmd( $connection, "mkdir -p $rffdb/BLASTdbs", $verbose);
}

sub build_remote_script_dir {
    my ($self, $verbose) = @_;
    my $rscripts      = $self->{"remote_script_dir"};
    ( defined($rscripts) ) || die "The remote scripts directory was not defined, so we cannot create it!\n";
    my $connection = $self->remote_connection();
    Shotmap::Run::execute_ssh_cmd( $connection, "mkdir -p $rscripts"          , $verbose); # <-- 'mkdir' with the '-p' flag won't produce errors or overwrite if existing, so simply always run this.
}

1;

