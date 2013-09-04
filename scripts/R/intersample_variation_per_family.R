# Invoke %  R  --slave  --args  class.id  outdir  out.file.stem  metadata.tab rare.value <  calculate_diversity.R
require(ggplot2)

Args             <- commandArgs()
class.id         <- Args[4]
outdir           <- Args[5] #must have trailing slash!
out.file.stem    <- Args[6]
metadata.tab     <- Args[7] #need to figure out how to automate building of this! Maybe we change sample table on the fly....
rare.value       <- Args[8] #need to check if it is defined or not...

#add trailing slash
outdir <- paste( outdir, "/", sep="" )

#get the metadata
meta       <- read.table( file=metadata.tab, header = TRUE )
meta.names <- colnames( meta )

#get the classification maps associated with the class.id
maps     <- list.files(pattern=paste('ClassificationMap_Sample_.*_ClassID_', class.id, '_Rare_', rare.value, '.tab',sep='' ))
proj.tab <- NULL #cats samp.tabs together
div.tab  <- NULL #maps sample id to family relative abundance shannon entropy and richness
div.types <- c( "RICHNESS" , "RELATIVE_RICHNESS", "SHANNON_ENTROPY" )

samp.tabs <- NULL #a df of sample tables, which we build in the code below
for( a in 1:length(maps) ){
  class.map    <- read.table( file=maps[a], header = TRUE )
  FAMID_FACTOR <- as.factor( class.map$FAMID )
  samp         <- unique( class.map$SAMPLE_ID )
  famids       <- levels( FAMID_FACTOR )
  counts       <- table( FAMID_FACTOR ) #maps family id to family counts
  read.count   <- class.map$READ_COUNT[1]
  project      <- class.map$PROJECT_ID[1]
  samp.tab     <- data.frame( samp, names(counts), as.numeric(counts)/read.count )
  colnames(samp.tab) <- c( "SAMPLE_ID", "FAMILY_ID", "RELATIVE_ABUNDANCE" )
  samp.tabs    <- rbind( samp.tabs, samp.tab )
}



#############################################################################################
# ORDER THE SAMPLES BY THEIR METADATA ORDER (PRESUMABLY, THIS IS THE ORDER WE WANT TO PLOT) #
#############################################################################################
samples  <- unique( samp.tabs$SAMPLE_ID )
samp.ord <- meta$SAMPLE_ID
names(samples)<-as.character(samples)
samples  <- samples[as.character(samp.ord)]

#####################################################
# BUILD A FAMILY BY SAMPLE RELATIVE ABUNDANCE TABLE #
#####################################################
famids <- unique( samp.tabs$FAMILY_ID )
fam.ra.mat <- matrix( nrow = length( famids ), ncol = length( samples ), data = 0 )
colnames(fam.ra.mat)<-samples
rownames(fam.ra.mat)<-famids
for(b in 1:dim(samp.tabs)[1] ){
  row   <- samp.tabs[b,]
  famid <- row$FAMILY_ID
  samp.id <- row$SAMPLE_ID
  ra      <- row $RELATIVE_ABUNDANCE
  fam.ra.mat[as.character(famid),as.character(samp.id)] <- ra
}

#############################
# FOLD CHANGE NORMALIZATION #
#############################
foldchange.norm <- function( x ){ #assume a normal dist and calculate number of sd for each obs in set
  results  <- NULL
  fam.sd   <- sd(x)
  fam.mean <- mean(x)
  for( i in 1:length(x) ){
    obs     <- x[i]
    val     <- ( obs - fam.mean ) / fam.sd
    results <- c( results, val )
  }
  results
}

fam.norm.tab <- apply( fam.ra.mat, 1, foldchange.norm ) #this is a transpose of the dataframe above!

write.table( fam.norm.tab, file = paste(outdir, "family_ra_tab_by_samples_foldnorm.tab", sep=""))

t(fam.norm.tab)->fam.norm.tab.t
fam.norm.dist <- dist( fam.norm.tab.t )

#####
# kmeans
#####

#see http://www.statmethods.net/advstats/cluster.html
wss <- (nrow(fam.norm.tab.t)-1)*sum(apply(fam.norm.tab.t,2,var))
for( i in 2:15 ) wss[i]<- sum(kmeans(fam.norm.tab.t,centers=i)$withinss)
plot(1:15, wss, type="b")
fit<-kmeans(fam.norm.tab.t,10)
agg<-aggregate(fam.norm.tab.t, by=list(fit$cluster),FUN=mean)
agg<-agg[,-1]
agg<-agg[,as.character(samples)]
fam.norm.tab.t<-data.frame(fam.norm.tab.t, fit$cluster)
#plot
c25 <- c("dodgerblue2","#E31A1C", # red
                         "green4",
                         "#6A3D9A", # purple
                         "#FF7F00", # orange
                         "black","gold1",
                         "skyblue2","#FB9A99", # lt pink
                         "palegreen2",
                         "#CAB2D6", # lt purple
                         "#FDBF6F", # lt orange
                         "gray70", "khaki2",
                         "maroon","orchid1","deeppink1","blue1","steelblue4",
                         "darkturquoise","green1","yellow4","yellow3",
                         "darkorange4","brown")
pdf(file="temporal_var_famClusts_kmeans10.pdf")
plot(t(agg[1,]), type="l", xlab="", ylab="Fold Change (sd)", xaxt='n', main="Variation of Clustered Families (kmeans, n=10)",
     col=c25[1], ylim=c(min(agg), max(agg)), lwd=10
     )
for(i in 2:17 ){
  lines( t(agg[i,] ), col=c25[i] )
}
axis(1, at=c(1:16), labels=c("W-D-MG","W-D-MT", "W-N-MG", "W-N-MT", "Sp-D-MG", "Sp-D-MT", "Sp-N-MG",
                      "Sp-N-MT", "Su-D-MG", "Su-D-MT", "Su-N-MG", "Su-N-MT", "Su-N-MG", "Su-N-MT",
                      "Su-D-MG", "Su-D-MT"), las=2 )
dev.off()
