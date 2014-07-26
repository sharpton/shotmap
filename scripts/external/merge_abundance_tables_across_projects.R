#right now, files number be 1 sample per abundance table, with the sample name in the file, ala
#
#V1.UC-8_SFAM_Diversity_Map.tab
#

###NOTE: you may need to update bioconductor for multtest. Open R and do the following
### > source("http://bioconductor.org/biocLite.R")
### > biocLite("multtest")

options(error=traceback)
options(error=recover)

norm.abunds <- function( abund.df, meta ) {	   
  #meta must have cols named "tot_bp" and "avg_size"
  #load microbe census results	       
  #do the normalization
  norm.abunds <- abund.df$ABUNDANCE / ( tmp3$size / tmp3$avg_size )
  abund.df.n <- cbind( abund.df, norm.abunds )
  colnames( abund.df.n ) <- c( colnames(abund.df), "NORM.ABUND" )
  remove(tmp)
  remove(tmp2)
  remove(tmp3)
  return( abund.df.n )
}

Args              <- commandArgs()
in.dir            <- Args[4]
metadata.tab      <- Args[5]
outfile           <- Args[6]
ags.normalize     <- Args[7]
reset.total_bp    <- Args[8]
total_bp          <- Args[9]

#in.dir       <- "/home/micro/sharptot/projects/shotmap_runs/MetaHIT_shotmap_output/SFAM/test/"
#metadata.tab <- "/home/micro/sharptot/projects/shotmap_runs/MetaHIT_shotmap_output/SFAM/test/metahit.avg_size-metadata.tab"
#outfile      <- "/home/micro/sharptot/projects/shotmap_runs/MetaHIT_shotmap_output/SFAM/test/metahit-abundance-tables.tab"
ags.normalize <- 1
reset.total_bp <- 1
total_bp       <- 20000000 * 70

metadata.delim <- ""

files <- list.files( in.dir )
abund.map.files <- files[grep(glob2rx("*Abundance_Map*"), files)]

####get the metadata - use it to process abund maps (see below)
meta       <- read.table( file=metadata.tab, header=TRUE, check.names=FALSE, sep=metadata.delim )
meta.names <- colnames( meta )
sample.alt.ids <- meta$SAMPLE.ID    #This must be in the metadata file!

if( reset.total_bp ){
    meta$total_bp <- total_bp
}

if( is.null(sample.alt.ids)){
    print( paste("ERROR: Could not find the field SAMPLE.NAME in your metadata file ", metadata.tab, sep=" ") );
    exit();   
}
if( length( sample.alt.ids ) < length( abund.map.files ) ){
    print( paste( "WARNING: There are more abundance maps in the directory <", in.dir, "> than there are samples in ",
    " the metadata table you provided <", metadata.tab, ">. I will only process those samples in your metadata table.", sep="") );
}

abund.map <- NULL
for ( z in 1:length(sample.alt.ids) ){
  alt.id <- sample.alt.ids[z]
  index  <- grep( paste(alt.id, "_", sep=""), abund.map.files) 
  if( length(index) == 0 ){
      print( paste( "WARNING: Cannot find abundance file for sample ", alt.id, ". Passing this sample...", sep="" ) )
      next
  }
  abund.file <- abund.map.files[index]
  print( paste( "Processing ", abund.file, sep="") )
  tmp.map    <- read.table( file=paste( in.dir, "/", abund.file, sep=""), header=TRUE, check.names=FALSE)	
  #replace sample_id number with sample_alt_id from the file name
  tmp.map$SAMPLE.ID <- alt.id
  #normalize abundance/relative abundance by AGS
  if( ags.normalize ){  
    meta.sub <- subset( meta, meta$SAMPLE.ID == alt.id )
    ags.norm.abund <- tmp.map$REL.ABUND / ( meta.sub$total_bp / meta.sub$avg_size )  #Or is it ABUNDANCE / TOT.ABUND?    
    tmp.map$ABUNDANCE <- ags.norm.abund
  }
  #append tmp.map to abund.map
  abund.map <- rbind( abund.map, tmp.map )
}

write.table( abund.map, file=outfile, row.names=FALSE, quote=FALSE, sep="\t")