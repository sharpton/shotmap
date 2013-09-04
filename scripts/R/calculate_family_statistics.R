###note: need a similar function that just plots functional data for each sample, not in a comparative context

require(vegan)
require(ggplot2)
require(reshape2)

options(error=traceback)
options(error=recover)

Args              <- commandArgs()
samp.abund.map    <- Args[4]
samp.relabund.map <- Args[5]
metadata.tab      <- Args[6]
family.stem       <- Args[7]
compare.stem      <- Args[8]

###Autodetect metadata variable type
###takes a list of values and determines if likely discrete or continuous. May not be perfect!
autodetect <- function( val.list ) {
  cont.thresh = 0.2 #what is min number of unique vals that constitutes a continuous list?
  type = NULL
  ##if any item matches a character, label as discrete
  if( length(which(grepl( "[a-z|A-Z]", val.list))) > 0 ){
    type = "discrete"
    return( type )
  }
  ##see if list of numbers looks like is has many or few types, using cont.thresh as a guide
  rel.uniqs <- length( unique( val.list ) ) / length( val.list ) #relative number of unique values
  if( rel.uniqs < cont.thresh ){
    type = "discrete"
  }
  else{
    type = "continuous"
  } 
  if( is.null( type ) ){
    print( paste("Could not autodetect value types for", val.list, sep=" ") );
    exit();
  }
  return( type )
}


####get the metadata
meta       <- read.table( file=metadata.tab, header=TRUE, check.names=FALSE )
meta.names <- colnames( meta )

###get family abundances by samples
abund.map  <- read.table( file=samp.abund.map,    header=TRUE, row.names=1, check.names=FALSE )
ra.map     <- read.table( file=samp.relabund.map, header=TRUE, row.names=1, check.names=FALSE)
samples    <- rownames(ra.map)
famids     <- colnames(ra.map)

###map sampleid to family id to relative abundance using melt
for( a in 0:length( meta.names ) ){
  if( a == 0 ){ #summary data across samples
    meta.field <- "ALL"
    sub.map    <- ra.map
    types      <- c( "ALL" )
  } else {
    meta.field <- meta.names[a]    
    if( meta.field == "SAMPLE_ID" ){
      next
    }
    if( autodetect( meta[,meta.field] ) == "continuous" ){
      next
    }
    types       <- unique( meta[,field] )
  }
  for( b in 1:length( types ) ){
    type        <- types[b]
    if( type == "ALL" ){
      sub.samps <- subset( meta$SAMPLE_ID )
    } else {
      sub.samps <- subset( meta$SAMPLE_ID, meta[,a] == type )
    }
    fam.map           <- melt( t( sub.map ) ) #Var1 is famid, Var2 sampleid 
    colnames(fam.map) <- c("Family", "Sample", "RelativeAbundance" )
    ##sort families by their abundance across all samples
    fam.abunds <- apply( sub.map, 2, max ) #apply a function to help determine how to sort families
    fam.sort   <- sort( fam.abunds, decreasing=TRUE ) #sort families by their median value across samples
    fam.names  <- names( fam.sort ) #ordered list of famids
    ##create a factor based on sorted family ids
    fam.map$famid <- fam.map$Family #create a dimension that we'll turn into ordered factor
    fam.map$famid <- factor( fam.map$famid, levels = fam.names ) #create the factor
    ##calc per family statistics - each fam gets a series of stats based on RA across samples
    fam.vars      <- apply( sub.map, 2, var )
    fam.max       <- apply( sub.map, 2, max )
    fam.meds      <- apply( sub.map, 2, median )
    fam.means     <- apply( sub.map, 2, mean )
    fam.min       <- apply( sub.map, 2, min )
    fam.stats     <- data.frame( famid=names(fam.vars), variance=fam.vars, maximum=fam.max, median=fam.meds, mean=fam.means, minimum=fam.min )
    fam.stats$sorted <- fam.stats$famid #create a factor of sorted famids 
    fam.stats$sorted <- factor( fam.stats$sorted, levels = fam.names ) 
    ##Print stats per family across all and category subsets
    ##may need to limit to the top N families or something to improve readability
    for( c in 1:length( colnames( fam.stats ) ) ){
      stat <- colnames(fam.stats)[c]
      if( stat == "famid" ){
        next
      }
      ggplot( fam.stats, aes_string( x = "sorted", y = stat ) ) + geom_bar( stat = "identity", position = "dodge" ) +
        ylab( stat ) +
          xlab( "Family Rank" ) +
            theme( axis.text.x = element_blank() ) +
              labs( title = paste( "Protein Family Statistics Across all Samples: ", stat, sep="" ) )
      file      <- paste( family.stem , "-", meta.field, "-", type, "-", stat, ".pdf", sep ="" )
      print( file )
      ggsave( filename=file, plot = last_plot() )
    }
    ##Print out the relative abundances for the families that belong to samples of this type
    tab.file  <- paste( family.stem, "-", meta.field, "-", type, "-family_relative_abundances.tab", sep="") 
    write.table( fam.sort, file = tab.file )
    ##Print out the family-level summary statistics for the families that belong to samples of this type
    tab.file  <- paste( family.stem, "-", meta.field, "-", type, "-family_statistics.tab", sep="") 
    write.table( fam.stats, file = stat.file )
  }
}


