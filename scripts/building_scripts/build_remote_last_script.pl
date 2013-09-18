#!/usr/bin/perl -w

## ====================================================================================
# Note: the script 'lastal' must be ON YOUR PATH on the REMOTE CLUSTER MACHINE in order for this script to work!
## ====================================================================================

use strict;
use Getopt::Long;

#my @args = ( "build_remote_last_script.pl", "-o $b_script_path", "-d $fin_blastdb_dir", "-n $blast_db_size" );

my ($outfile);
#my ($in_split_db_dir);
#my ($n_seqs_per_db_split);
my $n_searches     = 1;
my $n_splits       = 1;
my $use_bigmem         = 0; #should this select a big memory machine or not? NEVER SET ANYWHERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
my $use_array          = 1; #should this use array jobs or not? . NEVER SET ANYWHERE!!!!!!!!!!!!!!!!!
my $memory         = "5G"; #include units in this string, G for Gigabytes, K for Kilobytes
my $walltime       = "0:30:0"; #my $walltime       = "336:00:0";
my $projectdir     = ""; #what is the top level project dir on the remote server?
my $db_name_stem   = ""; #what is the basename of the db splits, ignoring the arrayjob split number?
my $use_scratch        = 0; #should we use the local scratch directory?
my $format         = 0; #last setting: -f optoin; 0=tab, 1=maf
my $max_multiplicity = 1000; #last setting: -m option
my $min_aln_score    = 40;  #last setting: -e option

#temp settings...
$max_multiplicity = 100; #last setting: -m option
$min_aln_score    = 70;  #last setting: -e option

GetOptions(
    "o=s"    => \$outfile,
#    "d=s"    => \$in_split_db_dir,
#    "n=i"    => \$n_seqs_per_db_split,
    "n=s"    => \$n_splits,
    "name=s" => \$db_name_stem,
    "z=s"    => \$n_searches,
    "p=s"    => \$projectdir,
    "s=i"    => \$use_scratch,
    "m=i"    => \$max_multiplicity,
    "e=i"    => \$min_aln_score,
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
#		"#\$ -l arch=lx24-amd64", 
		"#\$ -l arch=linux-x64", 
		"#\$ -l h_rt=" . $walltime, 
		"#\$ -l scratch=0.25G",
		"#\$ -pe smp 2",
		"#\$ -cwd", 
		"#\$ -r y",
		"#\$ -o /dev/null", 
		"#\$ -e /dev/null", 
		"\n" );
#THE ARRAY JOBS OPTION
if( $use_array ){
    print OUT "#\$ -t 1-" . $n_splits . "\n";
}
#MEMORY USAGE
if( $use_bigmem ){
    print OUT "#\$ -l xe5520=true\n";
} else {
    print OUT "#\$ -l mem_free=${memory}\n";
}

#GET VARS FROM COMMAND LINE
print OUT join( "\n", "INPATH=\$1", "INPUT=\$2", "DBPATH=\$3", "OUTPATH=\$4", "OUTSTEM=\$5", "\n" );
if ($use_array){
    print OUT "DB=${db_name_stem}_\${SGE_TASK_ID}.fa\n";
    #query_batch_1.fa-seed_seqs_ALL_fci4_6.fa_split_1-last.tab
    print OUT "OUTPUT=\${OUTSTEM}_" . "\${SGE_TASK_ID}" . ".tab\n";
} else {
    print OUT "DB=\$6\n";
    print OUT "OUTPUT=\$OUTSTEM\n";
}
#LAST BIT OF HEADER
print OUT join( "\n", "PROJDIR=" . $projectdir, "LOGS=\${PROJDIR}/logs", "\n" );

#CHECK TO SEE IF DATA ALREADY EXISTS IN OUTPUT LOCATION. IF SO, SKIP
print OUT join( "\n",
		"if [ -e \${OUTPATH}/\${OUTPUT} ]",
		"then",
		"exit",
		"fi",
		"\n" );


my $LAST_ALL = "\$LOGS/last/\${JOB_ID}.\${SGE_TASK_ID}.all";

#GET METADATA ASSOCIATED WITH JOB
print OUT join( "\n", 
		"qstat -f -j \${JOB_ID}                             > ${LAST_ALL} 2>&1",
		"uname -a                                          >> ${LAST_ALL} 2>&1",
		"echo \"****************************\"             >> ${LAST_ALL} 2>&1",
		"echo \"RUNNING LAST WITH \$*\"                 >> ${LAST_ALL} 2>&1",
#		"source /netapp/home/sharpton/.bash_profile        >> ${LAST_ALL} 2>&1",
		"date                                              >> ${LAST_ALL} 2>&1",
		"\n" );

if( $use_scratch ){
    #DO SOME ACTUAL WORK: Clean old files
    print OUT join( "\n",
		    "files=\$(ls /scratch/\${DB}* 2> /dev/null | wc -l )  >> ${LAST_ALL} 2>&1",
		    "echo \$files                                         >> ${LAST_ALL} 2>&1",
		    "if [ \"\$files\" != \"0\" ]; then",
		    "    echo \"Removing cache files\"",
		    "    rm /scratch/\${DB}*",
		    "else",
		    "    echo \"No cache files...\"",
		    "fi                                             >> ${LAST_ALL} 2>&1",
		    "\n" );
    #Copy files over to the node's scratch dir
    print OUT join( "\n",
		    "echo \"Copying dbfiles to scratch\"            >> ${LAST_ALL} 2>&1",
		    "cp -f \${DBPATH}/\${DB}*.gz /scratch/              >> ${LAST_ALL} 2>&1",
		    "gunzip /scratch/\${DB}*.gz                      >> ${LAST_ALL} 2>&1",
		    "echo \"Copying input file to scratch\"         >> ${LAST_ALL} 2>&1",
		    "cp -f \${INPATH}/\${INPUT} /scratch/\${INPUT}     >> ${LAST_ALL} 2>&1",
		    "\n");
    #RUN LAST
    print OUT "date                                                 >> ${LAST_ALL} 2>&1\n";
    #looks like last uses only score, not evalue, so no -z like option needed
#    print OUT "echo \"lastall -p lastp -z " . $n_searches . " -m 8 -d /scratch/\${DB} -i /scratch/\${INPUT} -o /scratch/\${OUTPUT}\" >> ${LAST_ALL} 2>&1\n";
#    print OUT "lastall -p lastp -z " . $n_searches . " -m 8 -d /scratch/\${DB} -i /scratch/\${INPUT} -o /scratch/\${OUTPUT} >> ${LAST_ALL} 2>&1\n";
    print OUT "echo \"lastal -e" . $min_aln_score . " -f" . $format . " -m" . $max_multiplicity . " /scratch/\${DB} /scratch/\${INPUT} -o /scratch/\${OUTPUT}\" >> ${LAST_ALL} 2>&1\n";
    print OUT "lastal -e" . $min_aln_score . " -f" . $format . " -m" . $max_multiplicity . " /scratch/\${DB} /scratch/\${INPUT} -o /scratch/\${OUTPUT} >> ${LAST_ALL} 2>&1\n";

    print OUT "date                                                 >> ${LAST_ALL} 2>&1\n";
    #CLEANUP
    print OUT join( "\n",
		    "echo \"removing input and dbfiles from scratch\" >> ${LAST_ALL} 2>&1",
		    "rm /scratch/\${INPUT}                            >> ${LAST_ALL} 2>&1",
		    "rm /scratch/\${DB}*                              >> ${LAST_ALL} 2>&1",
		    "echo \"moving results to netapp\"                >> ${LAST_ALL} 2>&1",
		    "mv /scratch/\${OUTPUT} \${OUTPATH}/\${OUTPUT}    >> ${LAST_ALL} 2>&1",
		    "echo \"moved to netapp\"                         >> ${LAST_ALL} 2>&1",
		    "date                                             >> ${LAST_ALL} 2>&1",
		    "echo \"RUN FINISHED\"                            >> ${LAST_ALL} 2>&1",
		    "\n" );
} else {
    print( "Not using scratch\n" );
    #RUN HMMER
    print OUT "date                                                 >> ${LAST_ALL} 2>&1\n";
    #might create switch to futz with F3 filter in the case of long reads
    print OUT "echo \"lastal -e" . $min_aln_score . " -f" . $format . " -m" . $max_multiplicity . " \${DBPATH}/\${DB} \${INPATH}/\${INPUT} -o \${OUTPATH}/\${OUTPUT}\" >> ${LAST_ALL} 2>&1\n";
    print OUT "lastal -e" . $min_aln_score . " -f" . $format . " -m" . $max_multiplicity . " \${DBPATH}/\${DB} \${INPATH}/\${INPUT} -o \${OUTPATH}/\${OUTPUT} >> ${LAST_ALL} 2>&1\n";
    print OUT "date                                                 >> ${LAST_ALL} 2>&1\n";
    #CLEANUP
    print OUT join( "\n",
		    "date                                             >> ${LAST_ALL} 2>&1",
		    "echo \"RUN FINISHED\"                            >> ${LAST_ALL} 2>&1",
		    "\n" );
}
close OUT;
