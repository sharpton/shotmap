Requirements & Dependencies
---------------------------

Note that install.pl attempts to install *all* of the packages below, and their dependencies, automatically.

###Perl Modules

####All users need these
* IPC::System::Simple
* IO::Uncompress::Gunzip
* IO::Compress::Gzip
* Carp
* File::Util
* File::Cat
* Unicode::UTF8
* XML::DOM
* XML::Tidy
* Math::Random
* Parallel::ForkManager
* File::Basename
* File::Copy
* File::Path
* File::Spec
* Getopt::Long
* Capture::Tiny

#####Only needed if using a mysql database (advanced users)
* DBIx::Class
* DBIx::BulkLoader::Mysql 
* DBI
* DBD::mysql  

Note: if mysql server is on foreign machine, DBD::mysql may need to be 
      installed by hand. see 
      http://search.cpan.org/dist/DBD-mysql/lib/DBD/mysql/INSTALL.pod 

###MySQL (Only if using a mysql database - advanced users)

* mysql 5.5 or greater

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

###Translation/Gene Annotation Tools

* Metatrans
* transeq
* prodigal

###Homology Detection Tools

* HMMER (v3)
* BLAST+
* LAST
* RAPsearch (v2)


