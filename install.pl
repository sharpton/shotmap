#!/usr/bin/perl -w 

use strict;
use File::Path;
use File::Basename;
use Cwd;
use Getopt::Long qw(GetOptionsFromString GetOptionsFromArray);
use Carp;
use Data::Dumper;

$SIG{ __DIE__ } = sub { Carp::confess( @_ ) };

my $testing = 0;

my $options = get_options( \@ARGV );

my $perlmods  = $options->{"perlmods"};
my $rpackages = $options->{"rpacks"};
my $algs      = $options->{"algs"};
my $clean     = $options->{"clean"};
my $get       = $options->{"get"};
my $build     = $options->{"build"};
my $test      = $options->{"test"};
my $db        = $options->{"db"};
my $source    = $options->{"source"};
my $all       = $options->{"all"};
my $iso_alg;
if( defined( $options->{"iso-alg"} ) ){
    $iso_alg = $options->{"iso-alg"};
}

#see if env var is defined. If not, try to add it.
if( !defined( $ENV{'SHOTMAP_LOCAL'} ) ){
    my $dir = getcwd;
    #we still need to load into current shell
    $ENV{'SHOTMAP_LOCAL'} = $dir;
    my $shotmap = $ENV{'SHOTMAP_LOCAL'} . "/scripts/shotmap.pl";
    unless( -e $shotmap ){
        die( "You haven't set the bash environmental variable \$SHOTMAP_LOCAL. " .
	     "I tried to set it for you, but failed (using your current directory " .
	     "I found ${dir}, which doesn't seem correct). Please either execute this " .
	     "installation script from the root shotmap repository directory, or add " .
	     "the variable to your ~/.bash_profile (or ~/.profile or ~/.bashrc, depending " .
	     "on what exists in your home directory) yourself. You should probably add " .
	     "something like the following:\n\n" .
	     "export SHOTMAP_LOCAL=<path_to_shotmap_repository>\n" );
    } else{
	#I'm not a fan of automatically messing with people's bash_profiles
	#system( "echo 'export SHOTMAP_LOCAL=${dir}' >> ~/.bash_profile" );
	#"${pkg}/${mbcensus_stem}/";
	#my $mbcensus_stem  = "MicrobeCensus";
	#"echo -e \"\nexport PYTHONPATH=\$PYTHONPATH:" . $algs->{$alg} . "\" >> ~/.bash_profile;";
	#"echo -e \"\nexport PATH=\$PATH:" . $algs->{$alg} . "/scripts/\" >> ~/.bash_profile" );
	#NEED SIMILAR COMMAND FOR TRANSEQ AND PRODIGAL

    }
}

our $ROOT = $ENV{'SHOTMAP_LOCAL'}; #top level of shotmap directory

if( $testing ){
    $ROOT = "/home/micro/sharptot/projects/shotmap-dev/shotmap/";
}
my $root = $ROOT;

my $inc = "${root}/inc/"; #location of included source code (cpanm)
my $pkg = "${root}/pkg/"; #location that we'll place algorithms
my $ext = "${root}/ext/"; #location of installed external perl modules (separate so we can wipe)
my $bin = "${root}/bin/"; #location of installed executables (symlinks)

#R variables
my $rlib   = "${ext}/R/";
my $mirror = "http://ftp.osuosl.org/pub/cran/"; # Pick yours from this list: http://cran.r-project.org/mirrors.html

system( "mkdir -p $rlib" );
system( "mkdir -p $pkg" );

######################
# Install Perl Module Dependencies using cpanm
if( $perlmods ){
 my @mods = (
     "IPC::System::Simple",
     "IO::Uncompress::Gunzip",
     "IO::Compress::Gzip",
     "Carp",
     "File::Util",
     "File::Cat",
     "Unicode::UTF8",
     "XML::DOM",
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
 if( $db ){
     print( "\n\nYou are asking me to build the mysql database communication " .
	    "modules. I'll do my best to install them, but note that some " .
	    ", especially DBD::mysql, can be finky and require installation by " .
	    "hand given system-specific settings. If this fails, see this link:\n" .
	    "http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod\n\n\n" 
	 );
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
     my $cmd = "perl ${bin}/cpanm -L ${ext} ${mod}";
     system( $cmd );
 }
}

######################
# R PACKAGES
if( $rpackages ){
    print( "Installing R packages...\n" );
    system( "Rscript ${inc}/packages.R ${rlib} ${mirror}" );
}

######################
######################
# Install 3rd Party Applications
if( $algs ){
    my $alg_data = parse_alg_data( $root . "/installer_alg_data.txt", $source, $test);
    foreach my $alg( keys( %$alg_data ) ){
	if( defined( $iso_alg ) ){
	    next if( $alg ne $iso_alg );
	}
	my $src   = $alg_data->{$alg}->{"src"};
	my $stem  = $alg_data->{$alg}->{"stem"};
	my $links = $alg_data->{$alg}->{"links"};
	my $build = $alg_data->{$alg}->{"build"};
	my $bins  = $alg_data->{$alg}->{"bins"};	    
	my $dload = $alg_data->{$alg}->{"download"};	    

	print "Installing ${alg}...\n";
	#need a better way to automate this step...
	my $alg_pkg = "${pkg}/${stem}/";
	if( $alg eq "blast" && $source ){
	    $alg_pkg = "${pkg}/${stem}/c++/";
	}
	if( $clean ){
	    clean_src( $links,
		       $alg_pkg, 
		       "${pkg}" . basename( $src ) 
		);
	}    
	if( $get ){
	    get_src( $src, $pkg, $dload );
	    decompress_src( $pkg, basename( $src ) );
	}
	if( $build ){
	    unless( $build eq "NA" ){
		build_src( $alg_pkg, $build );	    
	    }
	}
	foreach my $target( split( "\;", $bins ) ){
	    link_src( $alg_pkg . $target, 
		      $bin );
	}
	print "\t...done with ${alg}\n";
    }
    my $mc = $alg_data->{"microbecensus"}->{"stem"};
    print( "The requested items have been installed. If you haven't already, please be sure " .
	   "to make the following additions to your ~/.bash_profile:\n" .
	   "###################################\n"               . 
	   "export SHOTMAP_LOCAL=${root}\n"                      .
	   "export PYTHONPATH=\${PYTHONPATH}:${pkg}/${mc}/\n"    .
	   "export PATH=\$PATH:${pkg}/${mc}/scripts/\n"          .
	   "export PATH=\$PATH:\${SHOTMAP_LOCAL}/bin/\n"         .
	   "export PERL5LIB=\$PERL5LIB:\${SHOTMAP_LOCAL}/lib/\n" .
	   "###################################\n" 
	);
    print( "If you like, you can copy and paste the following command to automate the above entries:\n" . 
	   "###################################\n"                                         . 
	   "echo 'export SHOTMAP_LOCAL=${root}' >> ~/.bash_profile\n"                      .
	   "echo 'export PYTHONPATH=\${PYTHONPATH}:${pkg}/${mc}/' >> ~/.bash_profile\n"    .
	   "echo 'export PATH=\$PATH:${pkg}/${mc}/scripts/' >> ~/.bash_profile\n"          .
	   "echo 'export PATH=\$PATH:\${SHOTMAP_LOCAL}/bin/' >> ~/.bash_profile\n"         .
	   "echo 'export PERL5LIB=\$PERL5LIB:\${SHOTMAP_LOCAL}/lib/' >> ~/.bash_profile\n" .
	   "###################################\n" 
	);
}



###############
###############
### SUBROUTINES

    
sub build_src{
    my $loc = shift; #path to the downloaded, decompressed source, relative to shotmap root
    my $cmds =  shift; #semicolon delimited list of commands

    print "building source...\n";
    print "$loc\n";
    chdir( $loc );
    my @commands = split( "\;", $cmds );
    foreach my $command( @commands ){
	system( "$command" );
    }
    chdir( $ROOT );
    return;
}

sub check_name{
    my $name = shift;
    if( ! defined( $name ) ){
	die "Could not find a name when parsing alg_data!";
    }
}

sub decompress_src{
    my $loc = shift; #path to directory containing download, relative to shotmap root
    my $stem = shift; #name of the downloaded file

    print "decompressing source...\n";
    chdir( $loc );
    #if( ! -e $stem ){
	#die "For some reason, I didn't download $stem into $loc. " . 
	#    "Please try to reproduce this error before contacting " . 
	#    "the author for assistance\n";
    #}
    if( $stem =~ m/\.tar\.gz/ ){
	system( "tar xzf $stem" );
    }
    elsif( $stem =~ m/\.zip/ ){
	system( "unzip $stem" );
    }
    else{
	warn "No decompression needed for $stem\n";
    }
    chdir( $ROOT );
    return;
}

sub dereference_options{
    my $options = shift; #hashref
    foreach my $key( keys( %$options )){
	my $value = $options->{$key};
	if( defined( $value ) ){
	    $options->{$key} = ${ $value };
	}
    }
    return $options;
}


sub get_src{
    my $url = shift;
    my $loc = shift;
    my $method = shift; #git, wget

    print "downloading source...\n";
    chdir( $loc );
    if( $method eq "git" ){
	system( "git clone $url" );
    }
    elsif( $method eq "wget" ){
	system( "wget $url" );
    }
    else{
	die( "I don't know how to deal with the download method $method\n");
    }  
    chdir( $ROOT );
    return;
}

sub clean_src{
    my $link_names = shift;
    my $src_dir    = shift;
    my $dl_stem    = shift; #the downloaded compressed file, if it exists

    print "\tcleaning old install...\n";
    foreach my $link( split( "\;", $link_names ) ){
	print( "removing $link\n" );
	unlink( $link );
    }
    if( -d "${src_dir}" ){
	rmtree( "${src_dir}" );
    }
    if( defined( $dl_stem )) { 
	if( -e "${dl_stem}"){
	    unlink( "${dl_stem}" );
	}
    }

    chdir( $ROOT );
    return;
}

sub get_options{
    my $ra_args  = shift;
    my @args     = @{ $ra_args };

    #DEFAULT VALUES
    my $perlmods  = 0; #should we install perl modules
    my $rpackages = 0; #should we install R modules
    my $algs      = 0; #should we install 3rd party gene prediction/search algorithms?
    my $clean     = 0; #wipe old installations of algs?
    my $get       = 0; #download alg source code?
    my $build     = 0; #build alg source code?
    my $test      = 0; #should we run make checks during build?
    my $db        = 0; #should we install myql libraries? 
    my $all       = 1; 
    my $source    = 0; #should we build from source instead of x86 libraries
    my $iso_alg;       #let's only build one specific algoritm.

    my %ops = (
	"use-db"   => \$db, #try to build the libraries needed for mysql communication
	"source"   => \$source,
	"clean"    => \$clean,
	"test"     => \$test,
	"build"    => \$build,
	"get"      => \$get,
	"algs"     => \$algs,
	"rpacks"   => \$rpackages,
	"perlmods" => \$perlmods,
	"all"      => \$all,
	"iso-alg"  => \$iso_alg,
	);
    
    my @opt_type_array = (
	"use-db!",
	"source!",
	"clean!",
	"test!",
	"build!",
	"get!",
	"algs!",
	"rpacks!",
	"perlmods!",
	"iso-alg:s"
	);
    
    print "Note that this installer attempts to install precompiled x86 binaries when possible. If ".
	"this doesn't work for your architecture, please rerun the installer and invoke --source\n";
    
    GetOptionsFromArray( \@args, \%ops, @opt_type_array );
    %ops = %{ dereference_options( \%ops ) };

    if( $ops{"perlmods"} || 
	$ops{"rpacks"}   ||
	$ops{"algs"}     ||
	$ops{"clean"}    ||
	$ops{"get"}      ||
	$ops{"build"}    ||
	$ops{"test"}     ||
	$ops{"source"}   ){
	print "You specified a modular aspect of installation, so I will not run the entire " .
	    "installation pipeline\n";
	$ops{"all"} = 0;
    }

    #If we clean and want to build, we must also get.
    if( $ops{"clean"} && 
	$ops{"build"} ){
	$ops{"get"} = 1;
    }

    if( $ops{"all"} ){
	$ops{"perlmods"} = 1;
	$ops{"rpacks"}   = 1;
	$ops{"algs"}     = 1;
	$ops{"clean"}    = 1;
	$ops{"get"}      = 1;
	$ops{"build"}    = 1;
	$ops{"test"}     = 1;
    }
    return \%ops;
}

sub link_src{
    my $targets = shift; #must be path to target relative to shotmap root, semicolon sep list
    my $linkdir = shift;
    
    print "creating symlinks...\n";
    chdir( $linkdir );
    foreach my $target( split( "\;", $targets ) ){
	system( "chmod a+x ${target}" );
	system( "ln -s ${target}" );
    }
    chdir( $ROOT );
    return;
}

sub parse_alg_data{
    my $file     = shift;
    my $source   = shift;
    my $test     = shift;
    my $alg_data = ();
    open( IN, $file ) || die "Can't open $file for read: $!\n";
    my $name;
    while(<IN>){
	chomp $_;
	if( $_ =~ /^name/ ){
	    (my $string, $name ) = split( "\:", $_ );

	}  elsif( $_ =~ /^download/ ){
	    check_name( $name );
	    my ($string, $value ) = split( "\:", $_ );
	    $alg_data->{$name}->{"download"} = $value;
	    	   
	} elsif( $_ =~ /^x86\:/ ){
	    next if( $source );
	    check_name( $name );
	    #srcs may have : in the http/ftp string
	    my ($string, $value, @rest ) = split( "\:", $_ );
	    $value = join( ":", $value, @rest );
	    $alg_data->{$name}->{"src"} = $value;
	} elsif( $_ =~ /^src\:/ ){
	    next unless( $source );
	    check_name( $name );
	    my ($string, $value, @rest ) = split( "\:", $_ );
	    $value = join( ":", $value, @rest );
	    $alg_data->{$name}->{"src"} = $value;

	} elsif( $_ =~ /^x86stem/ ){
	    next if( $source );
	    check_name( $name );
	    my ($string, $value ) = split( "\:", $_ );
	    $alg_data->{$name}->{"stem"} = $value;
	} elsif( $_ =~ /^srcstem/ ){
	    next unless( $source );
	    check_name( $name );
	    my ($string, $value ) = split( "\:", $_ );
	    $alg_data->{$name}->{"stem"} = $value;

	} elsif( $_ =~ /^x86bins/ ){
	    next if( $source );
	    check_name( $name );
	    my ($string, $value ) = split( "\:", $_ );
	    $alg_data->{$name}->{"bins"} = $value;
	} elsif( $_ =~ /^srcbins/ ){
	    next unless( $source );
	    check_name( $name );
	    my ($string, $value ) = split( "\:", $_ );
	    $alg_data->{$name}->{"bins"} = $value;

	} elsif( $_ =~ /^testcmds/ ){
	    next unless( $test );
	    check_name( $name );
	    my ($string, $value ) = split( "\:", $_ );
	    $alg_data->{$name}->{"build"} = $value;
	} elsif( $_ =~ /^srccmds/ ){
	    next if( $test );
	    check_name( $name );
	    my ($string, $value ) = split( "\:", $_ );
	    $alg_data->{$name}->{"build"} = $value;

	} elsif( $_ =~ /^installed/ ){
	    check_name( $name );
	    my ($string, $value ) = split( "\:", $_ );
	    $alg_data->{$name}->{"links"} = $value;
	} elsif( $_ =~ m/^$/ ){
	    $name    = undef;
	}
    }
    close IN;
    return $alg_data;
}
