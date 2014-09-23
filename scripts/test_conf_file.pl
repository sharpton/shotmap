#!/usr/bin/perl -w

use lib ( $ENV{ 'SHOTMAP_LOCAL' } . "/ext/lib/perl5");     
use lib ( $ENV{ 'SHOTMAP_LOCAL' } . "/scripts"); ## Allows shotmap scripts to be found in the SHOTMAP_LOCAL directory
use lib ( $ENV{ 'SHOTMAP_LOCAL' } . "/lib");

use strict;
use Cwd;
use Data::Dumper;

use Shotmap;
use Shotmap::Load;
use Shotmap::Run;

my $pipe = Shotmap->new();
$pipe->is_test(1); #has effect on next statements
$pipe->Shotmap::Load::get_options( @ARGV );
$pipe->Shotmap::Load::check_vars();
$pipe->Shotmap::Load::set_params();

my $has_fails = 0;

# is SHOTMAP_LOCAL defined in environment?
my $shotmap_local = $ENV{ 'SHOTMAP_LOCAL' };
if ( !defined( $shotmap_local ) || $shotmap_local eq "" ) {
    _pr( "testing \$SHOTMAP_LOCAL definition", "FAIL" );
    _pr( "trying to autoset \$SHOTMAP_LOCAL", "..." );
    my $dir = getcwd;
    system( "echo 'export SHOTMAP_LOCAL=${dir}' >> ~/.bash_profile" );
    #we still need to load into current shell
    $shotmap_local = $dir;
    my $shotmap = $shotmap_local . "/scripts/shotmap.pl";
    unless( -e $shotmap ){
        die( "You haven't set the bash environmental variable \$SHOTMAP_LOCAL. " .
	     "I tried to set it for you, but failed (using your current directory " .
	     "I found ${dir}, which doesn't seem correct). Please either execute this " .
	     "script from the root shotmap repository directory, or add " .
	     "the variable to your ~/.bash_profile (or ~/.profile or ~/.bashrc, depending " .
	     "on what exists in your home directory) yourself. You should probably add " .
	     "something like the following:\n\n" .
	     "export SHOTMAP_LOCAL=<path_to_shotmap_repository>\n" );
    }
    _pr( "autoset \$SHOTMAP_LOCAL", "PASS" );
} else {
    _pr( "testing \$SHOTMAP_LOCAL definition", "PASS" );
}

#check perl module installations
my @mods = (
#    "XML::DOM", #barks a bunch of warnings.
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
    "File::Basename",
    "File::Copy",
    "File::Path",
    "File::Spec",
    "Getopt::Long",
    "Capture::Tiny",
    );

if( $pipe->use_db ){
    my @db_mods = (
	"DBIx::Class",
	"DBIx::BulkLoader::Mysql",
	"DBI",
	"DBD::mysql", #if mysql server is on foreign machine, install by hand
	#see http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod 
	);
    foreach my $db_mod( @db_mods ){
	push( @mods, $db_mod );
    }    
}


foreach my $mod( @mods ){
    $has_fails = _chk_mod( "$mod", $has_fails );
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
    transeq             => "${bin}/transeq -h",
    prodigal            => "${bin}/prodigal",
    lastal              => "${bin}/lastal",
    lastdb              => "${bin}/lastdb",
    "metatrans.py"      => "python ${bin}/metatrans.py",
    "ags_functions.py"  => "python ${bin}/ags_functions.py",
    "microbe_census.py" => "python ${bin}/microbe_census.py",
};

foreach my $alg( sort( keys( %$algs ) ) ){
    my $path = $algs->{$alg};   
    my( $stdout, $stderr, $exit_val) = Capture::Tiny::capture {
	system( $path );
    };
    if( $exit_val == -1 ){
	_pr( "testing $alg installation", "FAIL" );
	$has_fails = 1;
   } else {
	_pr( "testing $alg installation", "PASS" );
    }
}

# Additional checks
#check input sequence files
$pipe->Shotmap::Run::get_partitioned_samples( $pipe->raw_data );
#check DB options
#can we connect to the mysql database?
if( $pipe->use_db ){
    my $DBIstring = "DBI:mysql:host=" . $pipe->db_host; #don't want the dbname in string for autocreate
    my $dbh = DBI->connect( $DBIstring, $pipe->dbuser, $pipe->dbpass )
	or die "Connection Error: $DBI::errstr\n";
    my $sth = $dbh->prepare(
	"SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = " . $pipe->db_name
	)	
	or die "Couldn't prepare statement: " . $dbh->errstr;
    $sth->execute() 
	or die "Couldn't prepare statement: " . $dbh->errstr;
    my $db;
    my $build_db = 0;
    while( my @row = $sth->fetchrow_array() ){
	$db = $row[1];
    }
    unless( defined( $db ) ){
	print( "Couldn't find a mysql database named " . $pipe->db_name  .
	       "Trying to create this database....\n" );
	$build_db = 1;
    }
    $sth->finish;
    #now, let's try to autocreate the database. We may be hindered by create permissions. If so,
    #need db admin to step in.
    if( $build_db ){
	$dbh->func( 'createdb', $pipe->dbname, 'admin' );
	$dbh->disconnect; #we want to terminate the old connection, try anew with db name
	#try to touch the new database
	my $dbh = DBI->connect( $pipe->dbi_connection, $pipe->dbuser, $pipe->dbpass )
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
	print( "Created database " . $pipe->db_name . " on mysql server " . $pipe->db_host . ".");
    } 
    #now, let's reconnect to the new database and make sure we have access
    $dbh->disconnect; #note this is either (un)named db given above switch
    eval{    
	my $dbh = DBI->connect( $pipe->dbi_connection, $pipe->dbuser, $pipe->dbpass )
	or die "Connection Error: $DBI::errstr\n";	
	$dbh->disconnect;
    };
    unless( $@ ){
	print( "Can connect to " . $pipe->db_name . " on mysql server " . $pipe->db_host . ".");
	$has_fails = 1;
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

if( $has_fails ){
    die "Found errors when testing the configuration file. Please see the above output for more\n";
}

sub _chk_mod{
    my $mod_str   = shift;
    my $has_fails = shift;
    if( eval( "use ${mod_str}; 1" )){
	_pr( "testing $mod_str installation", "PASS" );
    } else {
	_pr( "testing $mod_str installation", "FAIL" );
	$has_fails = 1;
    }    
    return $has_fails;
}

sub _pr{
    my $string = shift;
    my $value  = shift;
    print join( "\t", $string, $value, "\n" );
}
