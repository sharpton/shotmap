Detailed Workflow Synopsis
==========================

ShotMAP is a computional workflow that annotates (meta)genomic or (meta)transcritomic sequences based on protein family 
classification. To run the workflow, users must:

1. Obtain input files. These are fasta-formatted nucleic acid sequences files, where each sample corresponds to a single file.
These should be quality controlled by the user. Note that ShotMAP can process multiple samples simultaneously. In this case,
each sample to be processed should be in the same directory. Files should end in .fa, though they can be gzipped (e.g., .fa.gz).

2. Obtain a protein family sequence database that input sequences will be classified into (i.e., the reference database). 
ShotMAP is agnostic to the specific database used, and we leave it up to users to select a database of their preference. 

    Whatever database is used in the analysis, users must first index the database so that ShotMAP can communicate with it. This
is handled by the script [build_shotmap_search_database.pl](docs/build_shotmap_search_database.pl.md). 
Briefly, users point this script to a reference database with the following requirements:

    * the database must consist of either protein sequences in fasta format, with filenames ending in .fa, or HMMs in HMMER3 format, with filenames ending in .hmm
    * each family must exist as an independent file
    * all reference family files must be in the same directory

    The script grabs all reference family files and builds an indexed search database based on user input parameters. A search
database only needs to be indexed one time and can be used for any number of subsequent ShotMAP runs. At its simplest,
you can invoke this script in the following manner:

        perl build_shotmap_search_database.pl -r=</dir/path/to/reference/database/> -d=</dir/path/to/output/search/database/>

3. Run the primary annotation script, [shotmap.pl](docs/shotmap.pl.md). There are a variety of options that can be supplied
to this script, but for most users, you will only need to provide the following:

        perl shotmap.pl -i=</path/to/input/file/> -d=</path/to/search/database/file> -o=</path/to/output/dir/> --nprocs=<number processors to use>

    ShotMAP operates by conducting the following steps:
   * Initialize a flatfile database (ffdb) that stores the results of the analysis. 
   By default, this is located in the directory that contains the metagenomic samples and is named shotmap_ffdb, but users can specify a specific 
   output directory (recommended!) using the -o option.

   * Obtain the input metagenomes (fasta formatted, can be gzipped). If users input a path to a file (recommended!), shotmap.pl will
   only process this single sample. However, if the user supplies a directory, shotmap.pl will process all samples in the folder.
   All metagenomes in the directory specified by -i will be processed by shotmap. Each input file (sample) will have a subdirectory created in the ffdb.

   * Split each metagenome file into a set of smaller files to improve parallelization. These split files are located in following subdirectory: 

        <ffdb>/<sample>/raw/

   * Predict protein coding sequences (orfs) in each sample. ShotMAP can currently run one of three different gene prediction methods: 
       * six-frame translation via transeq (6FT); 
       * 6FT, but splitting on stop codons (6FT_split), and 
       * prodigal.

       The results are stored in the 

            <ffdb>/<sample>/orfs/.

    * Search all predicted peptides against each target in a ShotMAP formatted search database. Search results are stored within <ffdb>/<sample>/search_results/.

    * Classify metagenomic sequences into protein families. By default, ShotMAP assigns metagenomic reads to the family that contains the read's best hit.

    This produces a classification map that provides classification statistics for each read, including the family it was classified into. It can be found here:

        <ffdb>/output/Classification_Maps/

    * Use Microbe Census to calculate the average genome size of each metagenome. The results are stored in:
    
        <ffdb>/<sample>/ags

    * Calculate the abundance of each protein family in each sample. 

    By default, ShotMAP calculates the average genome size normalized coverage of each family in each sample. ShotMAP also quantifies the relative abundance of 
each family, as well as the number of times a read is classified into a family (i.e., the family's count). ShotMAP will output various files that represent these
data in the following directory:

         <ffdb>/output/Abundances

     * Calculate the functional alpha-diversity of each sample (e.g., richness, shannon entropy). Various diversity-associated summary statistics are calucated and placed in

         <ffdb>/output/Metadata/Metadata-Diversity.tab

4. Compare results across samples. 

    In addition to annotating samples, ShotMAP can conduct statistical comparative assessments across samples. Here, the script
[compare_shotmap_results.pl](docs/compare_shotmap_results.pl.md) is used to quantify how protein alpha-diversity varies across samples and measure protein 
family beta-diversity. Users can point this script to multiple ShotMAP flat file directories - so the data being compared need not be processed at the same time - along
with a metadata file that provides additional statistics for each sample (e.g., environmental conditions). The script then executes a variety of functions that evaluate how
changes in protein family diversity vary in accordance with sample properties, identify protein families that stratify samples based on their properties, and assess how
samples relate to one another based on their shared protein family diversity. This script can be invoked in the following manner:

        perl compare_shotmap_results.pl -i=</file/list/of/ffdbs/to/compare> -m=</metadata/table/file> -o=</directory/path/to/comparison/results/>

    This script attempts to automate comparisons, but many analyses will require data-appropriate, customized consideration. We provide a variety of potentially useful analytical
functions via the shotmap.R library which may help users with one-off analyses (see $SHOTMAP_LOCAL/lib/R/shotmap.R). We plan to add functions to these libraries based on 
community need. Please contact us if there are analyses you commonly conduct on ShotMAP output files that you think the community would benefit from having shared access to.

