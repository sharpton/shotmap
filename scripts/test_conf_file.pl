#!/usr/bin/perl -w

use strict;

# is SHOTMAP_LOCAL defined in environment?
if ( defined( $ENV{'SHOTMAP_LOCAL'} ) ) {
    _pr( "testing \$SHOTMAP_LOCAL definition", "PASS" );
} else {
    _pr( "testing \$SHOTMAP_LOCAL definition", "FAIL" );
}

use lib ($ENV{'SHOTMAP_LOCAL'} . "/ext/lib/perl5");     
use lib ($ENV{'SHOTMAP_LOCAL'} . "/scripts"); ## Allows shotmap scripts to be found in the SHOTMAP_LOCAL directory
use lib ($ENV{'SHOTMAP_LOCAL'} . "/lib");

#check perl module installations
my @mods = (
#    "XML::DOM", #barks a bunch of warnings.
    "DBIx::Class",
    "DBIx::BulkLoader::Mysql",
    "IPC::System::Simple",
    "IO::Uncompress::Gunzip",
    "IO::Compress::Gzip",
    "Carp",
    "File::Util",
    "File::Cat",
    "Unicode::UTF8",
 
    "XML::Tidy",
    "Math::Random",
    "Parallel::ForkManager",
    "DBI",
    "DBD::mysql", 
    "File::Basename",
    "File::Copy",
    "File::Path",
    "File::Spec",
    "Getopt::Long",
    "Capture::Tiny",
    );

foreach my $mod( @mods ){
    _chk_mod( "$mod" );
}

# test 3rd party algorithms
use Capture::Tiny ':all';

my $bin = $ENV{'SHOTMAP_LOCAL'} . "/bin/";
my $algs = {
    rapsearch           => "${bin}/rapsearch",
    prerapsearch        => "${bin}/prerapsearch",
    blastp              => "${bin}/blastp",
    makeblastdb         => "${bin}/makeblastdb",
    hmmscan             => "${bin}/hmmscan",
    hmmsearch           => "${bin}/hmmsearch",
    transeq             => "${bin}/transeq",
    prodigal            => "${bin}/prodigal",
    lastal              => "${bin}/lastal",
    lastdb              => "${bin}/lastdb",
    "metatrans.py"      => "${bin}/metatrans.py",
    "ags_functions.py"  => "${bin}/ags_functions.py",
    "microbe_census.py" => "${bin}/microbe_census.py",
};

foreach my $alg( keys( %$algs ) ){
    my $path = $algs->{$alg};   
    my( $stdout, $stderr, $exit_val) = capture {
	system( $path );
    };
    if( $exit_val == -1 ){
	_pr( "testing $alg installation", "FAIL" );
    } else {
	_pr( "testing $alg installation", "PASS" );
    }
}

# Test run specific settings. Note that some of the algs and mods
# may want to be integrated into these sections
use Shotmap;
use Shotmap::Load;
use Shotmap::Run;
my $pipe = Shotmap->new();
$pipe->is_test(1); #has effect on next statements
$pipe->Shotmap::Load::get_options( @ARGV );
$pipe->Shotmap::Load::check_vars();
$pipe->Shotmap::Load::set_params();
# Additional checks
#check input sequence files
$pipe->Shotmap::Run::get_partitioned_samples( $pipe->raw_data );
#check DB options
#can we connect to the mysql database?
if( $pipe->use_db ){
    my $DBIstring = "DBI:mysql:host=" . $self->db_host; #don't want the dbname in string for autocreate
    my $dbh = DBI->connect( $DBIstring, $pipe->dbuser, $db_pass )
	or die "Connection Error: $DBI::errstr\n";
    my $sth = $dbh->prepare(
	"SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = $db_name"
	)
	or die "Couldn't prepare statement: " . $dbh->errstr;
    $sth->execute() 
	or die "Couldn't prepare statement: " . $dbh->errstr;
    my $db;
    my $build_db = 0;
    while( my @row = $sth->fetchrow_array() ){
	$db = $row[1];
    }
    unless defined( $db ){
	print( "Couldn't find a mysql database named $db_name. " .
	       "Trying to create this database....\n" );
	$build_db = 1;
    }
    $sth->finish;
    #now, let's try to autocreate the database. We may be hindered by create permissions. If so,
    #need db admin to step in.
    if( $build_db ){
	$dbh->func( 'createdb', $db_name, 'admin' );
	$dbh->disconnect; #we want to terminate the old connection, try anew with db name
	#try to touch the new database
	my $dbh = DBI->connect( $pipe->dbi_connection, $pipe->dbuser, $db_pass )
	    or die "Connection Error: $DBI::errstr\n";	
	#now let's add the schema
	my $sql_file = $ENV{'SHOTMAP_LOCAL'} . "/db/ShotDB.sql";
	open( FILE, $sql_file ) || die "Can't open $sql_file for read: $!\n";
	my $sql = join( "", <FILE> );
	close FILE;
	#we'll iterate...
	my @states = split( "\;", $sql );
	foreach my $state( @states ){
	    #do we need to eliminate comment lines?
	    my $sth = $dbh->prepare( $state );
	    $sth->execute or die $dbh->errstr;
	    $sth->finish;
	}	
	print( "Created database $db_name on mysql server " . $pipe->db_host . ".");
    } 
    #now, let's reconnect to the new database and make sure we have access
    $dbh->disconnect; #note this is either (un)named db given above switch
    eval{    
	my $dbh = DBI->connect( $pipe->dbi_connection, $pipe->dbuser, $db_pass )
	or die "Connection Error: $DBI::errstr\n";	
	$dbh->disconnect;
    };
    unless( $@ ){
	print( "Can connect to $db_name on mysql server " . $pipe->db_host . ".");
    }
}

#check remote server options
if( $pipe->remote ){
    #can we write to the remote server?
    my $rdir       = $pipe->remote_ffdb();
    my $remote_cmd = "mkdir $rdir";
    eval{ 
	$pipe->Shotmap::Run::execute_ssh_cmd( $pipe->remote_connection(), $remote_cmd );
    };
    if( $@ ){
	die( "Don't have permission to write $rdir on " . $pipe->remote_host . ". " .
	     "Please check your username, password, and that you have passwordless " .
	     "ssh settings configured. Also check that you have permission to write " .
	     "to this directory on the remove machine." );
    } else {
	print( "Can write to $rdir on " . $pipe->remote_host . "." );
    }    
}

sub _chk_mod{
    my $mod_str = shift;
    if( eval( "use ${mod_str}; 1" )){
	_pr( "testing $mod_str installation", "PASS" );
    } else {
	_pr( "testing $mod_str installation", "FAIL" );
    }    
}

sub _pr{
    my $string = shift;
    my $value  = shift;
    print join( ",", $string, $value, "\n" );
}
