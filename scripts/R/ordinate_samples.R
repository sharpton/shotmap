# Invoke %  R  --slave  --args  class.id  outdir  out.file.stem  metadata.tab <  calculate_diversity.R

options(error=traceback)
options(error=recover)

Args              <- commandArgs()
samp.abund.map    <- Args[4]
file.stem         <- Args[5]
metadata.tab      <- Args[6]
verbose           <- Args[7]

if( is.na( verbose ) ){
    verbose = 0
} else {
    verbose = 1
}

if( verbose ) {
    require(vegan)
    require(ggplot2)
    require(reshape2)
    require(fpc)
    require(grid) #needed for PCbiplot's call to arrow()
} else {
    msg.trap <- capture.output( suppressMessages( library( vegan ) ) )
    msg.trap <- capture.output( suppressMessages( library( ggplot2 ) ) )
    msg.trap <- capture.output( suppressMessages( library( reshape2 ) ) )
    msg.trap <- capture.output( suppressMessages( library( fpc ) ) )
    msg.trap <- capture.output( suppressMessages( library( grid ) ) )
}


method            <- "pca" #not currently used, but reserved for later
to.scale          <- 1
to.center         <- 1
topN              <- 5
to.plotloadings   <- 1

plotloadings <- FALSE
scale  <- FALSE
center <- FALSE
if( to.scale ){
  scale <- TRUE
}
if( to.center ){
  center <- TRUE
}
if( to.plotloadings ){
  plotloadings <- TRUE
}

plotstem <- method

#For testing purposes only
#samp.abund.map <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/Abundance_Map_cid_54_aid_1.tab"
#metadata.tab   <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/sample_metadata.tab"
#file.stem      <- "/mnt/data/work/pollardlab/sharpton/MRC_ffdb/projects/SFams_english_channel_L4/90/output/Sample_ordination_cid_54_aid_1"

###Thanks to crayola (http://stackoverflow.com/questions/6578355/plotting-pca-biplot-with-ggplot2)
PCbiplot <- function(PC, x="PC1", y="PC2", plotloadings=TRUE, topN=10, metatypes=NULL) {
  ## PC being a prcomp object
  data <- NULL
  plot <- NULL
  if( is.null( metatypes ) ){
    data <- data.frame(obsnames=row.names(PC$x), PC$x)
    plot <- ggplot(data, aes_string(x=x, y=y)) + geom_text(size=3, aes(label=obsnames)) +
      theme(panel.background = element_rect(fill='white', colour='black'))
    plot <- plot + geom_hline(aes(0), size=.2) + geom_vline(aes(0), size=.2)
  } else {
    data <- data.frame(obsnames=row.names(PC$x), metatype=metatypes[row.names(PC$x)], PC$x)
    plot <- ggplot(data, aes_string(x=x, y=y)) + geom_text(size=3, aes(label=obsnames, colour=factor(metatype))) +
      theme(panel.background = element_rect(fill='white', colour='black'))
    plot <- plot + geom_hline(aes(0), size=.2) + geom_vline(aes(0), size=.2)    
  }
  if( plotloadings ){
    datapc <- data.frame(varnames=rownames(PC$rotation), PC$rotation)
    top.x  <- sort(abs(pca$rotation[,x]), decreasing=TRUE)[1:topN]
    top.y  <- sort(abs(pca$rotation[,y]), decreasing=TRUE)[1:topN]  
    mult <- min(
                (max(data[,y]) - min(data[,y])/(max(datapc[,y])-min(datapc[,y]))),
                (max(data[,x]) - min(data[,x])/(max(datapc[,x])-min(datapc[,x])))
                )
    datapc <- transform(datapc,
                        v1 = .7 * mult * (get(x)),
                        v2 = .7 * mult * (get(y))
                        )
    ##reduce the complexity of the loadings visulatization
    datapc <- subset( datapc, rownames(datapc) %in% names(top.x) | rownames(datapc) %in% names(top.y) )
    plot <- plot + coord_equal() + geom_text(data=datapc, aes(x=v1, y=v2, label=varnames), size = 3, vjust=1, color="black")
    plot <- plot + geom_segment(data=datapc, aes(x=0, y=0, xend=v1, yend=v2), arrow=arrow(length=unit(0.2,"cm")), alpha=0.75, color="black")
  }
  plot
}

####get the metadata
meta       <- read.table( file=metadata.tab, header=TRUE, check.names=FALSE )
meta.names <- colnames( meta )

###get family abundances by samples
print( "Grabbing family abundance data..." )
abund.df <- read.table( file=samp.abund.map, header=TRUE, check.names=FALSE )
abund.map  <- acast(abund.df, SAMPLE.ID~FAMILY.ID, value.var="ABUNDANCE" ) #could try to do all work in the .df object instead, enables ggplot
samples    <- rownames(abund.map)
famids     <- colnames(abund.map)

###get family relative abundances by samples
print( "Grabbing relative abundance data..." )
ra.map  <- acast(abund.df, SAMPLE.ID~FAMILY.ID, value.var="REL.ABUND" ) #could try to do all work in .df object, enables ggplot

pca <- NULL
if( scale & center ){
  pca <- prcomp( ra.map, scale=TRUE, center=TRUE )
  plotstem <- paste( plotstem, "_center_scale", sep="")
} else if ( scale & !center ){
  pca <- prcomp( ra.map, scale=TRUE, center=FALSE )
  plotstem <- paste( plotstem, "_nocenter_scale", sep="")
} else if( !scale & center ){
  pca <- prcomp( ra.map, scale=FALSE, center=TRUE )
  plotstem <- paste( plotstem, "_center_noscale", sep="")
} else { #!scale & !center
  pca <- prcomp( ra.map, scale=FALSE, center=FALSE )
  plotstem <- paste( plotstem, "_nocenter_noscale", sep="")
}

###Is there support for sample clusters in PCA space?
n.factors <- 2 ###Let's just cluster in the first 2 PC since that's how we're visualizing the data
distmeth = "euclidean"
print( paste( "Looking for evidence of clusters in PCA space using: ", distmeth ," " , n.factors, " components", sep=""))
d         <-vegdist(pca$x[,1:n.factors], method=distmeth)
##print the distance matrix
dist.file <- paste( file.stem, "-sample_distance_matrix-", plotstem, "-pca_euclidean.dist", sep="" )
print( paste( "Write sample distance matrix to ", dist.file, sep="" ) )
write.matrix( d, dist.file )
if( length(colnames(d)) < 3 ){
    print( paste( "You don't have enough samples to conduct PAM clustering. Skiping this step." ) )
} else {
    ##cluster and look for support
    pamk.best <- pamk(d)
    ##print results
    sil.plot  <- paste( file.stem, "-pam_clusters-pca_euclidean-silhouettes.pdf" )
    print( paste( "Printing silhouette plot to ", sil.plot, sep="") )
    pdf( file = sil.plot )
    plot(pam(d, pamk.best$nc))
    dev.off()
    sil.file  <- paste( file.stem, "pam_clusters-pca_euclidean-data.tab" )
    pam.dat   <- pamk.best$pamobject #push into this var in case we want to do anything else in future
    print(paste( "Writing cluster support data to ", sil.file, sep="" ) )
    write.table( pam.dat$silinfo$widths, sil.file )
}

###Print a table of the loadings on the data
loads <- pca$rotation
##build relative (normalize) loadings table
aload <- abs( loads )
rel.loads  <- sweep( aload, 2, colSums(aload), "/" )
norm.loads <- rel.loads[,1:2]
##merge with raw loadings and print to file
dimensions <- c( "PC1", "PC2")
for( b in 1:length(dimensions) ){
  x <- dimensions[b]
  pc.norm.loads <- sort( norm.loads[,x], decreasing=TRUE)
  pc.abs.loads  <- sort(abs(pca$rotation[,x]), decreasing=TRUE)
  pc.loadings   <- data.frame( raw=pc.abs.loads, normalized=pc.norm.loads )
  load.tab      <- paste( file.stem, "-", x, "_loadings-", plotstem, ".tab", sep="" )
  print( paste( "Printing loadings to ", load.tab, sep="" ) )
  write.table( pc.loadings, load.tab )
}

###PLOT PCA by Metadata Parameters
has_meta = 0
for( a in 1:length( meta.names ) ){
  meta.field <- meta.names[a]    
  if( meta.field == "SAMPLE.ID" | meta.field == "SAMPLE.ALT.ID" ){
    next   
  }
  has_meta = 1
  metatypes <- meta[,meta.field]
  names(metatypes)<-meta$SAMPLE.ID
  pca.file <- paste( file.stem, "-by_", meta.field, "-", plotstem, ".pdf", sep="" )
  p <- PCbiplot(pca, metatypes=metatypes)
  p + theme(panel.background = element_rect(fill='white', colour='black'))
  print( paste( "Plotting ", pca.file, sep="" ) )
  ggsave(p, file=pca.file)
}

###if there's no metadata associated with samples other than ID and ALTID
if( !has_meta ){
  p   <- PCbiplot(pca)
  pca.file <- paste( file.stem, "-PCA.pdf", sep="" )
  ggsave(p, file=pca.file)
}
