#!/usr/bin/R

args <- commandArgs(TRUE)

r.lib  <- args[1]
mirror <- args[2]

.libPaths( r.lib )

install.packates( "vegan", lib=r.lib, repos=mirror );
install.packates( "ggplot2", lib=r.lib, repos=mirror );
install.packates( "reshape2", lib=r.lib, repos=mirror );
install.packages( "plyr", lib=r.lib, repos=mirror );

source("http://bioconductor.org/biocLite.R")
biocLite()