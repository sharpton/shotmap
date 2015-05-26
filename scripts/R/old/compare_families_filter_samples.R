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
metadata.tab      <- Args[6]  #required
filter.field      <- Args[7]  #filter samples by this field (e.g., DATA_TYPE)
filter.value      <- Args[8]  #filter samples by this field value (e.g., metagenome)
shotmap.R.path    <- Args[9] #path to general R functions
test.type         <- Args[10]  #optional, is auto set below if NA

###For testing purposes only
#samp.abund.map <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/Abundance_Map_cid_54_aid_1.tab"
#metadata.tab <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/sample_metadata_test.tab"
#family.stem <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/Family_Diversity_cid_54_aid_1"

#samp.abund.map <- "/Users/sharptot/projects/shotmap_runs/MS_data/L4/ko/rare_267k/Abundance_Map_cid_7_aid_3.tab"
#family.stem    <- "/Users/sharptot/projects/shotmap_runs/MS_data/L4/ko/rare_267k/genome_only/Family_Comparisons_genome_only"
#metadata.tab   <- "/Users/sharptot/projects/shotmap_runs/MS_data/L4/ko/sample_metadata.tab"
#filter.field   <- "DATA_TYPE"
#filter.value    <- "metatranscriptome"
#shotmap.R.path <- "~/projects/shotmap/scripts/R/shotmap.R";


###Set autodetection thresholds
cont.thresh    = 0.2 #if there are fewer than this fraction of uniq vars in list, force discrete
n.type.plot.lim = 10  #if there are more than this number of uniq vars in list, don't plot results, only produce table files

###Set some multiple testing parameters
procs         <- c("Bonferroni", "Holm", "Hochberg", "SidakSS", "SidakSD", "BH", "BY") #used in multtest
proc2plot     <- "BH" #must be one of the above
sig.threshold <- 0.05

print( "Loading data..." );

source(shotmap.R.path)

####get the metadata
tab       <- read.table( file=metadata.tab, header=TRUE, check.names=FALSE )
#filter the meta tab by metadata value
meta      <- subset(tab, tab[,filter.field] != filter.value )
meta.names <- colnames( meta )

###get family abundances by samples
abund.tab <- read.table( file=samp.abund.map, header=TRUE, check.names=FALSE)
#filter abund.map by those samples in filtered meta
abund.map <- subset( abund.tab, abund.tab$SAMPLE.ID %in% meta$SAMPLE.ID )
write.table( file=paste(samp.abund.map, "-filtered-", filter.field, "-", filter.value, sep="" ), abund.map )

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
  if( length( types ) < 2 ){
      next
  }       
  if( length(types) > n.type.plot.lim ){
    print( paste( "There are ", length(types), " types of the field <", meta.field, ">, so I will only output tables for it", sep="" ))
    to.plot = 0
  }
  ##t.test/wilcoxon.test
  if( length( types ) == 2 & autodetect( meta[,meta.field], cont.thresh, force="discrete" ) == "discrete"){
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
    res             <- mt.rawp2adjp(rawp0, procs, na.rm=TRUE)
    adjp            <- res$adjp[order(res$index), ]
    num.p           <- length(procs) + 1  #add 1 for raw.p
    rnd.p           <- round(adjp[,1:num.p], 4)
    rownames(rnd.p) <- rownames( test.data )
    rnd.p2 <- data.frame( test.type=test.type, rnd.p)
    ##now do something with this output
    tab.file <- paste( family.stem, "-", meta.field, "-", test.type, "-pvals.tab", sep="" )
    print( paste( "Generating p-value table for ", tab.file, sep="") )
    write.table( rnd.p2, tab.file )
    if( to.plot ){
      ##plot the results
    }
  }
  ##do a Kruskal-Wallis if the number of discrete classes > 2
  else if( length( types ) > 2 & autodetect( meta[,meta.field], cont.thresh, force="discrete" ) == "discrete" ){
    print("...preparing kruskal-wallis tests...")
    classes.unsort        <-meta[,meta.field]
    names(classes.unsort) <-meta$SAMPLE.ID
    test.data <- t( ra.map )
    classes   <- classes.unsort[ colnames( test.data ) ]
    rawp0     <- apply( test.data, 1, function(x) kruskal.test( x~classes)$p.value )
    res             <- mt.rawp2adjp(rawp0, procs, na.rm=TRUE)
    adjp            <- res$adjp[order(res$index), ]
    num.p           <- length(procs) + 1  #add 1 for raw.p
    rnd.p           <- round(adjp[,1:num.p], 4)
    rownames(rnd.p) <- rownames( test.data )
    rnd.p2          <- data.frame( test.type="kruskal.test", rnd.p)
    ##now do something with this output
    tab.file        <- paste( family.stem, "-", meta.field, "-kruskal-pvals.tab", sep="" )
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
    res           <- mt.rawp2adjp( rawp0$p.value, procs, na.rm=TRUE )
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


