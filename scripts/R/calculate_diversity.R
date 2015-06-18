# Invoke %  R  --slave  --args  class.id  outdir  out.file.stem  metadata.tab <  calculate_diversity.R

options(error=traceback)
options(error=recover)

Args              <- commandArgs()
samp.abund.map    <- Args[4]
outpath           <- Args[5]
metadata.tab      <- Args[6]
verbose           <- Args[7]
r.lib             <- Args[8]

#samp.abund.map <- "/nfs1/Sharpton_Lab/projects/sharptot/shotmap-runs/shotmap_ms/IBD_cohort/resubmission/MetaHIT/organized_results/stats_all//no_ags//metahit_all-abundance-tables.tab"
#outpath        <- "/nfs1/Sharpton_Lab/projects/sharptot/shotmap-runs/shotmap_ms/IBD_cohort/resubmission/MetaHIT/organized_results/stats_all//no_ags/"
#metadata.tab   <- "/nfs1/Sharpton_Lab/projects/sharptot/shotmap-runs/shotmap_ms/IBD_cohort/resubmission/MetaHIT/metadata/merged_metadata.tab"
#verbose        <- 1
#r.lib          <- "/home/micro/sharptot/src/shotmap/ext/R"

#####################
### Initialization
#####################

if( is.na( samp.abund.map ) ){
    print( "You must provide a sample abundance map!" )
    exit
}

if( is.na( metadata.tab ) ){
    print( "You must provide a metadata file!" )
    exit
}

if( is.na( outpath ) ){
    print( "You must specify an output directory!" )
    exit
}

if( is.na( verbose ) | verbose == 0){
    verbose = 0
} else {
    verbose = 1
}

if( !is.na( r.lib ) ){
    .libPaths( r.lib )  
}

if( verbose ) {
    require(vegan)
    require(ggplot2)
    require(reshape2)
} else {
    msg.trap <- capture.output( suppressMessages( library( vegan ) ) )
    msg.trap <- capture.output( suppressMessages( library( ggplot2 ) ) )
    msg.trap <- capture.output( suppressMessages( library( reshape2 ) ) )
}

print.log = 0   #should rank abundance curves be plotted in log space?
topN      = 100 #how many of the most abundant families should be plotted in rank abundance curves?
stat.test = 1   #should we statistically assess diversity/metadata relationships?

#create output directories
dir.create( outpath )
dir.create( paste( outpath, "/Abundances", sep="" ))
dir.create( paste( outpath, "/Metadata", sep=""   ))

###################################
#### Good's coverage
#### takes matrices of family counts by sample and number of classified reads by sample
#### Note: May not make sense for coverage-based abundances!
###################################
goods.coverage <- function( count.map, class.map ) {  
    count = class.map
    tmap  = t(count.map)
    singletons = apply( tmap, 2, function(df){length(subset(df, df == 1 ) ) } ) 
    coverage   = 1 - ( singletons / count )
    return( coverage )
}

#####################################
### Produce family abundances by samples
#####################################
if( verbose ){
    print( "Grabbing family abundance data..." )
}
abund.df   <- read.table( file=samp.abund.map, header=TRUE, check.names=FALSE )
abund.map  <- acast(abund.df, Sample.Name~Family.ID, value.var="Abundance", fill=0 ) 
count.map  <- acast(abund.df, Sample.Name~Family.ID, value.var="Counts", fill=0 ) 
ra.map     <- acast(abund.df, Sample.Name~Family.ID, value.var="Relative.Abundance", fill=0 ) 

### write the sample-by-data matrices
# abundance table
samp.abund.file = paste( outpath, "/Abundances/Abundances.tab", sep="" )
print( paste( "Producing samples-by-abundance table here: ", samp.abund.file, sep="") )
write.table( abund.map, file = samp.abund.file, quote=FALSE )
# counts table
samp.count.file = paste( outpath, "/Abundances/Counts.tab", sep="" )
print( paste( "Producing samples-by-counts table here: ", samp.count.file, sep="") )
write.table( count.map, file = samp.count.file, quote=FALSE )
# relative abundance table
samp.ra.file    = paste( outpath, "/Abundances/Relative_abundances.tab", sep="" )
print( paste( "Producing samples-by-relative abundance table here: ", samp.ra.file, sep="") )
write.table( ra.map, file = samp.ra.file, quote=FALSE )

#################################
### Produce updated metadata file
#################################
if( verbose  ){
    print( "Grabbing metadata..." )
}
meta       <- read.table( file=metadata.tab, header=TRUE, check.names=FALSE )
#only want samples that are in our abundance data frame
meta       <- subset(meta, meta$Sample.Name %in% abund.df$Sample.Name )
#order meta by samples in abund.map
meta       <- meta[ match( rownames(abund.map), meta$Sample.Name ), ]
meta.names <- colnames( meta )
nsamples   <- dim( meta )[1]

class.map <- meta[, "Classified.Sequences"]
names(class.map) <- meta[, "Sample.Name" ]

seq.map  <- meta[, "Processed.Reads" ]
names(seq.map) <- meta[, "Sample.Name" ]

###calculate various types of diversity
if( verbose ){
    print( "Calculating Shannon Entropy..." )
}
shannon    <- diversity(abund.map)
if( verbose ) { print( "Calculating Richness..." ) }
richness   <- specnumber(abund.map)
if( verbose ) {print( "Calculating Good's Coverage..." )}
goods      <- goods.coverage(count.map, class.map)
if( verbose ) {print( "Calculating Classification Rate..." )}
class.rate <- class.map / seq.map

div.map    <- cbind( meta, shannon, richness, goods, class.rate )

div.file   <- paste( outpath, "/Metadata/Metadata-Diversity.tab", sep="" )
print( paste( "Producing diversity map file here: ", div.file, sep="") )
write.table( div.map, file = div.file, quote=FALSE )


