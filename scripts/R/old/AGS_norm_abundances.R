# Invoke %  R  --slave  --args  class.id  outdir  out.file.stem  metadata.tab <  calculate_diversity.R

options(error=traceback)
options(error=recover)

Args              <- commandArgs()
samp.abund.map    <- Args[4]
metadata.tab      <- Args[5]
genome.size.tab   <- Args[6] #produced by microbe census
tot.bp.tab        <- Args[7] #samples by total metagenome size
outstem           <- Args[8] #name of the output file

norm.abunds <- function( abund.df, genome.size.tab, tot.bp.tab, meta ) {	    
  #load microbe census results	    
  ags.tab <- read.table( file=genome.size.tab, header=T )
  #load bp tab and reformt
  bp.tab  <- read.table( file=tot.bp.tab, header=F )
  colnames( bp.tab ) <- c( "sample", "size" )
  #let's build a big table
  tmp <- merge( abund.df, meta, by.x = 1, by.y = 1 )
  #limit our analysis to those samples in ags.tab
  tmp <- subset( tmp, tmp$SAMPLE.ALT.ID %in% ags.tab$sample_id )
  tmp2 <- merge( tmp, ags.tab, by.x = 5, by.y = 2, sort=FALSE )
  tmp3 <- merge( tmp2, bp.tab, by.x = 1, by.y = 1, sort=FALSE )
  #do the normalization
  norm.abunds <- tmp3$ABUNDANCE / ( tmp3$size / tmp3$avg_size )
  abund.df.n <- cbind( tmp, norm.abunds )
  colnames( abund.df.n ) <- c( colnames(abund.df), "NORM.ABUND" )
  remove(tmp)
  remove(tmp2)
  remove(tmp3)
  return( abund.df.n )
}

print( "Grabbing family abundance data..." )
abund.df   <- read.table( file=samp.abund.map, header=TRUE, check.names=FALSE )
print( "Normalizing abundances by average genome size...")
abund.df   <- norm.abunds( abund.df, genome.size.tab, tot.bp.tab, meta )
write.table( abund.df, file = paste(samp.abund.map, "-AGS_normalized.tab", sep="")  )
