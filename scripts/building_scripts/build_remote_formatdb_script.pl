#!/usr/bin/perl -w

use strict;
use Getopt::Long;


# Note: JOB_ID is a magic enviroment variable that is set by the cluster somehow.

#my @args = ( "build_remote_formatdb_script.pl", "-o $b_script_path", "-n $n_splits" );

my ( $outfile, $in_split_db_dir, $n_seqs_per_db_split );
my $n_searches     = 1;
my $n_splits       = 1;
my $bigmem         = 0; #should this select a big memory machine or not?
my $use_array          = 1; #should this use array jobs or not?
my $memory         = "1G"; #include units in this string, G for Gigabytes, K for Kilobytes
my $walltime       = "0:30:0";
my $projectdir     = ""; #what is the top level project dir on the remote server?
my $db_name_stem   = ""; #what is the basename of the db splits, ignoring the arrayjob split number?
my $scratch        = 0; #should we use the local scratch directory?

GetOptions(
    "o=s"    => \$outfile,
    "n=s"    => \$n_splits,
    "name=s" => \$db_name_stem,
    "p=s"    => \$projectdir,
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
if( $use_array ){
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
if( $use_array ){
    print OUT "DB=" . $db_name_stem . "_\${SGE_TASK_ID}.fa\n";
}
else{
    print OUT "DB=\$2\n";
}
#LAST BIT OF HEADER
print OUT join( "\n", "PROJDIR=$projectdir", "LOGS=\${PROJDIR}/logs", "\n" );

my $ALL_FILE = "\$LOGS/formatdb/\${JOB_ID}.\${SGE_TASK_ID}.all"; # quoting for the '$'

#GET METADATA ASSOCIATED WITH JOB
print OUT join( "\n", 
		"qstat -f -j \${JOB_ID}                             > ${ALL_FILE} 2>&1", # <-- note, this one is CREATING ('>') a file, not APPENDING ('>>')
		"uname -a                                          >> ${ALL_FILE} 2>&1",
		"echo \"****************************\"             >> ${ALL_FILE} 2>&1",
		"echo \"RUNNING FORMATDB WITH \$*\"                >> ${ALL_FILE} 2>&1",
#		"source /netapp/home/sharpton/.bash_profile        >> ${ALL_FILE} 2>&1",
		"date                                              >> ${ALL_FILE} 2>&1",
		"\n" );

# Alex removed the .bash_profile sourcing here!

if( $scratch ){
    #DO SOME ACTUAL WORK: Clean old files
    print OUT join( "\n",
		    "files=\$(ls /scratch/\${DB}* 2> /dev/null | wc -l )  >> ${ALL_FILE} 2>&1",
		    "echo \$files                                         >> ${ALL_FILE} 2>&1",
		    "if [ \"\$files\" != \"0\" ]; then",
		    "    echo \"Removing cache files\"",
		    "    /bin/rm /scratch/\${DB}*",
		    "else",
		    "    echo \"No cache files...\"",
		    "fi                                             >> ${ALL_FILE} 2>&1",
		    "\n" );
    #Copy files over to the node's scratch dir
    print OUT join( "\n",
		    "echo \"Copying dbfiles to scratch\"            >> ${ALL_FILE} 2>&1",
		    "cp \${DBPATH}/\${DB}.gz /scratch/              >> ${ALL_FILE} 2>&1",
		    "gunzip /scratch/\${DB}.gz                      >> ${ALL_FILE} 2>&1",
		    "\n");
    #RUN HMMER
    print OUT "date                                                 >> ${ALL_FILE} 2>&1\n";
    #might create switch to futz with F3 filter in the case of long reads
    print OUT "echo \"formatdb -p -i /scratch/\${DB}\"              >> ${ALL_FILE} 2>&1\n";
    print OUT "formatdb -p -i /scratch/\${DB}                       >> ${ALL_FILE} 2>&1\n";
    print OUT "date                                                 >> ${ALL_FILE} 2>&1\n";
    #CLEANUP
    print OUT join( "\n",
		    "echo \"removing input and dbfiles from scratch\" >> ${ALL_FILE} 2>&1",
		    "echo \"moving results to netapp\"                >> ${ALL_FILE} 2>&1",
		    "gzip /scratch/\${DB}*                            >> ${ALL_FILE} 2>&1",
		    "mv /scratch/\${DB}*.gz \${DBPATH}/                  >> ${ALL_FILE} 2>&1",
#		    "mv /scratch/\${DB}* \${DBPATH}/\${DB}            >> ${ALL_FILE} 2>&1",
		    "echo \"moved to netapp\"                         >> ${ALL_FILE} 2>&1",
		    "date                                             >> ${ALL_FILE} 2>&1",
		    "echo \"RUN FINISHED\"                            >> ${ALL_FILE} 2>&1",
		    "\n" );
}
else{
    print( "Not using scratch\n" );
    #RUN HMMER
    print OUT "date                                                 >> ${ALL_FILE} 2>&1\n";
    #might create switch to futz with F3 filter in the case of long reads
    print OUT "echo \"formatdb -p -i \${DBPATH}/\${DB}\"            >> ${ALL_FILE} 2>&1\n";
    print OUT "formatdb -p -i \${DBPATH}/\${DB}                     >> ${ALL_FILE} 2>&1\n";
    print OUT "date                                                 >> ${ALL_FILE} 2>&1\n";
    #CLEANUP
    print OUT join( "\n",
		    "date                                             >> ${ALL_FILE} 2>&1",
		    "echo \"RUN FINISHED\"                            >> ${ALL_FILE} 2>&1",
		    "\n" );
}
close OUT;
