#!/usr/bin/perl -w

use strict;
use Getopt::Long;

#my @args = ( "build_remote_blast_script.pl", "-o $b_script_path", "-d $fin_blastdb_dir", "-n $blast_db_size" );

my ( $outfile, $in_split_db_dir, $n_seqs_per_db_split );
my $n_searches = 1;
my $n_splits   = 1;
my $bigmem = 0; #should this select a big memory machine or not?
my $array  = 1; #should this use array jobs or not?
my $memory = "1G"; #include units in this string, G for Gigabytes, K for Kilobytes
my $walltime = "0:30:0";
my $projectdir = ""; #what is the top level project dir on the remote server?
my $db_name_stem = ""; #what is the basename of the db splits, ignoring the arrayjob split number?
my $forward_filter = 1; #should the forward filter (F3) be turned on or off? Binary (e.g., 0 = off, 1 = default on)
my $scratch        = 0;

GetOptions(
    "o=s"    => \$outfile,
#    "d=s"    => \$in_split_db_dir,
#    "n=i"    => \$n_seqs_per_db_split,
    "n=s"    => \$n_splits,
    "name=s" => \$db_name_stem,
    "z:s"    => \$n_searches,
    "p=s"    => \$projectdir,
    "f:i"    => \$forward_filter,
    "s:i"    => \$scratch,
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
		"#\$ -l arch=lx24-amd64", 
		"#\$ -l h_rt=" . $walltime, 
		"#\$ -l scratch=0.25G",
		"#\$ -pe smp 2",
		"#\$ -cwd", 
		"#\$ -r y",
		"#\$ -o /dev/null", 
		"#\$ -e /dev/null", 
		"\n" );
#THE ARRAY JOBS OPTION
if( $array ){
    print OUT "#\$ -t 1-" . $n_splits . "\n";
}
#MEMORY USAGE
if( $bigmem ){
    print OUT "#\$ -l xe5520=true\n";
}
else{
    print OUT "#\$ -l mem_free=1G\n";
}
#GET VARS FROM COMMAND LINE
print OUT join( "\n", "INPATH=\$1", "INPUT=\$2", "DBPATH=\$3", "OUTPATH=\$4", "OUTSTEM=\$5", "\n" );
if( $array ){
    print OUT "DB=" . $db_name_stem . "_\${SGE_TASK_ID}.hmm\n";
    #query_batch_1.fa-seed_seqs_ALL_fci4_6.fa_split_1-blast.tab
    print OUT "OUTPUT=\${OUTSTEM}_" . "\${SGE_TASK_ID}" . ".tab\n";
}
else{
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

my $SCAN_ALL_FILE = "\$LOGS/hmmscan/\${JOB_ID}.\${SGE_TASK_ID}.all";

#GET METADATA ASSOCIATED WITH JOB
print OUT join( "\n", 
		"qstat -f -j \${JOB_ID}                             > ${SCAN_ALL_FILE} 2>&1",
		"uname -a                                          >> ${SCAN_ALL_FILE} 2>&1",
		"echo \"****************************\"             >> ${SCAN_ALL_FILE} 2>&1",
		"echo \"RUNNING HMMSCAN WITH \$*\"                 >> ${SCAN_ALL_FILE} 2>&1",
#		"source /netapp/home/sharpton/.bash_profile        >> ${SCAN_ALL_FILE} 2>&1",
		"date                                              >> ${SCAN_ALL_FILE} 2>&1",
		"\n" );
#DO SOME ACTUAL WORK: Clean old files
if( $scratch ){
    print OUT join( "\n",
		    "files=\$(ls /scratch/\${DB}* 2> /dev/null | wc -l )  >> ${SCAN_ALL_FILE} 2>&1",
		    "echo \$files                                         >> ${SCAN_ALL_FILE} 2>&1",
		    "if [ \"\$files\" != \"0\" ]; then",
		    "    echo \"Removing cache files\"",
		    "    rm /scratch/\${DB}*",
		    "else",
		    "    echo \"No cache files...\"",
		    "fi                                             >> ${SCAN_ALL_FILE} 2>&1",
		    "\n" );
    #Copy files over to the node's scratch dir
    print OUT join( "\n",
		    "echo \"Copying dbfiles to scratch\"            >> ${SCAN_ALL_FILE} 2>&1",
		    "cp -f \${DBPATH}/\${DB}.gz /scratch/              >> ${SCAN_ALL_FILE} 2>&1",
		    "gunzip /scratch/\${DB}.gz                      >> ${SCAN_ALL_FILE} 2>&1",
		    "echo \"Running hmmpress\"                      >> ${SCAN_ALL_FILE} 2>&1",
		    "hmmpress -f /scratch/\${DB}                    >> ${SCAN_ALL_FILE} 2>&1",
		    "echo \"Copying input file to scratch\"         >> ${SCAN_ALL_FILE} 2>&1",
		    "cp -f \${INPATH}/\${INPUT} /scratch/\${INPUT}     >> ${SCAN_ALL_FILE} 2>&1",
		    "\n");
    #RUN HMMER
    print OUT "date                                                 >> ${SCAN_ALL_FILE} 2>&1\n";
    #might create switch to futz with F3 filter in the case of long reads
    if( $forward_filter ){
	print OUT "echo \"hmmscan -Z $n_searches --noali --cpu \$NSLOTS --domtblout /scratch/\${OUTPUT} /scratch/\${DB} /scratch/\${INPUT}\"   >> ${SCAN_ALL_FILE} 2>&1\n";
	print OUT "hmmscan -Z $n_searches --noali --cpu \$NSLOTS --domtblout /scratch/\${OUTPUT} /scratch/\${DB} /scratch/\${INPUT}\n";
    }
    else{
	print OUT "echo \"hmmscan -Z $n_searches --F3 1 --noali --cpu \$NSLOTS --domtblout /scratch/\${OUTPUT} /scratch/\${DB} /scratch/\${INPUT}\"   >> ${SCAN_ALL_FILE} 2>&1\n";
	print OUT "hmmscan -Z $n_searches --F3 1 --noali --cpu \$NSLOTS --domtblout /scratch/\${OUTPUT} /scratch/\${DB} /scratch/\${INPUT}\n";
    }
    print OUT "date                                                 >> ${SCAN_ALL_FILE} 2>&1\n";
    #CLEANUP
    print OUT join( "\n",
		    "echo \"removing input and dbfiles from scratch\" >> ${SCAN_ALL_FILE} 2>&1",
		    "/bin/rm /scratch/\${INPUT}                       >> ${SCAN_ALL_FILE} 2>&1",
		    "/bin/rm /scratch/\${DB}*                         >> ${SCAN_ALL_FILE} 2>&1",
		    "echo \"moving results to netapp\"                >> ${SCAN_ALL_FILE} 2>&1",
		    "mv /scratch/\${OUTPUT} \${OUTPATH}/\${OUTPUT}    >> ${SCAN_ALL_FILE} 2>&1",
		    "echo \"moved to netapp\"                         >> ${SCAN_ALL_FILE} 2>&1",
		    "date                                             >> ${SCAN_ALL_FILE} 2>&1",
		    "echo \"RUN FINISHED\"                            >> ${SCAN_ALL_FILE} 2>&1",
		    "\n" );
    close OUT;
}
else{
    print( "Not using scratch\n" );
    #RUN HMMER
    print OUT "date                                                 >> ${SCAN_ALL_FILE} 2>&1\n";
    #might create switch to futz with F3 filter in the case of long reads
    if( $forward_filter ){
	print OUT "echo \"hmmscan -Z $n_searches --noali --cpu \$NSLOTS --domtblout \${OUTPATH}/\${OUTPUT} \${DBPATH}/\${DB} \${INPATH}/\${INPUT}\"   >> ${SCAN_ALL_FILE} 2>&1\n";
	print OUT "hmmscan -Z $n_searches --noali --cpu \$NSLOTS --domtblout \${OUTPATH}/\${OUTPUT} \${DBPATH}/\${DB} \${INPATH}/\${INPUT}\n";
    }
    else{
	print OUT "echo \"hmmscan -Z $n_searches --F3 1 --noali --cpu \$NSLOTS --domtblout \${OUTPATH}/\${OUTPUT} \${DBPATH}/\${DB} \${INPATH}/\${INPUT}\"   >> ${SCAN_ALL_FILE} 2>&1\n";
	print OUT "hmmscan -Z $n_searches --F3 1 --noali --cpu \$NSLOTS --domtblout \${OUTPATH}/\${OUTPUT} \${DBPATH}/\${DB} \${INPATH}/\${INPUT}\n";
    }
    print OUT "date                                                   >> ${SCAN_ALL_FILE} 2>&1\n";
    #CLEANUP
    print OUT join( "\n",
		    "date                                             >> ${SCAN_ALL_FILE} 2>&1",
		    "echo \"RUN FINISHED\"                            >> ${SCAN_ALL_FILE} 2>&1",
		    "\n" );
    close OUT;
}
