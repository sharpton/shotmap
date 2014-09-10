#!/usr/bin/perl -w

use lib ($ENV{'SHOTMAP_LOCAL'} . "/scripts"); ## Allows shotmap scripts to be found in the SHOTMAP_LOCAL directory
use lib ($ENV{'SHOTMAP_LOCAL'} . "/lib"); ## Allows "Shotmap.pm and Schema.pm" to be found in the SHOTMAP_LOCAL directory. DB.pm needs this.
use lib ($ENV{'SHOTMAP_LOCAL'} . "/ext/lib/perl5");     

use strict;
use Getopt::Long;
use DBI;
use Data::Dumper;
use Shotmap;
use Shotmap::Load;

#Initialize vars
my $pipe = Shotmap->new();
$pipe->Shotmap::Notify::check_env_var( $ENV{'SHOTMAP_LOCAL'} );
$pipe->is_conf_build(1);
$pipe->Shotmap::Load::get_options( @ARGV );
$pipe->Shotmap::Load::check_vars( "build_conf_file" );
$pipe->Shotmap::Load::set_params();

if( $pipe->use_db ){
    my $db_pass;
    if( !defined( $pipe->db_pass ) ){
	print "Enter the MySQL password for user <". $pipe->dbuser ."> at database host <". $pipe->dbhost.">:\n";
	`stty -echo`;
	$db_pass = <>;
	`stty echo`;
	print "Testing MySQL connection....\n";
	chomp( $db_pass );
    }

    my $DBIstring = "DBI:mysql:host=" . $pipe->db_host; #don't want dbname in string for subsequent autocreate
    my $dbh = DBI->connect( $DBIstring, $pipe->dbuser, $db_pass )
	or die "Connection Error: $DBI::errstr\n";
    print "Looks like we can connect with these database settings.\n";
}
print "Building conf-file...\n";
my $conf_file = $pipe->{"opts"}->{"conf-file"};
open( OUT, ">$conf_file" ) || die "Can't open $conf_file for write: $!\n";
foreach my $key( keys( %{ $pipe->{"opts"} } ) ){
    my $value = $pipe->{"opts"}->{$key};
    if( defined( $value ) ){
	print OUT "--${key}=${value}\n";
    }
}    
close OUT;

`chmod 0600 $conf_file`;
print "Confile created here with permissions 0600: $conf_file\n";
