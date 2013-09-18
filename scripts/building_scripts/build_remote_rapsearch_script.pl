#!/usr/bin/perl -w

## ====================================================================================
# Note: the script 'lastal' must be ON YOUR PATH on the REMOTE CLUSTER MACHINE in order for this script to work!
## ====================================================================================

use strict;
use Getopt::Long;

#my @args = ( "build_remote_rapsearch_script.pl", "-o $b_script_path", "-d $fin_blastdb_dir", "-n $blast_db_size" );

my ($outfile);
#my ($in_split_db_dir);
#my ($n_seqs_per_db_split);
my $n_searches       = 1;
my $n_splits         = 1;
my $use_bigmem       = 0; #should this select a big memory machine or not?
my $use_array        = 1; #should this use array jobs or not?
my $memory           = "2G"; #include units in this string, G for Gigabytes, K for Kilobytes
my $walltime         = "0:30:0"; 
my $projectdir       = ""; #what is the top level project dir on the remote server?
my $db_name_stem     = ""; #what is the basename of the db splits, ignoring the arrayjob split number?
my $use_scratch      = 0; #should we use the local scratch directory?
my $format           = 0; #last setting: -f optoin; 0=tab, 1=maf
my $db_suffix        = "rsdb";

GetOptions(
    "o=s"    => \$outfile,
#    "d=s"    => \$in_split_db_dir,
#    "n=i"    => \$n_seqs_per_db_split,
    "n=s"    => \$n_splits,
    "name=s" => \$db_name_stem,
    "z=s"    => \$n_searches,
    "p=s"    => \$projectdir,
    "s=i"    => \$use_scratch,
    "suf=s"  => \$db_suffix,  #prerapsearch index can't point to seq file or will overwrite, so append to seq file name 
    );

#prep the outfile for write
open( OUT, ">$outfile" ) || die "Can't open $outfile for write: $!\n";

##################################
# Build the actual script here
##################################
#THE HEADER
print OUT join( "\n", 
		"#!/bin/bash", 
		"#", 
		"#\$ -S /bin/bash", 
		"#\$ -l arch=linux-x64", 
		"#\$ -l h_rt=" . $walltime, 
		"#\$ -l scratch=3G",
		"#\$ -pe smp 2",
		"#\$ -cwd", 
		"#\$ -r y",
		"#\$ -o /dev/null", 
		"#\$ -e /dev/null", 
		"\n" );
#THE ARRAY JOBS OPTION
if( $use_array ){
    print OUT "##\$ -t 1-" . $n_splits . " NO LONGER SETTING HERE, BUT IN QSUB COMMAND LINE!\n";
}
#MEMORY USAGE
if( $use_bigmem ){
    print OUT "#\$ -l xe5520=true\n";
} else {
    print OUT "#\$ -l mem_free=${memory}\n";
}

print OUT "ulimit -c 0\n"; #suppress core dumps

#GET VARS FROM COMMAND LINE
print OUT join( "\n", "INPATH=\$1", "INPUT=\$2", "DBPATH=\$3", "OUTPATH=\$4", "OUTSTEM=\$5", "\n" );
if ($use_array){
    #if this is a reprocess job, need to map the splits that need to be rerun to array task ids
    print OUT join( "\n", 
		    "SPLIT_REPROC_STRING=\$6\n",
		    "if [[ \$SPLIT_REPROC_STRING && \${SPLIT_REPROC_STRING-x} ]]",
#		    "if [ -z \"\$SPLIT_REPROC_STRING\" ]\;",
		    "then",
		    "INT_TASK_ID=\$(echo \${SPLIT_REPROC_STRING} | awk -v i=\"\${SGE_TASK_ID}\" \'{split(\$0,array,\",\")} END{ print array[i]}\')",		
		    "else",
		    "INT_TASK_ID=\${SGE_TASK_ID}",
		    "fi",
		    "\n" );
    print OUT "DB=${db_name_stem}_\${INT_TASK_ID}.fa.${db_suffix}\n";
    #query_batch_1.fa-seed_seqs_ALL_fci4_6.fa_split_1-last.tab
    print OUT "OUTPUT=\${OUTSTEM}_" . "\${INT_TASK_ID}" . ".tab\n";

} else {
    print OUT "DB=\$6\n";
    print OUT "DB=\${DB}.${db_suffix}\n";
    print OUT "OUTPUT=\$OUTSTEM\n";
    #print OUT "SPLIT_REPOC_STRING=\$7\n"; Can't have an array-based reprocess job if not use_array. But, this might be a useful var at some point
}
#LAST BIT OF HEADER
print OUT join( "\n", "PROJDIR=" . $projectdir, "LOGS=\${PROJDIR}/logs", "\n" );

#CHECK TO SEE IF DATA ALREADY EXISTS IN OUTPUT LOCATION. IF SO, SKIP
#Failed jobs means that we can't do this any more. Have to be intellegenet about how we restart jobs (see above block: INT_TASK_ID)
#print OUT join( "\n",
#		"if [ -e \${OUTPATH}/\${OUTPUT} ]",
#		"then",
#		"exit",
#		"fi",
#		"\n" );

my $RAP_ALL;
if( $use_array ){
    $RAP_ALL = "\$LOGS/rapsearch/\${JOB_ID}.\${INT_TASK_ID}.all";
}
else{
    $RAP_ALL = "\$LOGS/rapsearch/\${JOB_ID}.all";
}

#GET METADATA ASSOCIATED WITH JOB
print OUT join( "\n", 
		"qstat -f -j \${JOB_ID}                             > ${RAP_ALL} 2>&1",
		"uname -a                                          >> ${RAP_ALL} 2>&1",
		"echo \"****************************\"             >> ${RAP_ALL} 2>&1",
		"echo \"RUNNING RAPSEARCH WITH \$*\"               >> ${RAP_ALL} 2>&1",
		"echo \"INT_TASK_ID IS \${INT_TASK_ID}\"           >> ${RAP_ALL} 2>&1",
		"date                                              >> ${RAP_ALL} 2>&1",
		"\n" );




if( $use_scratch ){
    #DO SOME ACTUAL WORK: Clean old files
    print OUT join( "\n",
		    "files=\$(ls /scratch/\${DB}* 2> /dev/null | wc -l )  >> ${RAP_ALL} 2>&1",
		    "echo \$files                                         >> ${RAP_ALL} 2>&1",
		    "if [ \"\$files\" != \"0\" ]; then",
		    "    echo \"Removing cache files\"",
		    "    rm /scratch/\${DB}*",
		    "else",
		    "    echo \"No cache files...\"",
		    "fi                                             >> ${RAP_ALL} 2>&1",
		    "\n" );
    #Copy files over to the node's scratch dir
    print OUT join( "\n",
		    "echo \"Copying dbfiles to scratch\"            >> ${RAP_ALL} 2>&1",
		    "cp -f \${DBPATH}/\${DB}*.gz /scratch/              >> ${RAP_ALL} 2>&1",
		    "gunzip /scratch/\${DB}*.gz                      >> ${RAP_ALL} 2>&1",
		    "echo \"Copying input file to scratch\"         >> ${RAP_ALL} 2>&1",
		    "cp -f \${INPATH}/\${INPUT} /scratch/\${INPUT}     >> ${RAP_ALL} 2>&1",
		    "\n");
    #RUN
    print OUT "date                                                                                   >> ${RAP_ALL} 2>&1\n";
    #we don't want alignments, just the statistics, so -b 0
    print OUT "echo \"rapsearch -b 0 -q /scratch/\${INPUT} -d /scratch/\${DB} -o /scratch/\${OUTPUT}\" >> ${RAP_ALL} 2>&1\n";
    print OUT "rapsearch -b 0 -q /scratch/\${INPUT} -d /scratch/\${DB} -o /scratch/\${OUTPUT}          >> ${RAP_ALL} 2>&1\n";
    print OUT "date                                                                                    >> ${RAP_ALL} 2>&1\n";
    #CLEANUP
    print OUT join( "\n",
		    "echo \"removing input and dbfiles from scratch\" >> ${RAP_ALL} 2>&1",
		    "rm /scratch/\${INPUT}                            >> ${RAP_ALL} 2>&1",
		    "rm /scratch/\${DB}*                              >> ${RAP_ALL} 2>&1",
		    "echo \"moving results to main\"                  >> ${RAP_ALL} 2>&1",
		    "mv /scratch/\${OUTPUT}* \${OUTPATH}/             >> ${RAP_ALL} 2>&1", #rapsearch generates .m8 and .aln suffixes on $OUTPUT
		    "echo \"moved to main\"                           >> ${RAP_ALL} 2>&1",
		    "date                                             >> ${RAP_ALL} 2>&1",
		    "echo \"RUN FINISHED\"                            >> ${RAP_ALL} 2>&1",
		    "\n" );
} else {
    print( "Not using scratch\n" );
    print OUT "date                                                                                      >> ${RAP_ALL} 2>&1\n";
    #we don't want alignments, just statistics, so -b 0
    print OUT "echo \"rapsearch -b 0 -q \${INPATH}/\${INPUT} -d \${DBPATH}/\${DB} -o \${OUTPATH}/\${OUTPUT}\" >> ${RAP_ALL} 2>&1\n";
    print OUT "rapsearch -b 0 -q \${INPATH}/\${INPUT} -d \${DBPATH}/\${DB} -o \${OUTPATH}/\${OUTPUT}          >> ${RAP_ALL} 2>&1\n";
    print OUT "date                                                                                      >> ${RAP_ALL} 2>&1\n";
    #CLEANUP
    print OUT join( "\n",
		    "date                                             >> ${RAP_ALL} 2>&1",
		    "echo \"RUN FINISHED\"                            >> ${RAP_ALL} 2>&1",
		    "\n" );
}
close OUT;
