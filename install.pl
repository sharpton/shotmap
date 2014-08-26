#!/usr/bin/perl -w 

use strict;
use File::Path;
use File::Basename;

my $testing = 1;

my $perlmods  = 0; #should we install perl modules
my $rpackages = 0; #should we install R modules
my $algs      = 1; #should we install 3rd party gene prediction/search algorithms?
my $clean     = 1; #wipe old installations of algs?
my $get       = 1; #download alg source code?
my $build     = 0; #build alg source code?
my $test      = 0; #should we run make checks during build?

our $ROOT = $ENV{'SHOTMAP_LOCAL'}; #top level of shotmap directory


if( $testing ){
    $ROOT = "/home/micro/sharptot/projects/shotmap-dev/shotmap/";
}
my $root = $ROOT;


my $inc = "${root}/inc/"; #location of included source code
my $ext = "${root}/ext/"; #location of installed external perl modules (separate so we can wipe)
my $bin = "${root}/bin/"; #location of installed executables (symlinks)

#R variables
my $rlib   = "${ext}/R/";
my $mirror = "http://ftp.osuosl.org/pub/cran/"; # Pick yours from this list: http://cran.r-project.org/mirrors.html

system( "mkdir -p $rlib" );

######################
# Install Perl Module Dependencies using cpanm
if( $perlmods ){
 my @mods = (
     "DBIx::Class",
     "DBIx::BulkLoader::Mysql",
     "IPC::System::Simple",
     "IO::Uncompress::Gunzip",
     "IO::Compress::Gzip",
     "Bio::SeqIO",
     "Carp",
     "File::Util",
     "File::Cat",
     "Unicode::UTF8",
     "XML::DOM",
     "XML::Tidy",
     "Math::Random",
     "Parallel::ForkManager",
     "DBI",
     "DBD::mysql", #if mysql server is on foreign machine, install by hand
                   #see http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod     
     "File::Basename",
     "File::Copy",
     "File::Path",
     "File::Spec",
     "Getopt::Long"
     );
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

    my $rapsearch = "${inc}/${rapsearch_stem}/";
    my $hmmer     = "${inc}/${hmmer_stem}/";
    my $blast     = "${inc}/${blast_stem}/c++/";
    my $last      = "${inc}/${last_stem}/";
    my $transeq   = "${inc}/${transeq_stem}/";
    my $prodigal  = "${inc}/${prodigal_stem}/";
    my $microbecensus = "${inc}/${mbcensus_stem}/";
    my $metatrans     = "${inc}/${metatrans_stem}/";

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
	get_src( $srcs->{$alg}, $inc, "git" );
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
		   "${inc}" . basename( $srcs->{$alg})  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $inc, "wget" );
	decompress_src( $inc, basename( $srcs->{$alg} ) );
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
		   "${inc}" . basename( $srcs->{$alg})  ); 
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $inc, "wget" );
	decompress_src( $inc, basename( $srcs->{$alg} ) );
    }
    if( $build ){
	if( $test ){
	    build_src( $algs->{$alg}, "./configure;make check; make" );	    
	} else{ 
	    build_src( $algs->{$alg}, "./configure;make" );	    
	}
    }
    link_src( $algs->{$alg} . "/bin/blastp;" . 
	      $algs->{$alg} . "/bin/makeblasatdb", 
	      $bin );
    print "\t...done with ${alg}\n";
    
    ######################
    # LAST
    
    $alg = "last";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/lastal;" . 
		   "bin/lastdb"  , 
		   $algs->{$alg}, "${inc}" . basename( $srcs->{$alg} )  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $inc, "wget" );
	decompress_src( $inc, basename( $srcs->{$alg} ) );
    }
    if( $build ){
	build_src( $algs->{$alg}, "make" );	    	
    }
    link_src( $algs->{$alg} . "/bin/lastal;" . 
	      $algs->{$alg} . "/bin/lastdb" , 
	      $bin );
    print "\t...done with ${alg}\n";
    
    ######################
    # TRANSEQ
    
    $alg = "transeq";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/transeq", 
		   $algs->{$alg},
		   "${inc}" . basename( $srcs->{$alg} )  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $inc, "wget" );
	decompress_src( $inc, basename( $srcs->{$alg} ) );
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
		   "${inc}" . basename( $srcs->{$alg} )  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $inc, "wget" );
	decompress_src( $inc, basename( $srcs->{$alg} ) );
    }
    if( $build ){
	build_src( $algs->{$alg}, "make install INSTALLDIR=./bin/" ); 
    }
    link_src( $algs->{$alg} . "bin/prodigal" , 
	      $bin );
    print "\t...done with ${alg}\n";
        
    ######################
    # MICROBECENSUS
    
    my $alg = "microbecensus";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/microbe_census.py;" .
		   "bin/ags_functions.py"   ,
		   $algs->{$alg}, 
		   "${inc}" . basename( $srcs->{$alg} )  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $inc, "git" );
	decompress_src( $inc, basename( $srcs->{$alg} ) );
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

    my $alg = "metatrans";
    print "Installing ${alg}...\n";
    if( $clean ){
	clean_src( "bin/metatrans.py;" ,
		   $algs->{$alg}, 
		   "${inc}" . basename( $srcs->{$alg} )  );
    }    
    if( $get ){
	get_src( $srcs->{$alg}, $inc, "git" );
	decompress_src( $inc, basename( $srcs->{$alg} ) );
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
