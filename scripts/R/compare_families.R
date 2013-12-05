###note: need a similar function that just plots functional data for each sample, not in a comparative context

require(vegan)
require(ggplot2)
require(reshape2)
require(multtest)

###NOTE: you may need to update bioconductor for multtest. Open R and do the following
### > source("http://bioconductor.org/biocLite.R")
### > biocLite("multtest")


options(error=traceback)
options(error=recover)

Args              <- commandArgs()
samp.abund.map    <- Args[4]
metadata.tab      <- Args[6]
family.stem       <- Args[7]
compare.stem      <- Args[8]

#For testing purposes only
samp.abund.map <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/Abundance_Map_cid_54_aid_1.tab"
metadata.tab <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/sample_metadata.tab"
sample.stem <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/Family_Diversity_cid_54_aid_1"
compare.stem <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/Compare_Families_cid_54_aid_1"

###Set autodetection thresholds
cont.thresh    = 0.2 #if there are fewer than this fraction of uniq vars in list, force discrete
n.type.plot.lim = 10  #if there are more than this number of uniq vars in list, don't plot results, only produce table files

###Set some multiple testing parameters
procs         <- c("Bonferroni", "Holm", "Hochberg", "SidakSS", "SidakSD", "BH", "BY") #used in multtest
proc2plot     <- "BH" #must be one of the above
sig.threshold <- 0.05

###Autodetect metadata variable type
###takes a list of values and determines if likely discrete or continuous. User defined thresholds required!
autodetect <- function( val.list, cont.thresh) {
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

print( "Loading data..." );

####get the metadata
meta       <- read.table( file=metadata.tab, header=TRUE, check.names=FALSE )
meta.names <- colnames( meta )

###get family abundances by samples
abund.map <- read.table( file=samp.abund.map, header=TRUE, check.names=FALSE)
ra.map    <- abund.map
ra.map$ABUNDANCE <- NULL #don't need the abundance field for this script
a.tmp     <- melt(ra.map, id=c("SAMPLE.ID","FAMILY.ID") ) #reshape ra.map to get sample.ids by fam.ids
ra.map    <- dcast(a.tmp, SAMPLE.ID~FAMILY.ID) 
row.names(ra.map) <- ra.map$SAMPLE.ID #push sampleids to the rowname and drop the column from the df
ra.map$SAMPLE.ID <- NULL
samples   <- rownames(ra.map)
famids    <- colnames(ra.map)

###map sampleid to family id to relative abundance using melt
for( a in 1:length( meta.names ) ){
  to.plot = 1
  meta.field <- meta.names[a]    
  if( meta.field == "SAMPLE.ID" | meta.field == "SAMPLE.ALT.ID" ){
    next
  }
  ##was was this here previously? I don't think it make sense to skip, we just don't want to plot
  if( autodetect( meta[,meta.field] ) == "continuous" ){
    ##next
  }
  print( paste("Processing <", meta.field, ">...", sep="") )
  types <- unique( meta[,meta.field] )
  
  if( length(types) > n.type.plot.lim ){
    print( paste( "There are ", length(types), " types of the field <", meta.field, ">, so I will only output tables for it" ) )
    to.plot = 0
  }
  ##right now, we only do wilcoxon on discrete classes if no more than 2 categories. Talk to KP about other options
  if( length( types ) == 2 & autodetect( meta[,meta.field], cont.thresh ) == "discrete"){
    type.x    <- types[1]
    type.y    <- types[2]
    x.samps   <- subset( meta, meta[,meta.field] == type.x )$SAMPLE.ID
    y.samps   <- subset( meta, meta[,meta.field] == type.y )$SAMPLE.ID
    fam.map.x <- ra.map[as.character(x.samps),]
    fam.map.y <- ra.map[as.character(y.samps),]
    test.data <- t(rbind( fam.map.x, fam.map.y )) #this needs to be families by samples for multtest
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
    if( to.plot ){
      ##plot the results
    }
  } else if( length( types ) > 2 & autodetect( meta[,meta.field], cont.thresh ) == "discrete" ){
    
  }
  ##Correlation analyses on continuous vars
  else if( lengths(meta$SAMPLE.ID) > 2 & autodetect( meta[,meta.field], cont.thresh ) == "continuous" ){ #spearman's correlation and lm analysis, reqs 3 or more samples
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


