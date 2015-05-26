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
