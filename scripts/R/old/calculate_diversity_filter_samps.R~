# Invoke %  R  --slave  --args div.meta.tab filter.field filter.value outstem shotmap.R.path <  calculate_diversity_filter_samps.R

##########################
#Partition samples in a project by metadata field and calculate_diversity.R

#This R script takes a table file like Sample_Diversity_cid_54_aid_3-diversity-metadata-table.tab
#that is produced by shotmap/scripts/R/calculate_diversity.R, filters out samples by a metadata
#parameter, and reruns the calculate_diversity.R comparisons on the remaining data. 
##########################

require(ggplot2)
require(reshape2)

options(error=traceback)
options(error=recover)

Args           <- commandArgs()
div.meta.tab   <- Args[4] #diversity statistics and metadata fields by samples
filter.field   <- Args[5] #filter samples by this field (e.g., DATA_TYPE)
filter.value   <- Args[6] #filter samples by this field value (e.g., metagenome)
outstem        <- Args[7] 
shotmap.R.path <- Args[8]

source(shotmap.R.path)

tab <- read.table( file=div.meta.tab )
meta.div <- subset( tab, tab[,filter.field] != filter.value )

div.types  <- c( "shannon", "richness", "goods" )
meta.names <- colnames( meta.div )[!colnames(meta.div) %in% c( div.types, "SAMPLE.ID", "SAMPLE.ORDERED", "SAMPLE.ALT.ID" )] 
for( b in 1:length( meta.names ) ){
    for( d in 1:length( div.types ) ){
      div.type  <- div.types[d]
      meta.type <- meta.names[b]
      if( autodetect( meta.div[,meta.type] ) == "continuous" ){
        next
      }
      ggplot( meta.div, aes_string( x = meta.type, y=div.type ) ) +
        geom_boxplot() + #if color: geom_boxplot(aes(fill = COLNAME) )
          labs( title = paste( div.type, " by ", meta.names[b], sep="" ) ) +
            xlab( meta.type ) +
              ylab( div.type )
      file <- paste( outstem, "-", meta.type, "-", div.type, "-boxes.pdf", sep="" )
      print(file)
      ggsave( filename = file, plot = last_plot() )
    }
}
###build scatter plots, grouping by metadata fields. Not always informative (e.g., when field is discrete)
##relationship between diversity and metadata type?
for( b in 1:length( meta.names ) ){
    for( d in 1:length( div.types ) ){
      div.type  <- div.types[d]
      meta.type <- meta.names[b]
      if( autodetect( meta.div[,meta.type] ) == "discrete" ){ #we force because sample size is so small
        next
      }
      ggplot( meta.div, aes_string( x = meta.type, y=div.type ) ) +
        geom_point( ) + #if color: geom_point(aes(fill = COLNAME) )
          labs( title = paste( div.type, " by ", meta.names[b], sep="" ) ) +
            xlab( meta.type ) +
              ylab( div.type )
      file <- paste( outstem, "-", meta.type, "-", div.type, "-scatter.pdf", sep="" )
      print(file)
      ggsave( filename = file, plot = last_plot() )
   }
}

