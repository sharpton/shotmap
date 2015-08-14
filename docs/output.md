Workflow Output
===============

ShotMAP produces a variety of output files that may be of use. Here, these files and their formats are briefly described.

shotmap.pl output:
------------------

###Classification Maps

*Description*: These files provide the classification statistics for each read that was classified into a family. Only 
the results corresponding to the best hit - the hit that resulted in the classification - are shown.

*Location*:

    <ffdb>/output/Classification_Maps/Classification_Map_<Sample.Name>.tab

*Format*: These are comma separated tables, with the following header fields:

    orf_identifier read_identifier sample_id target_sequence family score evalue coverage alignment_length


###Abundance Maps

*Description*: These files provide the abundance of each protein family in each sample. There are three different types:

* Abundance: the abundance of the family, which by default is based on average genome size normalized coverage of the family
* Relative abundance: the fraction of the total abundance across families in a sample that the family occupies
* Counts: the number of reads classified into the family 

*Location*: 

    <ffdb>/output/Abundances/<Abundance.Type>_Map_<Sample.Name>.tab

*Format*: These are tab delimited table files. Columns represent families and rows represent samples. These files include
column names, so the first line is a list of families, as well as row names, so the first column is a list of sample names.
Only those families identified in the processed samples will be represented in these files.

###Alpha-diversity Metadata Table

####Description:

####Location:

####Format:


compare_shotmap_results.pl output:
----------------------------------



