locallib <- Sys.getenv( "SHOTMAP_LOCAL")
r.lib    <- paste( locallib, "/ext/R/", sep="")
.libPaths( r.lib )

library(ggplot2)
library(vegan)
library(dendextend)
library(fpc)
library(cluster)
library(dplyr)
library(psych)
library(coin)
library(multtest)
library(qvalue)

#############################################
### abundance_variance_filtering()
### Filters families with low ocurrence
#############################################
abundance_variance_filtering <- function( abund.map, method ){
  tmp.map   <- NULL
  if( method == "full.observation" ){
    nrows   <- dim(abund.map)[1]
    occurs  <- colSums(abund.map != 0)
    to.keep <- names(occurs[occurs == nrows ])
    tmp.map <- abund.map[, to.keep ]  
  }
  if( method == "high.variance"){
    results    <- abund.map %>% summarise_each( funs( var ) )
    box.stat   <- boxplot(t(results))$stats
    median.var <- box.stat[3,1]
    upper.q    <- box.stat[4,1]
    indices    <- which(results > upper.q)
    tmp.map    <- abund.map[,indices]
  }
  return(tmp.map)
}

##################################################
### categorical_diversity_analyses()
### Group samples by metadata, plot div statistics
##################################################
categorical_diversity_analyses <- function( div.map, outpath ){
  kw.tests   <- NULL
  for( a in 1:length( colnames(div.map) ) ){
    for( b in 1:length( colnames(div.map) ) ){
      div.type  <- colnames(div.map)[a]
      meta.type <- colnames(div.map)[b]
      if( div.type == meta.type ){
        next
      }
      if( is_sample_field( div.type ) |
            is_sample_field( meta.type) |
            is_categorical_field( div.type ) ){
        next
      }
      if( !( is_categorical_field( meta.type ) ) ){
        next
      }     
      ggplot( div.map, aes_string( x = meta.type, y=div.type ) ) +
        geom_boxplot() + #if color: geom_boxplot(aes(fill = COLNAME) )
        labs( title = paste( meta.type, " by ", div.type, sep="" ) ) +
        xlab( meta.type ) +
        ylab( div.type )
      file <- paste(  outpath,"/Boxplots-", meta.type, "-", div.type, ".pdf", sep="" )
      ggsave( filename = file, plot = last_plot(), width=7, height=7  )
      if( var( div.map[,div.type] ) == 0 ){
        #wilcox tests can't work on such samples
        print( paste( "The following field has no variation
                      so I can't conduct a kruskal-wallis test:",
                      div.type,
                      sep="")
        )
        next
      }
      #pval      <- kruskal.test( div.map[,meta.type], div.map[,div.type])$p.value
      pval <- pvalue( kruskal_test( div.map[,div.type] ~ div.map[,meta.type], data = div.map, distribution = approximate(B=5000) ) )
      
      tmp.stats <- data.frame( meta.field = meta.type, div.field = div.type, pvalue=as.vector(pval) )
      kw.tests  <- rbind( kw.tests, tmp.stats )
    }
  }
  kw.tests <- padjust_table( kw.tests )
  outtable <- paste( outpath, "/categorical_kwtests.tab", sep="")
  write.table( kw.tests, file=outtable)
}

##################################################
### categorical_family_analyses()
### Categorical Family Analyses
##################################################
categorical_family_analyses <- function( div.map, abund.map, outpath, plot.q.threshold ){
  to.plot <- 1
  for( a in 1:length( colnames(div.map) ) ){
    div.type <- colnames(div.map)[a]
    if( !is_categorical_field( div.type ) ){
      next
    }
    div.groups <- unique( div.map[,div.type] )
    if( length( div.groups ) < 2 ){
      print( paste("Not enough types of <", 
                   div.type, 
                   "> to conduct these statistics. Passing...", 
                   sep=""))
      next
    }  
    ##RUN THE TEST
    classes.unsort        <- as.factor(div.map[,div.type])
    names(classes.unsort) <- div.map$Sample.Name
    test.data       <- t( abund.map )
    classes         <- classes.unsort[ colnames( test.data ) ]      
    if( length( div.groups ) == 2 ){
      test.type <- "wilcoxon"
      type.x    <- div.groups[1]
      type.y    <- div.groups[2]
      x.samps   <- subset( div.map, div.map[,div.type] == type.x )$Sample.Name
      y.samps   <- subset( div.map, div.map[,div.type] == type.y )$Sample.Name      
      if( length(x.samps) <= 3 | length(y.samps) <= 3 ){
        print( paste( "You have fewer than three samples for one of the fields in <", 
                      div.type, 
                      ">, so we don't have ",
                      "enough data to identify significant differences. I will skip.", 
                      sep="" 
        ) 
        )
        next;          
      }        
      if( test.type == "t.test" ){
        rawp0 <- apply(test.data, 1, function(x) t.test(x~classes)$p.value)
      } else if( test.type == "wilcoxon" ){        
        rawp0 <- apply(test.data, 1, 
                       function(x) pvalue(
                         wilcox_test(x~factor(classes), 
                                     data = list( abundance = x, 
                                                  feature = factor(classes) ), 
                                     distribution="exact" ) 
                       ) 
        )
      }
    } else { #then kruskal wallis
      test.type <- "kw"
      rawp0   <- apply( test.data, 1, 
                        function(x) pvalue( 
                          kruskal_test( x~classes,
                                        data = list(abundance = x, 
                                                    feature = classes ), 
                                        distribution = approximate(B=5000) 
                          ) 
                        )
      )            
    }
    names( rawp0 ) <- rownames(test.data)
    rnd.p  <- correct_p( rawp0, test.data )
    rnd.p2 <- data.frame( test.type=test.type, rnd.p)
    ##now do something with this output
    tab.file <- paste( outpath, "/", test.type, "-", div.type, ".tab", sep="" )
    print( paste( "Generating p-value table for ", tab.file, sep="") )
    write.table( rnd.p2, tab.file )
    if( to.plot ){
      plot.tab  <- subset( rnd.p2, rnd.p2$qvalue < plot.q.threshold )
      plot.data <- subset( test.data, 
                           rownames( test.data ) %in% rownames( plot.tab ) 
      )
      for( i in 1:dim(plot.data)[1]){
        family <- rownames(plot.data)[i]
        data   <- plot.data[i,]
        outfile <- paste( outpath, "/", "Boxplot-Family-" , 
                          family, "-", div.type, ".pdf", sep="")
        pdf( file = outfile )
        boxplot( data~classes, xlab=div.type, ylab="Abundance" )
        dev.off()
      }
    }
  }
}

##################################################
### cluster_samples()
### Cluster samples
##################################################
cluster_samples <- function(div.map, abund.map, outpath){
  plotstem     <- NULL
  distmethods  <- c( "bray", "jaccard", "canberra")
  clustmethods <- c( "hclust" )
  for( a in 1:length( colnames(div.map) ) ){
    div.type  <- colnames(div.map)[a]     
    if( !( is_categorical_field( div.type ) ) ){
      next
    }                                        
    div.groups <- unique( div.map[, div.type] )
    for( b in 1:length( distmethods ) ){
      for( d in 1:length( clustmethods ) ){        
        distmethod  <- distmethods[b]    
        clustmethod <- clustmethods[c]
        dist  <- vegdist(abund.map, method = distmethod)   
        if( clustmethod == "hclust" ){
          clust <- hclust(dist, method = "average")
          dend  <- as.dendrogram(clust)
          # Assigning the labels of dendrogram object with new colors:
          color.groups        <- topo.colors(length(div.groups))
          names(color.groups) <- div.groups
          dend <- color_labels( dend, 
                                col=as.numeric(
                                  sort(div.map[,div.type])[order.dendrogram(dend)]                                            
                                )
          )
          # Plotting the new dendrogram
          par(cex=0.8)
          plotstem <- paste( outpath,
                             "/", 
                             clustmethod,
                             "-",
                             div.type,
                             "-",
                             distmethod,
                             ".pdf",
                             sep=""
          )
          pdf( file=plotstem )
          plot(dend, horiz=TRUE)  
          dev.off()
        }
        if( clustmethod == "pam" ){
          pamk.best <- pamk(dist)   
          #silhouette plots
          #plot(pam(dist, pamk.best$nc))
          
        }
      }
    }
  }
}

##################################################
### cluster_families()
### Cluster families based on correlation
##################################################
cluster_families <- function( abund.map ){
  n     <- 20
  set.seed(2000)
  cor   <- cor( abund.map )
  clust <- hclust(as.dist(1-cor), method="average")
  #plot(clust, hang = -1)
  fit   <- cutree( clust, k=n)
  agg   <- NULL
  for( i in 1:n){
    sub     <- abund.map[,names(subset( fit, fit == i))]
    results <- as.data.frame(t(sub)) %>% summarise_each( funs( median  ) )
    agg     <- rbind( agg, results )  
  }
  ## seed(100)
  # cluster 5, 10, 12
  #temporary addition
  order <- c( "WT.4" , "WT.6", "WT.8", "WT.10", "WT.12", 
              "DNR.4", "DNR.6", "DNR.8", "DNR.10", "DNR.12")
  agg   <- agg[,order]
  
  plot(t(agg[5,]), type="l", xlab="n", xaxt="n", col=1, ylim=c(min(agg), max(agg)), lwd=10)
  axis( 1, at=c(1:10),labels=colnames(agg))
  #ylab="Fold Change (sd)", xaxt='n', 
  #main="Variation of Clustered Families",
  for(i in 2:n ){
    lines( t(agg[i,] ), col=i, lwd=10 )
  }
}

##################################################
### cluster_families_by_category()
### Cluster families by category
##################################################
cluster_families_by_category <- function( div.map, med.map, se.map, outpath ){
  #kmeans wants the transpose of our maps - clusters by rows
  med.map <- t( med.map )
  se.map  <- t( se.map )  
  #note: abund map may alternatively be a norm.map  
  #see http://www.statmethods.net/advstats/cluster.html
  min.clustes  <- 1
  max.clusters <- 15
  wss <- (nrow(med.map))*sum(apply(med.map,2,var))
  for( i in 1:max.clusters ) wss[i]<- sum(kmeans(med.map,centers=i)$withinss)
  plot(1:max.clusters, wss, type="b")
  fit<-kmeans(med.map, 5)
  agg<-aggregate(med.map, by=list(fit$cluster),FUN=median)
  agg<-agg[,-1]
  fam.norm.tab.t<-data.frame(med.map, fit$cluster)
  plot(t(agg[1,]), type="l", xlab="", 
       ylab="Fold Change (sd)", xaxt='n', 
       main="Variation of Clustered Families (kmeans, n=10)",
       col=c25[1], ylim=c(min(agg), max(agg)), lwd=10
  )
  for(i in 2:5 ){
    lines( t(agg[i,] ), col=c25[i] )
  }
}

##################################################
### continuous_diversity_analyses()
### Correlate sample properties and diversity
##################################################
continuous_diversity_analyses <- function ( div.map, outpath ){
  corr.tests <- NULL
  for( a in 1:length( colnames(div.map) ) ){
    for( b in 1:length( colnames(div.map) ) ){
      div.type  <- colnames(div.map)[a]
      meta.type <- colnames(div.map)[b]
      if( div.type == meta.type ){
        next
      }
      if( is_sample_field( div.type ) |
            is_sample_field( meta.type) |
            is_categorical_field( div.type  ) |
            is_categorical_field( meta.type ) ){
        next
      }
      ggplot( div.map, aes_string( x = meta.type, y=div.type ) ) +
        geom_point( ) + #if color: geom_point(aes(fill = COLNAME) )
        labs( title = paste( meta.type, " by ", div.type, sep="" ) ) +
        xlab( meta.type ) +
        ylab( div.type )
      file <- paste( outpath, 
                     "/Scatterplots-", meta.type, "-", div.type, ".pdf", 
                     sep="" )
      ggsave( filename = file, plot = last_plot(), width=7, height=7 )
      if( is.numeric( div.map[,meta.type] ) ){
        corr      <- cor.test( div.map[,meta.type], 
                               div.map[,div.type], 
                               method="spearman" 
        )        
        tmp.stats  <- data.frame( meta.field = meta.type, 
                                  div.field = div.type,
                                  rho=corr$estimate, 
                                  pvalue=corr$p.value 
        )      
        corr.tests <- rbind( corr.tests, tmp.stats )    
      }    
    }
  }
  corr.tests <- padjust_table( corr.tests )
  outtable <- paste( outpath, "/categorical_corrtests.tab", sep="")
  write.table( corr.tests, file=outtable)
}

##################################################
### continuous_family_analyses()
### Continuous Family Analyses
##################################################
continuous_family_analyses <- function( div.map, abund.map, outpath, plot.q.threshold ){
  to.plot <- 1
  method  <- "kendall"
  plot.q.threshold <- 0.15 
  for( a in 1:length( colnames(div.map) ) ){
    div.type  <- colnames(div.map)[a]
    if( is_sample_field( div.type )       |
          is_categorical_field( div.type )  ){
      next
    }
    cor.data <- correlate_families_by_category( div.map, abund.map, div.type, method )
    rawp0 <- cor.data$p 
    names( rawp0 ) <- rownames( cor.data )
    corrected <- correct_p( rawp0 )
    results   <- as.data.frame( cbind( test.type = method, corrected) )
    tab.file  <- paste( outpath, "/Correlations-Families-by", div.type, "-", test.type, ".tab", sep="" )
    print( paste( "Generating p-value table ", tab.file, sep="") )
    write.table( rnd.p2, tab.file )
    if( to.plot ){
      fams.2.plot <- subset( results, results$BH < plot.q.threshold )
      for( i in 1:length(fams.2.plot)[1]){
        family   <- rownames(fams.2.plot)[i]
        cor.val  <- cor.data[family, "cor"]
        abunds   <- abund.map[,family]
        div.data <- div.map[,div.type]
        plot.data <- as.data.frame( cbind( abunds, div.data ) )
        ggplot( plot.data, aes_string( x = abunds, y=div.data ) ) +
          geom_point( ) + #if color: geom_point(aes(fill = COLNAME) )
          labs( title = paste( "Family", family, " by ", div.type, "; ", 
                               test.type, " = ", cor.val, sep="" ) ) +
          xlab( "Abundance" ) +
          ylab( div.type )
        file <- paste( outpath, 
                       "/Scatterplots-Family", family, "-", div.type, "-", test.type, ".pdf", 
                       sep="" )
        ggsave( filename = file, plot = last_plot(), width=7, height=7 )
      }      
    }
  }
}

##################################################
### correlate_families_by_category
### Correlate families by category
##################################################
correlate_families_by_category <- function( div.map, abund.map, category, method ){
  sub  <- div.map[div.map$Sample.Name %in% rownames(abund.map),]
  ord  <- sub[ match( rownames(abund.map), sub$Sample.Name),]
  vals <- ord[,category]
  cors <- corr.test( abund.map, as.data.frame(vals), adjust="none", method=method )
  #sig.ids <- which(cors$p < 0.05 )
  #p <- cors$p[sig.ids]
  #r <- cors$r[sig.ids]
  #names <- rownames(cors$r)[sig.ids]
  #results <- data.frame( cor=r, p=p)
  #rownames( results ) <- names
  results <- as.data.frame(cbind( cors$p, cors$r ))
  colnames(results) <- c("p", "cor")
  return( results )
}

##################################################
### correct_p
### Correct p-values for multiple tests
##################################################
correct_p <- function( rawp0 ){
  procs           <- c("BH")
  procs.full      <- c( procs, "qvalue" ) #multtest no likey qvalue
  res             <- mt.rawp2adjp(rawp0, procs, na.rm=TRUE)
  adjp            <- res$adjp[order(res$index), ]
  num.p           <- length(procs) + 1  #add 1 for raw.p
  rnd.p           <- round(adjp[,1:num.p], 4)
  rownames(rnd.p) <- names( rawp0 )
  rnd.p <- as.data.frame( rnd.p )
  if( "qvalue" %in% procs.full ){            
    qvals        <- qvalue( rnd.p[,1] )$qvalues
    rnd.p$qvalue <- qvals
  }
  return(rnd.p)
}

#############################################
### filter_samples_from_map()
### Remove samples (rows) from a table
#############################################
filter_samples_from_map <- function( df, samples.to.filter, category ){
  tmp.map = NULL
  if( category == "rownames" ){
    tmp.map <- subset( df, !(rownames(df) %in% samples.to.filter ) )
  } else if ( !( is.null(category))){
    tmp.map <- subset( df, !(df[,category] %in% samples.to.filter ) )
  } else {
    print ("No category was provided to filter_samples_from_map()")
    exit #this may be sloppy, but quick solution for now
  }
  return( tmp.map )
}

#############################################
### fold_change_norm() 
### Fold change normalization of proteins
#############################################
fold_change_norm <- function( abund.map ){ 
  results    <- NULL
  fam.sd     <- apply( abund.map, 2, sd )
  fam.median <- apply( abund.map, 2, median )
  results    <- ( abund.map - fam.median ) / fam.sd
  return(results)
}

#################################################
### heatmap_samples()
### Heatmap samples
##################################################
heatmap_samples <- function(div.map, abund.map, outpath){
  heatmap(as.matrix(abund.map[1:20,200:300]))
  #heatmap(as.matrix(abund.map[,1:200]))  
  heatmap(cor(as.matrix(t(abund.map[,1:10])), method="kendall"), symm=TRUE)
}

###############################################
### is_categorical_field()
### checks if a field is a categorical property
###############################################
is_categorical_field <- function( field ){
  value = 0
  if( field %in% cat.fields   ){
    value = 1
  }
  return(value)
}

#############################################
### is_sample_field()
### checks if a field is a sample identifier
#############################################
is_sample_field <- function(field){
  value = 0
  if( field  == "Sample.Name"  |
      field  == "Sample.ID"   ){
    value = 1
  }
  return(value)
}

##################################################
### ordinate_samples()
### Ordinate samples
##################################################
ordinate_samples <- function( div.map, abund.map, outpath ){
  centers = c( TRUE, FALSE )
  scales  = c( TRUE, FALSE )
  choices = c( 1,2,3,4 )
  methods = c( "pca", "mds", "pcoa" )
  for( a in 1:length(choices)){
    for( b in 1:length(choices)){
      for( d in 1:length(scales)){
        for( e in 1:length(centers)){
          for( f in 1:length(methods)){
            choice.1 <- choices[a]
            choice.2 <- choices[b]
            if( choice.1 == choice.2 |
                  choice.1 >  choice.2 ){
              next
            }
            scale  = scales[d]
            center = centers[e]
            method = methods[f]
            for( g in 1:length( colnames(div.map) ) ){
              div.type  <- colnames(div.map)[g]     
              if( !( is_categorical_field( div.type ) ) ){
                next
              }                                        
              div.groups <- unique( div.map[, div.type] )
              mod      <- NULL
              plotstem <- NULL
              if( method == "pca" ){
                mod <- prcomp( abund.map, scale=scale, center=center )
                plotstem <- paste( outpath,
                                   "/", 
                                   method,
                                   "-",
                                   div.type,
                                   "_center_", center,
                                   "_scale_", scale, 
                                   "_dims_", choice.1, 
                                   "_", choice.2,
                                   ".pdf",
                                   sep="")              
              }
              if( method == "mds" ){
                distmethod <- "bray"
                dist  <- vegdist(abund.map, method = distmethod)            
                mod   <- metaMDS(abund.map, dist = distmethod, pc=TRUE )
                #stressplot(mod)
                plotstem <- paste( outpath,
                                   "/", 
                                   method,
                                   "-",
                                   div.type,
                                   "_dims_", choice.1, 
                                   "_", choice.2,
                                   ".pdf",
                                   sep="")            
              }   
              pdf( file = plotstem )
              mds.fig <- ordiplot(mod, 
                                  display="sites", 
                                  type = "none", 
                                  choices=c(choice.1,choice.2)
              )
              order.map  <- div.map[match(rownames(mds.fig$sites), 
                                          div.map$Sample.Name)
                                    ,]              
              points(mds.fig$sites, 
                     #pch=19,
                     pch = as.numeric(order.map[,div.type]), 
                     col = as.numeric(order.map[,div.type])
              )             
              for( h in seq(div.groups)){
                div.group <- div.groups[h]        
                ordiellipse(mod,
                            order.map[, div.type], 
                            conf=0.95, 
                            kind="se",
                            choices=c(choice.1,choice.2),
                            col=as.numeric(div.group),
                            show.groups=factor(div.group)
                )
                ordispider(mod,                         
                           order.map[, div.type], 
                           choices=c(choice.1,choice.2),
                           col=as.numeric(div.group),
                           show.groups=div.group
                )                        
              }   
              legend( "topright", 
                      legend=div.groups, 
                      bty="n",
                      #pch=4,
                      pch = as.numeric(div.groups), 
                      col = as.numeric(div.groups),                   
                      #pt.bg=as.numeric(div.map[,div.type])
              )                 
              ###TESTER
              #x <-data.frame(a=rownames(mds.fig$sites),
              #               b=order.map[,"SAMPLE.ID"], 
              #               c=order.map[,div.type], 
              #               d=mds.fig$sites)
              #subset(x, x$c == "WT.6")                        
              dev.off()
            }
          }
        }
      }
    }
  }
}

###############################################
### padjust_table()
### Adds adjusted pvalues to a dataframe
###############################################
padjust_table <- function( table ){
  fdr      <- p.adjust( table$pvalue, method="fdr")
  bons     <- p.adjust( table$pvalue, method="bonferroni")
  table    <- cbind( table, fdr=fdr, bons=bons)
  return(table)
}

########################################
### plot_diversity_stats()
### Plot per sample diversity statistics
########################################
plot_diversity_stats <- function( div.map, outpath ){
  for( b in 1:length( colnames(div.map) ) ){
    div.type <- colnames(div.map)[b]
    if( is_sample_field( div.type) ){
      next
    }
    ggplot( div.map, aes_string(  x="Sample.Name", y= div.type ) ) +
      geom_bar( stat="identity" ) +
      labs( title = paste( div.type, "across samples", sep="" ) ) +
      xlab( "Sample ID" )
    file <- paste( outpath, "/Alpha_diversity_barplots-", div.type, ".pdf", sep="" )
    ggsave( filename = file, plot = last_plot(), width=7, height=7 )
  }
}

###############################################
### prep_div_map()
### Formats div.map for downstream analyses
###############################################
#This can be modified, as newer versions of shotmap don't require;
#we assume order of samples in the metadata file is the desired order
prep_div_map <- function( div.map ){
  tmp.map <- cbind( as.data.frame( rownames(div.map)), div.map ) 
  colnames(tmp.map) <- c( "Sample.Name", colnames(div.map) )
  tmp.map$Sample.Ordered <- factor( tmp.map$Sample.Name, sort( tmp.map$Sample.Name) )
  div.map <- tmp.map
  return( div.map )
}

###############################################
### prep_abund_map()
### Formats abund.map for downstream analyses
###############################################
prep_abund_map <- function( abund.map, ko.to.keep ){  
  my.cols <- colnames(abund.map)[colnames(abund.map) %in% as.character(ko.to.keep$ids)]
  tmp.map <- abund.map[, my.cols ]
  ko.cp   <- ko.to.keep$names
  names(ko.cp) <- as.character( ko.to.keep$ids )
  colnames( tmp.map ) <- ko.cp[ colnames(tmp.map) ]
  return( tmp.map )
}

###############################################
### scale_family_map()
### Scale family map
###############################################
scale_family_map <- function( abund.map){
  scaled <- scale( abund.map )
  return( scaled )
}

###############################################
### se()
### Calculate standard error
###############################################
se <- function(x) {
  std.err <- sqrt(var(x)/length(x))
  return( std.err )
}

###############################################
### set_categorical_fields()
### Set Categorical Fields global variable
###############################################
set_categorical_fields <- function( field.list ){
  assign( "cat.fields", field.list, envir = .GlobalEnv )
}

###############################################
### subset_families_by_category()
### Subset families by category and value
###############################################
subset_families_by_category <- function( div.map, abund.map, category, value  ){
  sub.div <- subset( div.map, div.map[,category] == value )
  tmp     <- subset( abund.map, rownames(abund.map) %in% as.character(sub.div$Sample.Name) )
  return(tmp)
}

###############################################
### summarize_families_by_category()
### Summarize Families by Category
###############################################
summarize_families_by_category <- function( div.map, abund.map, category, fun ){
  tmp <- NULL    
  sub <- data.frame( Sample.Name=div.map$Sample.Name,
                     category=div.map[,category]
  )
  tmp     <- merge( sub, 
                    abund.map, 
                    by.x = "Sample.Name", 
                    by.y = "row.names"
  )
  #tmp <- tmp[,-1] #get rid of redundant SAMPLE.ID
  rownames(tmp) <- tmp$Sample.Name
  tmp         <- tmp[,-1]
  by_category <- tmp %>% group_by("category")
  results     <- by_category %>% summarise_each(  fun  )
  names       <- results[,1]
  results     <- results[,-1]
  rownames(results) <- names
  tmp         <- NULL
  by_category <- NULL
  return( as.data.frame( results ) )
}