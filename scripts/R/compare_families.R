###note: need a similar function that just plots functional data for each sample, not in a comparative context

require(vegan)
require(ggplot2)
require(reshape2)
require(multtest)

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

###Set some multiple testing parameters
procs         <- c("Bonferroni", "Holm", "Hochberg", "SidakSS", "SidakSD", "BH", "BY") #used in multtest
proc2plot     <- "BH" #must be one of the above
sig.threshold <- 0.05

####get the metadata
meta       <- read.table( file=metadata.tab, header=TRUE, check.names=FALSE )
meta.names <- colnames( meta )

###get family abundances by samples
abund.map  <- read.table( file=samp.abund.map,    header=TRUE, row.names=1, check.names=FALSE )
ra.map     <- read.table( file=samp.relabund.map, header=TRUE, row.names=1, check.names=FALSE)
samples    <- rownames(ra.map)
famids     <- colnames(ra.map)

###map sampleid to family id to relative abundance using melt
for( a in 1:length( meta.names ) ){
  meta.field <- meta.names[a]    
  if( meta.field == "SAMPLE_ID" ){
    next
  }
  if( autodetect( meta[,meta.field] ) == "continuous" ){
    next
  }
  types       <- unique( meta[,field] )
  ##right now, we only do wilcoxon on discrete classes if no more than 2 categories. Talk to KP about other options
  if( length( types ) == 2 & autodetect( meta[,meta.field] ) == "discrete"){
    type.x    <- types[1]
    type.y    <- types[2]
    x.samps   <- subset( meta, meta[,meta.field] == type.x )$SAMPLE.ID
    y.samps   <- subset( meta, meta[,meta.field] == type.y )$SAMPLE.ID
    fam.map.x <- t( ra.map )[,as.character(x.samps)]
    fam.map.y <- t( ra.map )[,as.character(y.samps)]
    test.data <- cbind( fam.map.x, fam.map.y )
    test.type <- c( rep(0, length(x.samps) ), rep(1, length(y.samps ) ) )
    teststat  <- mt.teststat( test.data, test.type, test="wilcoxon" )
    ##from: http://www.bioconductor.org/packages/2.12/bioc/vignettes/multtest/inst/doc/multtest.pdf
    rawp0           <- 2 * (1 - pnorm(abs(teststat)))    
    res             <- mt.rawp2adjp(rawp0, procs)
    adjp            <- res$adjp[order(res$index), ]
    rnd.p           <- round(adjp[,1:length(procs)], 2)
    rownames(rnd.p) <- rownames(test.data)
    ##now do something with this output
    tab.file <- paste( family.stem, "-", meta.field, "-", type.x, "-", type.y, "-pvals.tab", sep="" )
    write.table( rnd.p, tab.file )
  }
  ##Correlation analyses on continuous vars
  else if( lengths(meta$SAMPLE.ID) > 2 & autodetect( meta[,meta.field] ) == "continuous" ){ #spearman's correlation and lm analysis, reqs 3 or more samples
    meta.vals     <- meta[order(meta$SAMPLE.ID),][,meta.field] #have to order by sample id to map to ra.map
    res           <- as.data.frame(t(apply( t(ra.map), 1, function(row){
      s<-cor.test( row, meta.vals, type="spearman" )
      c(s$statistic, s$p.value)
    } )))
    colnames(res) <- c( "statistic", "p.value" )
    rownames(res) <- rownames( t( ra.map ) )
    #do we need to correct for multiple tests? I think so...
    corrected     <- mt.rawp2adjp( res$p.value, procs )
    adjp          <- corrected$adjp[order(corrected$index), ] #according to help, this returns rows in original order in res
    res           <- cbind( FAMID=rownames(res), res, adjp )
    #print results to output
    tab.file      <- paste( family.stem, "-", meta.field, "-RA_spearman_statistics.tab", sep="")
    write.table( fam.stats, file = stat.file )        
    sigs          <- apply( res, 1, function(row){      
      if( row[,plot.proc] <= sig.threshold ){
        famid     <- row$FAMID
        tab.file  <- paste( family.stem, "-", famid, "-", meta.field, "-RA_correlation_data.tab", sep="")
        tmp.tab   <- as.data.frame( SAMPLE.ID = rownames( ra.map ), RELATIVE.ABUNDANCE = ra.map[,famid], meta.field = meta.vals )
        write.table( tmp.tab, file = tab.file )
      }
    } )
    ##add linear fit plot here, maybe...  
  }
}


