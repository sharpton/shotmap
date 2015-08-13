Detailed Workflow Synopsis
__________________________

ShotMAP conducts the following steps:

1. Initialize a flatfile database (ffdb) that stores the results of the analysis. 
By default, this is located in the directory that contains the metagenomic samples.
2. Obtain the input metagenomes (fasta formatted, can be gzipped). These should be quality controlled by the user. 
All metagenomes in the directory specified by -i will be processed by shotmap.
While several metagenomes can be processed simultaneously, each sample should be represented by a single file.
The data for each project is stored within a sample subdirectory within the shotMAP ffdb:
ffdb/sample/
The directory containing the input metagenomes may optionally include a metadata file
(see the section on ShotMAP Metadata Files for more information).
3. Split each metagenome file into a set of smaller files to improve parallelization.  
These files are located in the ffdb/sample/raw/ subdirectory.
4. Predict protein coding sequences in each metagenome. 
ShotMAP software can currently run one of three different gene prediction methods: 
six-frame translation via transeq (6FT); 6FT, but splitting on stop codons (6FT_split), and prodigal.
The results are stored in the ffdb/sample/orfs/.
5. Search all metagenomic predicted peptides against each target in a shotMAP formatted search database.
[Note: This database can be built using the program $SHOTMAP_LOCAL/scripts/build_shotmap_searchdb.pl, which
takes as input a protein family database (e.g., protein sequences or HMMs), and formats the database to in a 
mannar appropriate for how the user wants to analyze their data. 
See the secion Building a ShotMAP Search Database
for more information]. 
Search results are stored within ffdb/sample/search_results/.
6. Classify metagenomic sequences into protein families. 
By default, shotMAP assigns metagenomic reads to the family that contains the read's best hit. 
This produces a classification map (ffdb/output/Classification_Map_Sample*) 
that lists which family each classified read is a member of.
7. Use Microbe Census to calculate the average genome size of each metagenome. 
The results are stored in ffdb/sample/ags.
8. Calculates the abundance of each protein family in each sample. 
By default, shotMAP calculates the average genome size normalized coverage of each family in each sample. 
ShotMAP also quantifies the relative abundance of each family, as well as the number of times a read is 
classified into a family (i.e., the family's count).
The output of this step can be found in ffdb/output/Abundances/.
10. Calculate the functional alpha-diversity of each sample. 
Various diversity-associated summary statistics are calucated and placed in the
/ffdb/output/Alpha_diversity directory. 
If multiple samples are included, shotmap conducts statistical comparison of their differences
in functional diversity. If a metadata file is included, shotMAP will evaluate how diveristy 
associates with sample covariates.
11. Identify families that stratify samples, and cluster samples by their interfamily variation.
[Note: These analyses are only attempted if multiple samples are included in an analysis, 
though the script run_stats_tests.pl can be run at a later date on any set of samples]
The results of this analysis are found in ffdb/output/Families and ffdb/output/Beta_diversity
