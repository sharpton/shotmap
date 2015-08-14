ShotMAP Metadata Files
---------------------

ShotMAP can accept user defined metadata, which it applies to the statistical tests it ultimately conducts. The format requirements are simple:

1. It is a tab delimited file
2. The first row is a header row that names each metadata field (no spaces please)
3. The first column is named Sample.Name and lists, one per row, the sample names for each sample included in your analysis. 

The sample identifier is simply the file name corresponding to each metagenomic sample, without the file extension. So, if we processed
a metagenomic sample with the filename 

* O2.UC11.0.fa.gz

the corresponding sample name would be 

* O2.UC11.0

The file O2.UC11.0.fa would have the same sample name.

An example metadata file can be found [here](../data/stool_sim_multiple/metadata/stool_sim_multiple_metadata.txt).

