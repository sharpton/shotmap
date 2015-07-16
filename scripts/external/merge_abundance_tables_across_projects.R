#right now, files number be 1 sample per abundance table, with the sample name in the file, ala
#
#V1.UC-8_SFAM_Diversity_Map.tab
#

###NOTE: you may need to update bioconductor for multtest. Open R and do the following
### > source("http://bioconductor.org/biocLite.R")
### > biocLite("multtest")

options(error=traceback)
options(error=recover)

Args              <- commandArgs()
in.dir            <- Args[4]
metadata.tab      <- Args[5]
outpath           <- Args[6]
r.lib             <- Args[7]

libloc <- .Library
if( !is.na( r.lib ) ){
    libloc <- r.lib
}

library(reshape2, lib.loc = libloc)	

metadata.delim <- ""
col.classes    <- c( "factor", "factor", rep( "numeric", 3 ) )

files <- list.files( in.dir )
abund.map.files <- files[grep(glob2rx("Abundance_Data_Frame*"), files)]

####get the metadata - use it to process abund maps (see below)
meta       <- read.table( file=metadata.tab, header=TRUE, check.names=FALSE, sep=metadata.delim )
meta.names <- colnames( meta )
sample.alt.ids <- meta$Sample.Name    #This must be in the metadata file!

if( is.null(sample.alt.ids)){
    print( paste("ERROR: Could not find the field Sample.Name in your metadata file ", metadata.tab, sep=" ") );
    exit();   
}
if( length( sample.alt.ids ) < length( abund.map.files ) ){
    print( paste( "WARNING: There are more abundance maps in the directory <", in.dir, "> than there are samples in ",
    " the metadata table you provided <", metadata.tab, ">. I will only process those samples in your metadata table.", sep="") );
}

abund.df <- NULL
for ( z in 1:length(sample.alt.ids) ){
  alt.id <- sample.alt.ids[z]
  index  <- grep( alt.id, abund.map.files) 
  if( length(index) == 0 ){
      print( paste( "WARNING: Cannot find abundance file for sample ", alt.id, ". Passing this sample...", sep="" ) )
     next
  }
  abund.file <- abund.map.files[index]
  print( paste( "Processing ", abund.file, sep="") )
  tmp.map    <- read.table( file=paste( in.dir, "/", abund.file, sep=""), header=TRUE, check.names=FALSE, colClasses = col.classes )
  #replace sample_id number with sample_alt_id from the file name
  tmp.map$SAMPLE.ID <- alt.id
  #append tmp.map to abund.df
  abund.df <- rbind( abund.df, tmp.map )
}

outfile <- paste( outpath, "/Merged_Abundance_Data_Frame.tab", sep="" )
write.table( abund.df, file=outfile, row.names=FALSE, quote=FALSE, sep="\t")

abund.map  <- acast(abund.df, Sample.Name~Family.ID, value.var="Abundance", fill=0 ) 
count.map  <- acast(abund.df, Sample.Name~Family.ID, value.var="Counts", fill=0 ) 
ra.map     <- acast(abund.df, Sample.Name~Family.ID, value.var="Relative.Abundance", fill=0 ) 

### write the sample-by-data matrices
# abundance table
samp.abund.file = paste( outpath, "/Merged_Abundances.tab", sep="" )
print( paste( "Producing samples-by-abundance table here: ", samp.abund.file, sep="") )
write.table( abund.map, file = samp.abund.file, quote=FALSE )

# counts table
samp.count.file = paste( outpath, "/Merged_Counts.tab", sep="" )
print( paste( "Producing samples-by-counts table here: ", samp.count.file, sep="") )
write.table( count.map, file = samp.count.file, quote=FALSE )

# relative abundance table
samp.ra.file    = paste( outpath, "/Merged_Relative_abundances.tab", sep="" )
print( paste( "Producing samples-by-relative abundance table here: ", samp.ra.file, sep="") )
write.table( ra.map, file = samp.ra.file, quote=FALSE )
