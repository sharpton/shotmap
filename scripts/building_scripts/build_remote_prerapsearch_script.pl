#!/usr/bin/perl -w

use strict;
use Getopt::Long;

# Appears to require that 'lastdb' is installed on the remote machine.

#my @args = ( "build_remote_lastdb_script.pl", "-o $b_script_path", "-n $n_splits" );

my ( $outfile, $in_split_db_dir, $n_seqs_per_db_split );
my $n_searches     = 1;
my $n_splits       = 1;
my $bigmem         = 0; #should this select a big memory machine or not?
my $array          = 1; #should this use array jobs or not?
my $memory         = "2G"; #include units in this string, G for Gigabytes, K for Kilobytes
my $walltime       = "0:30:0";
my $projectdir     = ""; #what is the top level project dir on the remote server?
my $db_name_stem   = ""; #what is the basename of the db splits, ignoring the arrayjob split number?
my $scratch        = 0; #should we use the local scratch directory?
my $db_suffix      = "rsdb";

GetOptions(
    "o=s"    => \$outfile,
    "n=s"    => \$n_splits,
    "name=s" => \$db_name_stem,
    "p=s"    => \$projectdir,
    "s:i"    => \$scratch,
    "suf=s"  => \$db_suffix, #prerapsearch index can't point to seq file or will overwrite, so append to seq file name 
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
print OUT join( "\n", "DBPATH=\$1", "\n" );
if( $array ){
    print OUT "DB=" . $db_name_stem . "_\${SGE_TASK_ID}.fa\n";
}
else{
    print OUT "DB=\$2\n";
}
#LAST BIT OF HEADER
print OUT join( "\n", "PROJDIR=" . $projectdir, "LOGS=\${PROJDIR}/logs", "\n" );

#GET METADATA ASSOCIATED WITH JOB
print OUT join( "\n", 
		"qstat -f -j \${JOB_ID}                             > \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		"uname -a                                          >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		"echo \"****************************\"             >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		"echo \"RUNNING PRERAPSEARCH WITH \$*\"            >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
#		"source /netapp/home/sharpton/.bash_profile        >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		"date                                              >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		"\n" );

if( $scratch ){
    #DO SOME ACTUAL WORK: Clean old files
    print OUT join( "\n",
		    "files=\$(ls /scratch/\${DB}* 2> /dev/null | wc -l )  >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "echo \$files                                         >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "if [ \"\$files\" != \"0\" ]; then",
		    "    echo \"Removing cache files\"",
		    "    rm /scratch/\${DB}*",
		    "else",
		    "    echo \"No cache files...\"",
		    "fi                                             >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "\n" );
    #Copy files over to the node's scratch dir
    print OUT join( "\n",
		    "echo \"Copying dbfiles to scratch\"            >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "cp \${DBPATH}/\${DB}.gz /scratch/              >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "gunzip /scratch/\${DB}.gz                      >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "\n");

    #Run the job
    print OUT "date                                                                     >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1\n";
    print OUT "echo \"prerapsearch -d /scratch/\${DB} -n /scratch/\${DB}.${db_suffix}\" >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1\n";
    print OUT "prerapsearch -d /scratch/\${DB} -n /scratch/\${DB}.${db_suffix}          >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1\n";
    print OUT "date                                                                     >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1\n";
    #CLEANUP
    print OUT join( "\n",
		    "echo \"removing input and dbfiles from scratch\" >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "echo \"moving results to main\"                  >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "gzip /scratch/\${DB}*                            >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "mv /scratch/\${DB}*.gz \${DBPATH}/                  >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "echo \"moved to main\"                           >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "date                                             >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "echo \"RUN FINISHED\"                            >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "\n" );
}
else{
    print( "Not using scratch\n" );
    print OUT "date                                                                     >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1\n";
    print OUT "echo \"prerapsearch -d \${DBPATH}/\${DB} -n \${DBPATH}/\${DB}.${db_suffix}\" >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1\n";
    print OUT "prerapsearch -d \${DBPATH}/\${DB} -n \${DBPATH}/\${DB}.${db_suffix}          >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1\n";
    print OUT "date                                                                     >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1\n";
    print OUT join( "\n", 
		    "date                                                               >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "echo \"RUN FINISHED\"                                              >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
		    "\n" );
}
close OUT;
