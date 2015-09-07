compare_shotmap_samples.pl
==========================

Usage:
------
    
    perl compare_shotmap_samples.pl
     
Description: 
------------

This script takes a series of shotmap.pl output directories and conducts comparative statistical analyses on the results. 
Users specify which samples from which output directories are to be compared, and this script produces a merged abundance
table (or relative abundance or counts), which can be used in various downstream analyses. 

Additionally, users can optionally provide a metadata file to contextualize
statistical comparisons across samples. For example, this script will evaluate how alpha diversity 
varies across samples associated with various metadata fields, identify protein families whose abundances stratify 
samples of various metadata type, and assess intersample similarity. 

This script leverages the shotmap.R R library (located [here](../lib/R/shotmap.R))
which contains additional functions that may be useful for one-off or custom analyses. We recommend that
users leverage the output abundance tables produced by this script for their own custom analyses.

Examples:
---------

If all of the samples to be compared are located in a single shotmap output directory:

    perl compare_shotmap_samples.pl -i </path/to/shotmap/output/directory/> -o </path/to/statistical/results/dir/>

If you have samples in multiple output directories, you can point -i to a directory list, which is a 
file that contains the directory paths to each of the output directories to be compared, one per line

   perl compare_shotmap_samples.pl -i </path/to/directory/list> -o </path/to/statistical/results/dir/>

For example, this directory list might look like this:

    /data/shotmap_samples/sample_1/
    /data/shotmap_samples/marine_metagenome_20120101/
    /projects/ibd_microbiome/metahit/

All of the samples with shotmap results in these three directories will be processed by compare_shotmap_samples.pl. You can
tell this script to only include a subset of these samples by providing an optional metadata file, which includes only
the samples to be compared:

    perl compare_shotmap_samples.pl -i </path/to/directory/list> -o </path/to/statistical/results/dir/> -m </path/to/metadata/file>

By default, the script will process abundance data as a point of comparison. However, you can alternatively tell it to use
relative abundance or counts data:

    perl compare_shotmap_samples.pl -i </path/to/directory/list> -o </path/to/statistical/results/dir/> --datatype counts

If your metadata file contains categorical data fields, shotmap.R needs to know what they are to conduct the appropriate
types of statistical tests. You can provide compare_shotmap_samples.pl with a categorical fields file, which contains
the metadata file table headings that are associated with categorical fields:

    perl compare_shotmap_samples.pl -i </path/to/directory/list> -o </path/to/statistical/results/dir/> -m </path/to/metadata/file> --cat-fields-file </path/to/categorical/fields/file>

A categorical fields file has a format of one field per line, typed idetically to how it appears in the metadata file.

    Biome_type
    Health_status
    Host_species

Options:
--------

* **-i, --input=STRING** (REQUIRED) DEFAULT: NO DEFAULT

  The location of either the (1) shotmap.pl output directory that contains the samples to be compared or (2) a directory list file
as described above.

* **-d, --datatype=abundances|relative-abundances|counts** (REQUIRED) DEFAULT: abundances

  The type of data to use in statistical comparisons. Either abundances, relative-abundances, or counts.

* **-m, --metadata=STRING** (OPTIONAL) DEFAULT: NO DEFAULT

  The location of the metadata file to be used to contextualize the comparisons. This file can contain fields in addition
to those specified when shotmap.pl was run. If specified, only those samples in this file will be processed.

* **-o, --output=STRING** (REQUIRED) DEFAULT: NO DEFAULT

  The location of the directory that will store the output of this script.

* **--cat-fields=STRING** (OPTIONAL) DEFAULT: NO DEFAULT

  The location of the categorical fields file that indicates which metadata fields are categorical, as described above.

