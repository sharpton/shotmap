####Good's coverage
####takes matrix of family abundances by sample
#Note: May not make sense for coverage-based abundances!
goods.coverage <- function( abunds.map ) {  
###count = apply( abunds.map, 1, sum ) #this may need to be amended for coverage-based abundances
  count = apply( abunds.map, 1, function(df){length(subset(df, df > 0))} ) 
  tmap  = t(abunds.map)
  singletons = apply( tmap, 2, function(df){length(subset(df, df <= 1 & df > 0 ) ) } ) #what is a singleton in coverage-abudance context?
  coverage   = 1 - ( singletons / count )
  return( coverage )
}

###Autodetect metadata variable type
###takes a list of values and determines if likely discrete or continuous. May not be perfect!
###note that in its current incarnation, this function doesn't work well when sample size is small!
autodetect <- function( val.list, cont.thresh = 0.2, force = NULL ) {
  #cont.thresh is min number of unique vals that constitutes a continuous list?
  if( !is.null( force ) ){
      if( force == "discrete" ){
      	  return( "discrete" )
      } 
      if( force == "continuous" ){
      	  return( "continuous" )
      }
  }
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
