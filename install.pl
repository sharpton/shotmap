#!/usr/bin/perl -w 

use strict;
use File::Path;
use File::Basename;
use Cwd;
use Getopt::Long;

my $testing = 0;

my $perlmods  = 1; #should we install perl modules
my $rpackages = 1; #should we install R modules
my $algs      = 1; #should we install 3rd party gene prediction/search algorithms?
my $clean     = 1; #wipe old installations of algs?
my $get       = 1; #download alg source code?
my $build     = 1; #build alg source code?
my $test      = 1; #should we run make checks during build?
my $db        = 0;

GetOptions(
    "use-db!" => \$db, #try to build the libraries needed for mysql communication
    );

#see if env var is defined. If not, try to add it.
if( !defined( $ENV{'SHOTMAP_LOCAL'} ) ){
    my $dir = getcwd;
    system( "echo 'export SHOTMAP_LOCAL=${dir} >> ~/.bash_profile'" );
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
    system( "Rscript ${inc}/packages.R ${rlib} ${mirror}" );
}

######################
######################
# Install 3rd Party Applications
if( $algs ){

    my $rapsearch_src  = "https://github.com/zhaoyanswill/RAPSearch2";
    #my $hmmer_src      = "ftp://selab.janelia.org/pub/software/hmmer3/3.1b1/hmmer-3.1b1-linux-intel-x86_64.tar.gz";
    my $hmmer_src      = "ftp://selab.janelia.org/pub/software/hmmer3/3.1b1/hmmer-3.1b1.tar.gz";
    #my $blast_src      = "ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.2.29+-x64-linux.tar.gz";
    my $blast_src      = "ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.2.29+-src.tar.gz";
    my $last_src       = "http://last.cbrc.jp/last-475.zip";
    my $transeq_src    = "ftp://emboss.open-bio.org/pub/EMBOSS/EMBOSS-6.6.0.tar.gz";
    my $prodigal_src   = "https://github.com/hyattpd/Prodigal/archive/v2.6.1.tar.gz";
    my $mbcensus_src   = "https://github.com/snayfach/MicrobeCensus.git";
    my $metatrans_src  = "https://github.com/snayfach/metatrans.git";

    my $rapsearch_stem = "RAPSearch2";
    #my $hmmer_stem     = "hmmer-3.1b1-linux-intel-x86_64";
    my $hmmer_stem     = "hmmer-3.1b1";
    #my $blast_stem     = "ncbi-blast-2.2.29+";
    my $blast_stem     = "ncbi-blast-2.2.29+-src";
    my $last_stem      = "last-475";
    my $transeq_stem   = "EMBOSS-6.6.0";
    my $prodigal_stem  = "Prodigal-2.6.1";
    my $mbcensus_stem  = "MicrobeCensus";
    my $metatrans_stem = "metatrans";

    my $rapsearch = "${pkg}/${rapsearch_stem}/";
    my $hmmer     = "${pkg}/${hmmer_stem}/";
    my $blast     = "${pkg}/${blast_stem}/c++/";
    my $last      = "${pkg}/${last_stem}/";
    my $transeq   = "${pkg}/${transeq_stem}/";
    my $prodigal  = "${pkg}/${prodigal_stem}/";
    my $microbecensus = "${pkg}/${mbcensus_stem}/";
    my $metatrans     = "${pkg}/${metatrans_stem}/";

    my $algs = {
        "rapsearch" => $rapsearch,
        "hmmer"     => $hmmer,
        "blast"     => $blast,
        "last"      => $last,
        "transeq"   => $transeq,
        "prodigal"  => $prodigal,
        "microbecensus" => $microbecensus,
        "metatrans"     => $metatrans,
    };

    my $srcs = {
	"rapsearch" => $rapsearch_src,
	"hmmer"     => $hmmer_src,
	"blast"     => $blast_src,
	"last"      => $last_src,
	"transeq"   => $transeq_src,
	"prodigal"  => $prodigal_src,
	"microbecensus" => $mbcensus_src,
	"metatrans"     => $metatrans_src,
    };

    ######################
    # RAPsearch2
    
    my $alg = "rapsearch";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/prerapsearch;bin/rapsearch", $algs->{$alg} );
    }
    if( $get ){
	get_src( $srcs->{$alg}, $pkg, "git" );
    }
    if( $build ){
	build_src( $algs->{$alg}, "./install" );
    }
    link_src( $algs->{$alg} . "/bin/prerapsearch;" . 
	      $algs->{$alg} . "/bin/rapsearch"     , 
	      $bin );
    print "\t...done with ${alg}\n";
    
    ######################
    # HMMER v3 
    
    $alg = "hmmer";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/hmmsearch;" . 
		   "bin/hmmscan", 
		   $algs->{$alg}, 
		   "${pkg}" . basename( $srcs->{$alg})  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $pkg, "wget" );
	decompress_src( $pkg, basename( $srcs->{$alg} ) );
    }
    if( $build ){
	if( $test ){
	    build_src( $algs->{$alg}, "./configure;make; make check" );	    
	} else{ 
	    build_src( $algs->{$alg}, "./configure;make" );	    
	}
    }
    link_src( $algs->{$alg} . "/src/hmmsearch;" . 
	      $algs->{$alg} . "/src/hmmscan"    , 
	      $bin );
    print "\t...done with ${alg}\n";
    
    ######################
    # BLAST+
    
    $alg = "blast";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/blastp;"    .
		   "bin/makeblastdb", 
		   $algs->{$alg}, 
		   "${pkg}" . basename( $srcs->{$alg})  ); 
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $pkg, "wget" );
	decompress_src( $pkg, basename( $srcs->{$alg} ) );
    }
    if( $build ){
	if( $test ){
	    build_src( $algs->{$alg}, "./configure;make check; make" );	    
	} else{ 
	    build_src( $algs->{$alg}, "./configure;make" );	    
	}
    }
    link_src( $algs->{$alg} . "/ReleaseMT/bin/blastp;" . 
	      $algs->{$alg} . "/ReleaseMT/bin/makeblasatdb", 
	      $bin );
    print "\t...done with ${alg}\n";
    
    ######################
    # LAST
    
    $alg = "last";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/lastal;" . 
		   "bin/lastdb"  , 
		   $algs->{$alg}, "${pkg}" . basename( $srcs->{$alg} )  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $pkg, "wget" );
	decompress_src( $pkg, basename( $srcs->{$alg} ) );
    }
    if( $build ){
	build_src( $algs->{$alg}, "make" );	    	
    }
    link_src( $algs->{$alg} . "/src/lastal;" . 
	      $algs->{$alg} . "/src/lastdb" , 
	      $bin );
    print "\t...done with ${alg}\n";
    
    ######################
    # TRANSEQ
    
    $alg = "transeq";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/transeq", 
		   $algs->{$alg},
		   "${pkg}" . basename( $srcs->{$alg} )  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $pkg, "wget" );
	decompress_src( $pkg, basename( $srcs->{$alg} ) );
    }
    if( $build ){
	if( $test ){
	    build_src( $algs->{$alg}, "./configure  --without-x; make; make check" );	    	
	} else {
	    build_src( $algs->{$alg}, "./configure --without-x; make" );	    	
	}
    }
    link_src( $algs->{$alg}. "/emboss/transeq;", $bin );
    print "\t...done with ${alg}\n";
    
    ######################
    # PRODIGAL
    
    $alg = "prodigal";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/prodigal", 
		   $algs->{$alg} , 
		   "${pkg}" . basename( $srcs->{$alg} )  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $pkg, "wget" );
	decompress_src( $pkg, basename( $srcs->{$alg} ) );
    }
    if( $build ){
	build_src( $algs->{$alg}, "make install INSTALLDIR=./bin/" ); 
    }
    link_src( $algs->{$alg} . "bin/prodigal" , 
	      $bin );
    print "\t...done with ${alg}\n";
        
    ######################
    # MICROBECENSUS
    
    $alg = "microbecensus";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/microbe_census.py;" .
		   "bin/ags_functions.py"   ,
		   $algs->{$alg}, 
		   "${pkg}" . basename( $srcs->{$alg} )  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $pkg, "git" );
	decompress_src( $pkg, basename( $srcs->{$alg} ) );
    }
    if( $build ){
	#do nothing
    }
    link_src( $algs->{$alg} . "/src/ags_functions.py;" . 
	      $algs->{$alg} . "/src/microbe_census.py"  , 
	      $bin );
    print "\t...done with ${alg}\n";
    
    ######################
    # METATRANS

    $alg = "metatrans";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/metatrans.py;" ,
		   $algs->{$alg}, 
		   "${pkg}" . basename( $srcs->{$alg} )  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $pkg, "git" );
	decompress_src( $pkg, basename( $srcs->{$alg} ) );
    }
    if( $build ){
	#do nothing
    }
    link_src( $algs->{$alg} . "/metatrans.py" , 
	      $bin );
    print "\t...done with ${alg}\n";

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

sub decompress_src{
    my $loc = shift; #path to directory containing download, relative to shotmap root
    my $stem = shift; #name of the downloaded file

    print "decompressing source...\n";
    chdir( $loc );
    if( $stem =~ m/\.tar\.gz/ ){
	system( "tar xzf $stem" );
    }
    if( $stem =~ m/\.zip/ ){
	system( "unzip $stem" );
    }
    else{
	warn "No decompression needed for $stem\n";
    }
    chdir( $ROOT );
    return;
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
