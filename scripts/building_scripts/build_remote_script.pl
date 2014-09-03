#!/usr/bin/perl -w

use strict;
use Getopt::Long;

my ( 
    $type,
    $outfile, 
    $cluster_configuration_file, 
    $projectdir,
    $method,
    $db_name_stem,
    $db_size,
 );

my $use_array             = 1;
my $use_scratch           = 1;
my $db_suffix             = "rsdb"; #only for rapsearch
my $rapsearch_n_hits      = 1;
my $hmmer_maxacc          = 1;
my $cpus                  = 1;
my $score_threshold       = 25;
my $last_max_multiplicity = 10; #increase to improve sensitivity
my $metatrans_len_cutoff  = 1;
my $compress              = 0;

GetOptions(
    "t=s"                    => \$type, #search, orfs, dbformat
    "o=s"                    => \$outfile,
    "c=s"                    => \$cluster_configuration_file,
    "m=s"                    => \$method,
    "p=s"                    => \$projectdir,
    "name|n=s"               => \$db_name_stem,
    "scratch"                => \$use_scratch,
    "array"                  => \$use_array,
    "suffix:s"               => \$db_suffix,
    "min-score:f"            => \$score_threshold, #either score or evalue
    "db-size:i"              => \$db_size, 
    "rapsearch-n-hits:i"     => \$rapsearch_n_hits,    
    "hmmer_maxacc!"          => \$hmmer_maxacc,
    "metatrans_len_cutoff:i" => \$metatrans_len_cutoff,
    "compress!"              => \$compress,
    "nprocs:i"               => \$cpus,
    );

#prep the outfile for write
open( my $out, ">$outfile" ) || die "Can't open $outfile for write: $!\n";

#import cluster configuration data
my $cluster_config = import_cluster_configs( $cluster_configuration_file );
print $out $cluster_config;

print $out get_header_strings( $type, $method, $db_name_stem, $projectdir, $use_array, $use_scratch );
print $out get_metadata_strings( $method );
print $out get_scratch_prefix( $type ) if $use_scratch;

#print $out run_strings( $method, $use_scratch, $threshold, $db_suffix );

print $out get_run_strings( search_method        => $method,
			    use_scratch          => $use_scratch,
			    score_threshold      => $score_threshold,
			    db_suffix            => $db_suffix,
			    rapsearch_n_hits     => $rapsearch_n_hits,
			    db_size              => $db_size,
			    hmmer_maxacc         => $hmmer_maxacc,
			    metatrans_len_cutoff => $metatrans_len_cutoff,
			    compress             => $compress,
			    cpus                 => $cpus,
			    
    );

print $out get_cleanup_strings( $type, $use_scratch );

close $out;

sub get_header_strings{
    my ( $type, $method, $db_name_stem, $projectsdir, $use_array, $use_scratch ) = @_;
    my $string = "";
    if( $type eq "search" ){
	$string   .= join( "\n", "INPATH=\$1", "INPUT=\$2", "DBPATH=\$3", "OUTPATH=\$4", "OUTSTEM=\$5", "\n" );
	if ($use_array){
	    #if this is a reprocess job, need to map the splits that need to be rerun to array task ids
	    $string .= join( "\n", 
			     "SPLIT_REPROC_STRING=\$6\n",
			     "if [[ \$SPLIT_REPROC_STRING && \${SPLIT_REPROC_STRING-x} ]]",
			     #"if [ -z \"\$SPLIT_REPROC_STRING\" ]\;",
			     "then",
			     "INT_TASK_ID=\$(echo \${SPLIT_REPROC_STRING} | awk -v i=\"\${SGE_TASK_ID}\" \'{split(\$0,array,\",\")} END{ print array[i]}\')",		
			     "else",
			     "INT_TASK_ID=\${SGE_TASK_ID}",
			     "fi",
			     "\n" );
	    #print OUT "DB=${db_name_stem}_\${INT_TASK_ID}.fa.${db_suffix}\n";
	    $string .= "DB=" . ${db_name_stem} ."_\${INT_TASK_ID}.fa\n";
	    $string .= "OUTPUT=\${OUTSTEM}_" . "\${INT_TASK_ID}" . ".tab\n";
	} else {
	    $string .= "DB=\$6\n";
	    $string .= "OUTPUT=\$OUTSTEM\n";
	}
    } elsif( $type eq "orfs" ){
	$string   .= join( "\n", "INPATH=\$1", "INSTEM=\$2", "OUTPATH=\$3", "OUTSTEM=\$4", "\n" );
	if( $use_array ){
	    $string   .= join( "\n", "INPUT=\${INBASENAME}\${SGE_TASK_ID}.fa", "OUTPUT=\${OUTBASENAME}\${SGE_TASK_ID}.fa", "\n" );
	} else {
	    $string   .= join( "\n", "INPUT=\${INBASENAME}.fa", "OUTPUT=\${OUTBASENAME}.fa", "\n" );
	}
    } elsif( $type eq "dbformat" ){
	$string   .= join( "\n", "DBPATH=\$1", "\n" );
	if( $use_array ){
	    $string   .= "DB=" . $db_name_stem . "_\${SGE_TASK_ID}.fa\n";
	} else {
	    $string   .= "DB=\$2\n";
	}	
    }

    $string .= join( "\n", "PROJDIR=" . $projectdir, "LOGS=\${PROJDIR}/logs", "\n" );
    $string .= get_log_string( $method, $use_scratch );
    return $string;
}

sub get_log_string{
    my $method = shift;
    my $use_scratch   = shift;
    my $string        = "";
    if( $use_array ){
	$string .= "LOG=\${LOGS}/" . $method . "/\${JOB_ID}.\${INT_TASK_ID}.all\n";
    } else{
	$string .= "LOG=\${LOGS}/" . $method . "/\${JOB_ID}.all\n";
    }
    return $string;
}

sub get_metadata_strings{
    my $method = shift;
    my $string        = "";
    $string   .= join( "\n", 
		       "qstat -f -j \${JOB_ID}                             > \${LOG} 2>&1",
		       "uname -a                                          >> \${LOG} 2>&1",
		       "echo \"****************************\"             >> \${LOG} 2>&1",
		       "echo \"RUNNING " . uc($method) . "WITH \$*\"               >> \${LOG} 2>&1",
		       "echo \"INT_TASK_ID IS \${INT_TASK_ID}\"           >> \${LOG} 2>&1",
		       "date                                              >> \${LOG} 2>&1",
		       "\n" );
    return $string;
}

sub get_cleanup_strings{
    my $type        = shift;
    my $use_scratch = shift;
    my $string      = "";
    if( $use_scratch ){
       	if( $type eq "search"){
	    $string .= join( "\n",
			     "rm /scratch/\${DB}*                              >> \${LOG} 2>&1",
			     "\n" );
	}
	if( $type eq "search" || $type eq "orfs" ){
	    $string .= join( "\n",
			     "echo \"removing non-output files from scratch\" >> \${LOG} 2>&1",
			     "rm /scratch/\${INPUT}                            >> \${LOG} 2>&1",
			     "\n" );
	    $string  .= join( "\n",
			      "echo \"moving results to main\"                  >> \${LOG} 2>&1",
			      "mv /scratch/\${OUTPUT}* \${OUTPATH}/             >> \${LOG} 2>&1", #e.g., rapsearch generates .m8 and .aln suffixes on $OUTPUT
			      "echo \"moved to main\"                           >> \${LOG} 2>&1",
			      "date                                             >> \${LOG} 2>&1",
			      "echo \"RUN FINISHED\"                            >> \${LOG} 2>&1",
			      "\n" );	
	}
	if( $type eq "dbformat" ){
	      $string .= join( "\n",
			       "echo \"removing input and dbfiles from scratch\" >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "echo \"moving results to main\"                  >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       #"gzip /scratch/\${DB}*                            >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "mv /scratch/\${DB}* \${DBPATH}/                  >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "echo \"moved to main\"                           >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "date                                             >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "echo \"RUN FINISHED\"                            >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "\n" );
	}
    } else {
	$string    .= join( "\n",
			    "date                                             >> \${LOG} 2>&1",
			    "echo \"RUN FINISHED\"                            >> \${LOG} 2>&1",
			    "\n" );    
    }
    return $string;
}

sub get_scratch_prefix{
    my $type   = shift;
    my $string = "";
    #DO SOME ACTUAL WORK: Clean old files
    if( $type eq "search" || $type eq "dbformat" ){
	$string   .= join( "\n",
			   "files=\$(ls /scratch/\${DB}* 2> /dev/null | wc -l )  >> \${LOG} 2>&1",
			   "echo \$files                                         >> \${LOG} 2>&1",
			   "if [ \"\$files\" != \"0\" ]; then",
			   "    echo \"Removing cache files\"",
			   "    rm /scratch/\${DB}*",
			   "else",
			   "    echo \"No cache files...\"",
			   "fi                                                  >> \${LOG} 2>&1",
			   "\n" );
	#Copy files over to the node's scratch dir
	$string   .= join( "\n",
			   "echo \"Copying dbfiles to scratch\"             >> \${LOG} 2>&1",
			   "\n");
	$string   .= join( "\n",		       
			   "cp -f \${DBPATH}/\${DB}* /scratch/              >> \${LOG} 2>&1",
			   "ls /scratch/\${DB}* >> \${LOG} 2>&1",
			   "gunzip /scratch/\${DB}*.gz                      >> \${LOG} 2>&1",
			   "\n");
    }
    if( $type eq "orfs" || $type eq "search" ){
	$string   .= join ("\n", "echo \"Copying input file to scratch\"         >> \${LOG} 2>&1",
			   "cp -f \${INPATH}/\${INPUT} /scratch/\${INPUT}  >> \${LOG} 2>&1",
			   "\n");
    }
    return $string;
}

sub import_cluster_configs{
    my ( $cluster_configuration_file ) = shift;
    my $string = "";
    open (FILE, $cluster_configuration_file ) || die "Can't open $cluster_configuration_file for read: $!\n";
    while(<FILE>){
	$string .= $_;
    }
    close FILE;
    return $string
}

sub get_run_strings{
    my( %vals ) = @_;
    my $method       = $vals{"search_method"};
    my $use_scratch  = $vals{"use_scratch"};
    my $compress     = $vals{"compress"};
    # notice method specific values invoked below
    my $string      = "";

    # set up a few universal vars
    my( $query, $db, $out, $cmd );
    if( $use_scratch ){
	$query   = "/scratch/\${INPUT}";
	$db      = "/scratch/\${DB}";
	$out     = "/scratch/\${OUTPUT}";
    } else {
	$query   = "\${INPATH}/\${INPUT}";
	$db      = "\${DBPATH}/\${DB}";
	$out     = "\${OUTPATH}/\${OUTPUT}";
    }    

    $string .= "date  >> \${LOG} 2>&1\n";
    #####
    # HOMOLOGY SEARCH
    #####
    if( $method eq "rapsearch_accelerated" ){	
	my $score_threshold  = $vals{"score_threshold"};
	my $db_suffix        = $vals{"db_suffix"};
	my $n_hit_report     = $vals{"rapsearch_n_hits"};
	$db = $db . "." . $db_suffix;
	$cmd  = "rapsearch -b 0 -v " . $n_hit_report . " -i " . $score_threshold . " -a T -q " . $query . " -d " . $db . " -o " . $out;
    } elsif( $method eq "rapsearch" ){
	my $score_threshold  = $vals{"score_threshold"};
	my $db_suffix        = $vals{"db_suffix"};
	my $n_hit_report     = $vals{"rapsearch_n_hits"};
	$db = $db . "." . $db_suffix;
	$cmd  = "rapsearch -b 0 -v " . $n_hit_report . " -i " . $score_threshold . " -a F -q " . $query . " -d " . $db . " -o " . $out;
    } elsif( $method eq "blast" ){
	my $cpus           = $vals{"cpus"};
	my $blastdb_size   = $vals{"db_size"};
	$cmd = "blastp -query " . $query . " -db " . $db . " -out " . $out . " -dbsize " . $blastdb_size . " -num_threads " . $cpus . " -outfmt 6";
    } elsif( $method eq "last" ){
	my $min_aln_score    = $vals{"score_threshold"};
	my $max_multiplicity = $vals{"last_max_multiplicity"};
	$cmd = "lastal -e" . $min_aln_score . " -f 0  -m" . $max_multiplicity . " " . $db . " " . $query . " -o " . $out;
    } elsif( $method eq "hmmsearch" ){
	my $n_searches     = $vals{"db_size"};
	my $maxacc         = $vals{"hmmer_maxacc"};
	my $cpus           = $vals{"cpus"};
	if( $maxacc ){
	    $cmd = "hmmsearch -Z " . $n_searches . " --max --noali --cpu " . $cpus . " --domtblout " . $out . " " . $db . " " . $query;
	}
	else{
	    $cmd = "hmmsearch -Z " . $n_searches . " --noali --cpu " . $cpus . " --domtblout " . $out . " " . $db . " " . $query;
	}
    } elsif( $method eq "hmmscan" ){
	my $n_searches     = $vals{"db_size"};
	my $maxacc         = $vals{"hmmer_maxacc"};
	my $cpus           = $vals{"cpus"};
	if( $maxacc ){
	    $cmd = "hmmscan -Z " . $n_searches . " --max --noali --cpu " . $cpus . " --domtblout " . $out . " " . $db . " " . $query;
	}
	else{
	    $cmd = "hmmscan -Z " . $n_searches . " --noali --cpu " . $cpus . " --domtblout " . $out . " " . $db . " " . $query;
	}
    } 
    #####
    # GENE PREDICTION
    #####
    elsif( $method eq "6FT" ){
	$cmd = "metatrans.py -m 6FT " . $query . " " . $out;	
    } elsif( $method eq "6FT_split" ){
	my $length_cutoff = $vals{"metatrans_len_cutoff"};
	$cmd = "metatrans.py -m 6FT-split -l " . $length_cutoff . " " . $query . " " . $out;
    } elsif( $method eq "prodigal" ){
	$cmd = "metatrans.py -m Prodigal " . $query . " " . $out;
    } 
    #####
    # SEARCH DB FORMATTING
    #####
    elsif( $method eq "makeblastdb" ){
	$cmd = "makeblastdb -dbtype prot -in " . $db;
    } elsif( $method eq "lastdb" ){
	$cmd = "lastdb -p $db $db";
    } elsif( $method eq "prerapsearch" ){
	my $db_suffix  = $vals{"db_suffix"};
	$cmd = "prerapsearch -d " . $db . " -n " . $db . "." . $db_suffix;
    } else {
	die( "I don't know how to build submission scripts for the search method $method\n" );
    }  
    #print the command
    $string .= "echo \"" . $cmd . "\" >> \${LOG} 2>&1\n";
    $string .= $cmd . ">> \${LOG} 2>&1\n";
    if( $compress ){
	$string .= "echo \"gzip " . $out . "\" >> \${LOG} 2>&1\n";
	$string .= "gzip " . $out . " >> \${LOG} 2>&1\n";
    }
    $string .= "date  >> \${LOG} 2>&1\n";
    return $string;
}

