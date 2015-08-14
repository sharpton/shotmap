Requirements & Dependencies
---------------------------

Note that [install.pl](install.pl.pm) attempts to install *all* of the packages below, and their dependencies, automatically.

###Perl Modules

####All users need these
* Benchmark
* Carp
* Capture::Tiny
* File::Basename
* File::Cat
* File::Copy
* File::Path
* File::Spec
* File::Util
* Getopt::Long
* IPC::System::Simple
* IO::Uncompress::Gunzip
* IO::Compress::Gzip
* List::Util
* Math::Random
* Parallel::ForkManager
* POSIX
* Unicode::UTF8
* XML::DOM
* XML::Tidy

###R Packages

* vegan
* ggplot2
* reshape2
* plyr
* fpc 
* grid
* coin
* MASS
* qvalue (bioconductor)
* multtest (bioconductor)
* cluster
* psych

###Translation/Gene Annotation Tools

* Metatrans
* transeq
* prodigal

###Homology Detection Tools

* HMMER (v3)
* BLAST+
* LAST
* RAPsearch (v2)

###MySQL (Only if using a mysql database - advanced users only!)

* mysql 5.5 or greater

#####Perl Modules that are only needed if using a mysql database (advanced users)
* DBIx::Class
* DBIx::BulkLoader::Mysql 
* DBI
* DBD::mysql  

Note: if mysql server is on foreign machine, DBD::mysql may need to be 
      installed by hand. see 
      http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod 
