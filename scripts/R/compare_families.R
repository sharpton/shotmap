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
samp.abund.map    <- Args[4]  #required
family.stem       <- Args[5]  #required
compare.stem      <- Args[6]  #required
metadata.tab      <- Args[7]  #required
test.type         <- Args[8]  #optional, is auto set below if NA

###For testing purposes only
#samp.abund.map <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/Abundance_Map_cid_54_aid_1.tab"
#metadata.tab <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/sample_metadata_test.tab"
#family.stem <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/Family_Diversity_cid_54_aid_1"
#compare.stem <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/Compare_Families_cid_54_aid_1"

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
    print( paste( "There are ", length(types), " types of the field <", meta.field, ">, so I will only output tables for it", sep="" ))
    to.plot = 0
  }
  ##t.test/wilcoxon.test
  if( length( types ) == 2 & autodetect( meta[,meta.field], cont.thresh ) == "discrete"){
    #note that wilcoxon won't give significant results if number of samples for each type < 4. Just do a t-test in that case
    type.x    <- types[1]
    type.y    <- types[2]
    x.samps   <- subset( meta, meta[,meta.field] == type.x )$SAMPLE.ID
    y.samps   <- subset( meta, meta[,meta.field] == type.y )$SAMPLE.ID
    if( is.na(test.type) ){ #if user defines it above, skip this step
      test.type <- "wilcoxon.test"
      if( length(x.samps) <= 3 & length(y.samps) <= 3 ){
        print( paste( "There aren't enough samples in each type of the field <", meta.field, "> to have the power to ",
                     "detect significant differences using a Wilcoxon Test. We'll implement a t-test instead. Note that ",
                     "this *assumes* that the samples in each type are normally distributed!", sep="") )
        test.type = "t.test"
      }
    }
    print( paste("...preparing ", test.type, " tests...", sep=""))
    fam.map.x <- ra.map[as.character(x.samps),]
    fam.map.y <- ra.map[as.character(y.samps),]
    test.data <- t(rbind( fam.map.x, fam.map.y )) #this needs to be families by samples for multtest
    classes <- c( rep(0, length(x.samps) ), rep(1, length(y.samps ) ) )
    ##RUN THE TEST
    ##t.test
    if( test.type == "t.test" ){
      rawp0 <- apply(test.data, 1, function(x) t.test(x~classes)$p.value)
    } else if( test.type == "wilcoxon.test" ){   
      ##fastest procedure seems to be applying wilcox.test to df rows
      rawp0 <- apply(test.data, 1, function(x) wilcox.test(x~classes)$p.value)
      ##from: http://www.bioconductor.org/packages/2.12/bioc/vignettes/multtest/inst/doc/multtest.pdf
      ##teststat  <- mt.teststat( test.data, classes, test="wilcoxon" )
      ##rawp0           <- 2 * (1 - pnorm(abs(teststat)))
    }
    res             <- mt.rawp2adjp(rawp0, procs)
    adjp            <- res$adjp[order(res$index), ]
    num.p           <- length(procs) + 1  #add 1 for raw.p
    rnd.p           <- round(adjp[,1:num.p], 4)
    rownames(rnd.p) <- rownames( test.data )
    rnd.p2 <- data.frame( test.type=test.type, rnd.p)
    ##now do something with this output
    tab.file <- paste( family.stem, "-", meta.field, "-", type.x, "-", type.y, "-pvals.tab", sep="" )
    print( paste( "Generating p-value table for ", tab.file, sep="") )
    write.table( rnd.p2, tab.file )
    if( to.plot ){
      ##plot the results
    }
  }
  ##do a Kruskal-Wallis if the number of discrete classes > 2
  else if( length( types ) > 2 & autodetect( meta[,meta.field], cont.thresh ) == "discrete" ){
    print("...preparing kruskal-wallis tests...")
    classes.unsort        <-meta[,meta.field]
    names(classes.unsort) <-meta$SAMPLE.ID
    test.data <- t( ra.map )
    classes   <- classes.unsort[ colnames( test.data ) ]
    rawp0     <- apply( test.data, 1, function(x) kruskal.test( x~classes)$p.value )
    res             <- mt.rawp2adjp(rawp0, procs)
    adjp            <- res$adjp[order(res$index), ]
    num.p           <- length(procs) + 1  #add 1 for raw.p
    rnd.p           <- round(adjp[,1:num.p], 4)
    rownames(rnd.p) <- rownames( test.data )
    rnd.p2          <- data.frame( test.type="kruskal.test", rnd.p)
    ##now do something with this output
    tab.file        <- paste( family.stem, "-", meta.field, "-", type.x, "-", type.y, "-pvals.tab", sep="" )
    print( paste( "Generating p-value table for ", tab.file, sep="") )
    write.table( rnd.p2, tab.file )
  }  
  ##Correlation analyses on continuous vars
  ##just linear for now, but could fit additional models in the future
  else if( length(meta$SAMPLE.ID) > 2 & autodetect( meta[,meta.field], cont.thresh ) == "continuous" ){ #spearman's correlation and lm analysis, reqs 3 or more samples
    print("...preparing spearman rank correlation tests...")
    meta.vals     <- meta[order(meta$SAMPLE.ID),][,meta.field] #have to order by sample id to map to ra.map
    test.data     <- t(ra.map)
    rawp0         <- as.data.frame(t(apply( test.data, 1, function(row){
      s<-cor.test( row, meta.vals, type="spearman" )
      c(s$estimate, s$p.value)
    } )))
    colnames(rawp0) <- c( "cor.estimate", "p.value" )
    rownames(rawp0) <- rownames( test.data )
    #do we need to correct for multiple tests? I think so...
    res           <- mt.rawp2adjp( rawp0$p.value, procs )
    adjp          <- res$adjp[order(res$index), ] #according to help, this returns rows in original order in res
    num.p         <- length(procs) + 1  #add 1 for raw.p
    rnd.p         <- round(adjp[,1:num.p], 4)
    rnd.cor       <- round(rawp0$cor.estimate, 4 )
    res           <- data.frame( test.type="spearman", cor.estimate=rnd.cor, rnd.p )
    #print results to output
    tab.file      <- paste( family.stem, "-", meta.field, "-RA_spearman_statistics.tab", sep="")
    print( paste( "Generating p-value table for ", tab.file, sep="") )
    write.table( res, tab.file )        
#    sigs          <- apply( res, 1, function(row){      
#      if( row[,plot.proc] <= sig.threshold ){
#        famid     <- row$FAMID
#        tab.file  <- paste( family.stem, "-", famid, "-", meta.field, "-RA_correlation_data.tab", sep="")
#        tmp.tab   <- as.data.frame( SAMPLE.ID = rownames( ra.map ), RELATIVE.ABUNDANCE = ra.map[,famid], meta.field = meta.vals )
#        write.table( tmp.tab, file = tab.file )
#      }
#    } )
    ##add linear fit plot here, maybe...  
  }
}


