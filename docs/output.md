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

*Description*: These files contain alpha diversity and other statistics calculated by ShotMAP for each sample, including
protein family richness, shannon entropy, and classification rate. These data are appended to the metadata provided by the user.
If no metadata is provided, then ShotMAP initializes a metadata file, which includes just these statistics.

*Location*:

    <ffdb>/output/Metadata/Metadata-Diversity.tab

*Format*: These are tab delimited files that follow the metadata table file format outlined [here](metadata_files.md).


compare_shotmap_results.pl output:
----------------------------------

###Merged ShotMAP output files

The first thing [compare_shotmap_results.pl](compare_shotmap_results.pl.md) does is merge abundance maps and metadata tables produced by shotmap.pl (see above)
into single files. These may be useful for subsequent, project specific analyses. You can find them in the output directory
specified when running compare_shotmap_results.pl

    <output_directory>/Abundances/Merged_<Abundance.Type>.tab
    <output_directory>/Merged_Metadata.tab

Note that if you specify an additional metadata table when invoking compare_shotmap_results.pl, then the merged metadata table
will contain this additional metadata. Also, it will only process those samples specified in the metadata file.

###Statistical Comparisons

The script then uses R to conduct various statistical comparisons:

####Alpha-diversity analyses

*Description*: Various alpha-diversity (and other) statistics are evaluated across samples and metadata fields. For example, richness, shannon entropy,
and classification rates are subject to robust statistical tests to identify associations between metadata fields and these sample statistics. For
continuous metadata fields, tests of correlation are used. For categorical fields, wilcoxon tests are used. The resulting p-values are subject to 
multiple test correction (qvalue). Both plots and table files are created to represent these results.

*Location*: 

    <output_directory>/Alpha_Diversity/

*Format*: The pdf files contain plots (regression or boxplots, depending on data type) and the file names indicate which diversity statistics and
which metadata fields are represented in the plot. The tab-deliminted table files (.tab) provide the underlying data with the following format:

    Metadata.Field Diversity.Field p.value q.value

####Beta-diversity

*Description*: Intersample distances are calculated based on protein family abundances. Currently, PCA is used to represent the protein family
beta-diversity based on the intersample co-variation in protein family abundance profiles. Ordination plots are produced and colored based on 
sample metadata.

*Location*:

    <output_directory>/Beta_Diversity/

*Format*: The pdf files contain the aforemtioned PCA plots. The file names indicate which metadata field is being used to color samples and which
PC axes are represented in the plot.

####Families

*Description*: The association between family abundance and sample metadata field is quantified using robust statistical tests, such as wilcoxon tests
for categorical fields or kendall's tau for continuous fields. 

*Location*:

    <output_directory>/Families/

*Format*: The pdf files contain either boxplots or regression plots for families that significantly associate with sample metadata properties. 
The tab-delimited table files (.tab) contain the underlying data, with the following header fields:

    Test.Type Family.Identifier Diversity.Field p.value q.value
