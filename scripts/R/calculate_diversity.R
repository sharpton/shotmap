# Invoke %  R  --slave  --args  class.id  outdir  out.file.stem  metadata.tab <  calculate_diversity.R

options(error=traceback)
options(error=recover)

Args              <- commandArgs()
samp.abund.map    <- Args[4]
sample.stem       <- Args[5]
compare.stem      <- Args[6]
metadata.tab      <- Args[7]
verbose           <- Args[8]
r.lib             <- Args[9]

.libPaths( r.lib )

if( is.na( verbose ) ){
    verbose = 0
} else {
    verbose = 1
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

#For testing purposes only
#samp.abund.map <- "/home/micro/sharptot/projects/shotmap_runs/MetaHIT_shotmap_output/KO/stats/no_ags//metahit.ibd-abundance-tables.tab"
#metadata.tab <- "/home/micro/sharptot/projects/shotmap_runs/MetaHIT_shotmap_output/metadata/metahit.ibd-metadata-fmt.ags-updated.tab"
#sample.stem  <- "/home/micro/sharptot/projects/shotmap_runs/MetaHIT_shotmap_output/KO/stats/no_ags/diversity//Sample_Diversity"
#compare.stem <- "/home/micro/sharptot/projects/shotmap_runs/MetaHIT_shotmap_output/KO/stats/no_ags/diversity//Sample_Comparison"
#verbose = 1

print.log = 0   #should rank abundance curves be plotted in log space?
topN      = 100 #how many of the most abundant families should be plotted in rank abundance curves?

####Good's coverage
####takes matrices of family counts by sample and number of classified reads by sample
#Note: May not make sense for coverage-based abundances!
goods.coverage <- function( count.map, class.map ) {  
###count = apply( abunds.map, 1, sum ) #this may need to be amended for coverage-based abundances
  #count = apply( abunds.map, 1, function(df){length(subset(df, df > 0))} ) 
    count = class.map
    tmap  = t(count.map)
    singletons = apply( tmap, 2, function(df){length(subset(df, df == 1 ) ) } ) 
    coverage   = 1 - ( singletons / count )
    return( coverage )
}

###Autodetect metadata variable type
###takes a list of values and determines if likely discrete or continuous. May not be perfect!
autodetect <- function( val.list ) {
  cont.thresh = 0.2 #what is min number of unique vals that constitutes a continuous list?
  type = NULL
  ##if any item matches a character, label as discrete
  ## maybe not - maybe even a large number of categories should be treated as continuous
  ##if( length(which(grepl( "[a-z|A-Z]", val.list))) > 0 ){
  ##  type = "discrete"
  ##  return( type )
  ##}
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
if( verbose  ){
    print( "Grabbing metadata..." )
}
meta       <- read.table( file=metadata.tab, header=TRUE, check.names=FALSE )
meta.names <- colnames( meta )

###get family abundances by samples
if( verbose ){
    print( "Grabbing family abundance data..." )
}
abund.df   <- read.table( file=samp.abund.map, header=TRUE, check.names=FALSE )
abund.map  <- acast(abund.df, SAMPLE.ID~FAMILY.ID, value.var="ABUNDANCE", fill=0 ) #could try to do all work in the .df object instead, enables ggplot
count.map  <- acast(abund.df, SAMPLE.ID~FAMILY.ID, value.var="COUNTS", fill=0 ) #could try to do all work in the .df object instead, enables ggplot
class.df   <- as.data.frame( unique(cbind(abund.df$SAMPLE.ID, abund.df$CLASS.SEQS) ) )
class.df   <- class.df[ order( class.df[,1] ), ]
class.map  <- class.df$V2
names(class.map) <- class.df$V1

seq.df   <- as.data.frame( unique(cbind(abund.df$SAMPLE.ID, abund.df$TOT.SEQS) ) )
seq.df   <- seq.df[ order( seq.df[,1] ), ]
seq.map  <- seq.df$V2
names(seq.map) <- seq.df$V1

samples    <- rownames(abund.map)
famids     <- colnames(abund.map)

### DO WE NEED THIS
###get family relative abundances by samples
### we need this in case we calc abundance as family coverage, where
### normalization is a function of total target length
if( verbose ){
    print( "Grabbing relative abundance data..." )
}
ra.map  <- acast(abund.df, SAMPLE.ID~FAMILY.ID, value.var="REL.ABUND", fill=0 ) #could try to do all work in .df object, enables ggplot

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

div.map    <- cbind( shannon, richness, goods, class.rate )
div.file   <- paste( sample.stem, ".tab", sep="" )
print( paste( "Producing diversity map file here: ", div.file, sep="") )
write.table( div.map, file = div.file, quote=FALSE )

###Make per-Sample Rank Abundance Plots
if( verbose ){ print( "Plotting rank abundance curves..." ) }
for( i in 1:dim(abund.map)[1] ){
  samp           <- rownames(abund.map)[i]
  data           <- abund.map[samp,]
  ra.data        <- ra.map[samp,]
  sorted         <- sort( ra.data, decreasing = TRUE )
  ##sample RA
  ##all Families
  file <- paste( sample.stem, "_sample_", samp, "_RA_all.pdf", sep="" )
  pdf( file )
  plot( 1:length(sorted), sorted, type="l",
       xlab = "Family Rank",
       ylab = "Relative Abundance",
       main = paste( "Relative Abundance of Sample ", samp, sep="" )
       )
  garbage <- dev.off()
  ##topN
  if( dim(abund.map)[2] > topN ){
    file <- paste( sample.stem, "_sample_", samp, "_RA_top", topN, ".pdf", sep="" )
    pdf(file)
    plot( 1:topN, sorted[1:topN], type="l",
         xlab = "Family Rank",
         ylab = "Relative Abundance",
         main = paste( "Relative Abundance of Sample ", samp, ", top ", topN, "families", sep="" )
         )
   garbage <- dev.off()
  }
  ##sample RA (log scale)  
  if( print.log ){
    ##all Families
    file <- paste( sample.stem, "_sample_", samp, "_RA_log.pdf", sep="" )
    pdf( file )
    plot( 1:length(sort(ra.data)), rev( sort( log(ra.data) ) ), type="l",
         xlab = "Family Rank",
         ylab = "Relative Abundanc (Log)",
         main = paste( "Relative Abundance of Sample ", samp, " Log Scale", sep="" )
         )
    garbage <- dev.off()
    ##topN
    if( dim(abund.map)[2] > topN ){
      file <- paste( sample.stem, "_sample_", samp, "_RA_log_top", topN, ".pdf", sep="" )
      pdf(file)
      plot( 1:topN, sorted[1:topN], type="l",
           xlab = "Family Rank",
           ylab = "Relative Abundance",
           main = paste( "Relative Abundance of Sample ", samp, ", top ", topN, " families", sep="" )
           )
      garbage <- dev.off()
    }
  }
}

###Plot all sample relative abundances in single image
##all Families
file <- paste( sample.stem, "_all_samples_RA.pdf", sep="" )
pdf( file )
for( i in 1:dim(abund.map)[1] ){
  samp           <- rownames(abund.map)[i]
  data           <- abund.map[samp,]
  ra.data        <- ra.map[samp,]
  sorted         <- sort( ra.data, decreasing = TRUE )
  if( i == 1 ){
    plot( 1:length(sorted), sorted, type="l",
         xlab = "Family Rank",
         ylab = "Relative Abundance",
         main = paste( "Relative Abundance Distributions", sep="" )
         )
  } else{
    lines( 1:length(sorted), sorted )
  }
}
garbage <- dev.off()
##topN
if( dim(abund.map)[2] > topN ){
  file <- paste( sample.stem, "_samples_RA_top", topN, ".pdf", sep="" )
  pdf(file)
  for( i in 1:dim(abund.map)[1] ){
    samp           <- rownames(abund.map)[i]
    data           <- abund.map[samp,]
    ra.data        <- ra.map[samp,]
    sorted         <- sort( ra.data, decreasing = TRUE )
    if( i == 1 ){
      plot( 1:topN, sorted[1:topN], type="l",
           xlab = "Family Rank",
           ylab = "Relative Abundance",
           main = paste( "Relative Abundance Distributions for top ", topN, " families", sep="" )
           )
    } else{
      lines( 1:topN, sorted[1:topN] )
    }
  }
  garbage <- dev.off()
}

###Plot all log-corrected sample relative abundances in single image
if( print.log ){
    if( verbose ){ print( "Plotting log-space rank abundance curve..." ) }
    file <- paste( sample.stem, "_all_samples_RA_log.pdf", sep="" )
    pdf( file )
    for( i in 1:dim(abund.map)[1] ){
        samp           <- rownames(abund.map)[i]
        data           <- abund.map[samp,]
        ra.data        <- ra.map[samp,]
        names(data)    <- c( "ABUNDANCE" )
        names(ra.data) <- c( "RELATIVE_ABUNDANCE" )  
        if( i == 1 ){
            plot( 1:length(sort(ra.data )), rev(sort( log( ra.data) ) ), type="l",
                 xlab = "Family Rank",
                 ylab = "Relative Abundance",
                 main = paste( "Relative Abundance Distributions", sep="" )
                 )
        } else{
            lines( 1:length(sort(ra.data)), rev(sort( log( ra.data) ) ) )
        }
    }
    garbage <- dev.off()
    ##topN
    if( dim(abund.map)[2] > topN ){
        file <- paste( sample.stem, "_samples_RA_log_top", topN, ".pdf", sep="" )
        pdf(file)
        for( i in 1:dim(abund.map)[1] ){
            samp           <- rownames(abund.map)[i]
            data           <- abund.map[samp,]
            ra.data        <- ra.map[samp,]
            sorted         <- sort( ra.data, decreasing = TRUE )
            if( i == 1 ){
                plot( 1:topN, sorted[1:topN], type="l",
                     xlab = "Family Rank",
                     ylab = "Relative Abundance",
                     main = paste( "Relative Abundance Distributions for top ", topN, " families", sep="" )
                     )
            } else{
                lines( 1:topN, sorted[1:topN] )
            }
        }
        garbage <- dev.off()
    }
}

###Plot per sample diversity statistics
###prepare div.map for plotting
tmp.map <- cbind( as.data.frame( rownames(div.map)), div.map ) 
colnames(tmp.map) <- c( "SAMPLE.ID", colnames(div.map) )
tmp.map$SAMPLE.ORDERED <- factor( tmp.map$SAMPLE.ID, sort( tmp.map$SAMPLE.ID) )
div.map <- tmp.map

if( verbose ) { print( "Plotting diversity statistics" ) }
for( b in 1:length( colnames(div.map) ) ){
  div.type <- colnames(div.map)[b]
  if( div.type == "SAMPLE.ID" | div.type == "SAMPLE.ORDERED" ){
    next
  }
  if( div.type == "shannon" ){
    ylabel <- "Shannon Entropy"
  }
  if( div.type == "richness" ){
    ylabel <- "Richness"
  }
  if( div.type == "goods" ){
    ylabel <- "Good's Coverage"
  }
  ggplot( div.map, aes_string(  x="SAMPLE.ORDERED", y= div.type ) ) +
    geom_bar( stat="identity" ) +
      labs( title = paste( ylabel, "across samples", sep="" ) ) +
        xlab( "Sample ID" ) +
          ylab( ylabel )
  file <- paste( sample.stem, "-", div.type, ".pdf", sep="" )
  if( verbose ) { print(file) }
  ggsave( filename = file, plot = last_plot(), width=7, height=7 )
}

###Can only do the below if metadata fields are provided


###merge metadata with diversity data for future plotting
if( is.null( meta ) ){
  stop( paste( "I didn't detect any metadata for your samples. ",
              "If this is correct, ignore this warning. If you have metadata, ",
              "check that it is loaded in the samples table of the database correctly",
              sep="")
       )
} else {
  meta.div   <- merge( div.map, meta, by = "SAMPLE.ID" )
 ##print out meta.div so users can do custom plotting
  out.tab <- paste(sample.stem, "-diversity-metadata-table.tab", sep="")
  print( paste( "Writing metadata by diversity table. Use this for custom plotting: ", out.tab, sep="") ) 
  write.table( meta.div, file=out.tab, quote=FALSE )
  corr.tests <- NULL
  kw.tests   <- NULL
###Compare diversity statistics between metadata groups
##differences in diversity across distinct types of metadata classes
  for( b in 1:length( meta.names ) ){
    for( d in 1:length( colnames(div.map) ) ){
      div.type  <- colnames(div.map)[d]
      meta.type <- meta.names[b]
      if( div.type == "SAMPLE.ID" | div.type == "SAMPLE.ORDERED" | meta.type == "SAMPLE.ID" | meta.type == "SAMPLE.ALT.ID" ){
        next;
      }
      if( autodetect( meta[,meta.type] ) == "continuous" ){
        next
      }
      ggplot( meta.div, aes_string( x = meta.type, y=div.type ) ) +
        geom_boxplot() + #if color: geom_boxplot(aes(fill = COLNAME) )
          labs( title = paste( div.type, " by ", meta.names[b], sep="" ) ) +
            xlab( meta.type ) +
              ylab( div.type )
      file <- paste( compare.stem, "-", meta.type, "-", div.type, "-boxes.pdf", sep="" )
      if( verbose ){ print(file) }
      ggsave( filename = file, plot = last_plot(), width=7, height=7  )
      pval <- kruskal.test( meta.div[,meta.type], meta.div[,div.type])$p.value
      tmp.stats <- data.frame( meta.field = meta.type, div.field = div.type, pvalue=pval )
      kw.tests  <- rbind( kw.tests, tmp.stats )
    }
  }

 ###build scatter plots, grouping by metadata fields. Not always informative (e.g., when field is discrete)
##relationship between diversity and metadata type?
  for( b in 1:length( meta.names ) ){
    for( d in 1:length( colnames(div.map) ) ){
      div.type  <- colnames(div.map)[d]
      meta.type <- meta.names[b]
      if( div.type == "SAMPLE.ID" | div.type == "SAMPLE.ORDERED" | meta.type == "SAMPLE.ID" | meta.type == "SAMPLE.ALT.ID" ){
        next;
      }
      if( autodetect( meta[,meta.type] ) == "discrete" ){
        next
      }
      ggplot( meta.div, aes_string( x = meta.type, y=div.type ) ) +
        geom_point( ) + #if color: geom_point(aes(fill = COLNAME) )
          labs( title = paste( div.type, " by ", meta.names[b], sep="" ) ) +
            xlab( meta.type ) +
              ylab( div.type )
      file <- paste( compare.stem, "-", meta.type, "-", div.type, "-scatter.pdf", sep="" )
      if( verbose ){ print(file) }
      ggsave( filename = file, plot = last_plot(), width=7, height=7 )
      if( is.numeric( meta.div[,meta.type] ) ){
            corr <- cor.test( meta.div[,meta.type], meta.div[,div.type], method="spearman" )
      	    tmp.stats <- data.frame( meta.field = meta.type, div.field = div.type, rho=corr$estimate, pvalue=corr$p.value )      
	    corr.tests  <- rbind( corr.tests, tmp.stats )		
      }
    }
  }

###build line plots between types
###the change in diversity over metadata space
### OFF FOR NOW - need efficient way to select how samples are grouped within a metadata type (richness for mg v. mt across time) for this to be meaningful
  if( 0 ){
    for( b in 1:length( meta.names ) ){
      for( d in 1:length( colnames(div.map) ) ){
        div.type  <- colnames(div.map)[d]
        meta.type <- meta.names[b]
        if( div.type == "SAMPLE.ID" | div.type == "SAMPLE.ORDERED" | meta.type == "SAMPLE.ID" | meta.type == "SAMPLE.ALT.ID" ){
          next;
        }
        if( autodetect( meta[,meta.type] ) == "discrete" ){
          next
        }
        ggplot( meta.div, aes_string( x = meta.type, y=div.type ) ) +
          geom_line() + #if color: geom_line(aes(fill = COLNAME) )
            labs( title = paste( div.type, " by ", meta.names[b], sep="" ) ) +
              xlab( meta.type ) +
                ylab( div.type )
        file <- paste( compare.stem, "-", meta.type, "-", div.type, "-line.pdf", sep="" )
        print(file)
        ggsave( filename = file, plot = last_plot(), width=7, height=7  )
      }
    }
  }
  kw.tab <- paste(sample.stem, "-kruskal-wallis_stats.tab", sep="")
  write.table( kw.tests, file=kw.tab, quote=FALSE )
  corr.tab <- paste(sample.stem, "-spearman_stats.tab", sep="")
  write.table( corr.tests, file=corr.tab, quote=FALSE )
}

