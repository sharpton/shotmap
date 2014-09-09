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
my $hmmer_maxacc          = 0;
my $cpus                  = 1;
my $last_max_multiplicity = 10; #increase to improve sensitivity
my $metatrans_len_cutoff  = 1;
my $compress              = 0;
my $delete_raw            = 0;
my $evalue_threshold      = "NULL"; #"NULL" used in parse_results.pl and handler
my $coverage_threshold    = "NULL";
my $score_threshold       = "NULL";

our $scratch_path         = "/scratch/";

GetOptions(
    "t=s"                    => \$type, #search, orfs, dbformat
    "o=s"                    => \$outfile,
    "c=s"                    => \$cluster_configuration_file,
    "m=s"                    => \$method,
    "p=s"                    => \$projectdir,
    "name|n=s"               => \$db_name_stem,
    "scratch!"               => \$use_scratch,
    "array!"                 => \$use_array,
    "suffix:s"               => \$db_suffix,
    "db-size:i"              => \$db_size, 
    "rapsearch-n-hits:i"     => \$rapsearch_n_hits,    
    "hmmer_maxacc!"          => \$hmmer_maxacc,
    "metatrans_len_cutoff:i" => \$metatrans_len_cutoff,
    "compress!"              => \$compress,
    "nprocs:i"               => \$cpus,
    "scratch-path:s"         => \$scratch_path,
    "evalue:f"               => \$evalue_threshold,
    "score:f"                => \$score_threshold, 
    "coverage:f"             => \$coverage_threshold,
    "delete-raw!"            => \$delete_raw,
    );

my $remote_scripts_dir = $projectdir . "/scripts/";

#prep the outfile for write
open( my $out, ">$outfile" ) || die "Can't open $outfile for write: $!\n";

#import cluster configuration data
my $cluster_config = import_cluster_configs( $cluster_configuration_file );
print $out $cluster_config;

print $out get_header_strings( type               => $type, 
			       method             => $method, 
			       db_name_stem       => $db_name_stem, 
			       projectdir         => $projectdir, 
			       use_array          => $use_array, 
			       use_scratch        => $use_scratch,
			       score_threshold    => $score_threshold,
			       evalue_threshold   => $evalue_threshold,
			       coverage_threshold => $coverage_threshold,
			       remote_scripts_dir => $remote_scripts_dir,			       
    );
print $out get_metadata_strings( $type, $method );
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
			    type                 => $type,
			    delete_raw           => $delete_raw,
    );

print $out get_cleanup_strings( $type, $use_scratch );

close $out;

sub get_header_strings{
    my( %vals ) = @_;
    my $type               = $vals{"type"}; 
    my $method             = $vals{method}; 
    my $db_name_stem       = $vals{db_name_stem}; 
    my $projectdir         = $vals{projectdir}; 
    my $use_array          = $vals{use_array}; 
    my $use_scratch        = $vals{use_scratch};
    my $score_threshold    = $vals{score_threshold};
    my $evalue_threshold   = $vals{evalue_threshold};
    my $coverage_threshold = $vals{coverage_threshold};
    my $remote_scripts_dir = $vals{remote_scripts_dir};
			       
    my $string = "";
    if( $type eq "search" ){
	$string   .= join( "\n", "INPATH=\$1", "INPUT_GZ=\$2", "DBPATH=\$3", "OUTPATH=\$4", "OUTSTEM=\$5", "\n" );
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
	    if( $method =~ m/hmm/ ){
		$string .= "DB=" . ${db_name_stem} ."_\${INT_TASK_ID}.hmm\n";
	    } else {
		$string .= "DB=" . ${db_name_stem} ."_\${INT_TASK_ID}.fa\n";
	    }
	    $string .= "OUTPUT=\${OUTSTEM}_" . "\${INT_TASK_ID}" . ".tab\n";
	} else {
	    $string .= "DB=\$6\n";
	    $string .= "OUTPUT=\$OUTSTEM\n";
	}
	#we gunzip before running to deal with those programs that can't read gz files
	#note that could see about setting up gunzip pipes into programs down below..
	$string .= "INPUT=\$(echo \${INPUT_GZ} | sed 's/\.gz//')\n";
    } elsif( $type eq "orfs" ){
	$string   .= join( "\n", "INPATH=\$1", "INSTEM=\$2", "OUTPATH=\$3", "OUTSTEM=\$4", "\n" );
	if( $use_array ){
	    $string   .= join( "\n", "INPUT=\${INSTEM}\${SGE_TASK_ID}.fa.gz", "OUTPUT=\${OUTSTEM}\${SGE_TASK_ID}.fa", "\n" );
	} else {
	    $string   .= join( "\n", "INPUT=\${INSTEM}.fa.gz", "OUTPUT=\${OUTSTEM}.fa", "\n" );
	}
	$string  .= "INT_TASK_ID=\${SGE_TASK_ID}\n"; #this makes log naming consistent across types
	$string  .= "METATRANS=\$(which metatrans.py)\n"; #we need the full path since we must invoke python
    } elsif( $type eq "dbformat" ){
	$string   .= join( "\n", "DBPATH=\$1", "\n" );
	if( $use_array ){
	    $string   .= "DB=" . $db_name_stem . "_\${SGE_TASK_ID}.fa\n";
	} else {
	    $string   .= "DB=\$2\n";
	}	
	$string  .= "INT_TASK_ID=\${SGE_TASK_ID}\n"; #this makes log naming consistent across types
    } elsif( $type eq "parse" ){
	$string   .= join( "\n", "INPATH=\$1", "INPUT=\$2", "OUTPATH=\$3", "OUTSTEM=\$4", "OUTSUFFIX=\$5", "SAMPLE_ID=\$6", "\n" );
	if ($use_array){
	    #if this is a reprocess job, need to map the splits that need to be rerun to array task ids
	    $string .= join( "\n", 
			     "SPLIT_REPROC_STRING=\$7\n",
			     "if [[ \$SPLIT_REPROC_STRING && \${SPLIT_REPROC_STRING-x} ]]",
			     #"if [ -z \"\$SPLIT_REPROC_STRING\" ]\;",
			     "then",
			     "INT_TASK_ID=\$(echo \${SPLIT_REPROC_STRING} | awk -v i=\"\${SGE_TASK_ID}\" \'{split(\$0,array,\",\")} END{ print array[i]}\')",		
			     "else",
			     "INT_TASK_ID=\${SGE_TASK_ID}",
			     "fi",
			     "\n" );	    
	    $string .= "OUTPUT=\${OUTSTEM}_\${INT_TASK_ID}\${OUTSUFFIX}\n"; #OUTPUT is really the result file
	} else {
	    $string .= "OUTPUT=\${OUTSTEM}\${OUTSUFFIX}\n";
	}
	$string .= join( "\n", 
			 "PARSE_RESULTS=" . $remote_scripts_dir . "/parse_results.pl",
			 "SEARCH_METHOD=" . $method,
			 "EVALUE="        . $evalue_threshold,
			 "COVERAGE="      . $coverage_threshold,
			 "SCORE="         . $score_threshold,
			 "\n" );
         #we want old jobs to be wiped in the case that we've run force_parse in the control script
	$string .= join( "\n",
			 "if [ -e \${OUTPATH}/\${OUTPUT}.mysqld ]",
			 "then",
			 "rm  \${OUTPATH}/\${OUTPUT}.mysqld",
			 "fi",
			 "\n" );

    }
    $string .= join( "\n", "PROJDIR=" . $projectdir, "LOGS=\${PROJDIR}/logs", "\n" );
    $string .= get_log_string( $type, $method );
    return $string;
}

sub get_log_string{
    my $type    = shift;
    my $method  = shift;
    my $dirname = $method;
    if( $type eq "parse" ){
	$dirname = "parse_results";
    }
    my $string        = "";
    if( $use_array ){
	$string .= "LOG=\${LOGS}/" . $dirname . "/\${JOB_ID}.\${INT_TASK_ID}.all\n";
    } else{
	$string .= "LOG=\${LOGS}/" . $dirname . "/\${JOB_ID}.all\n";
    }
    return $string;
}

sub get_metadata_strings{
    my $type   = shift;
    my $method = shift;
    my $string = "";
    my $name   = $method;
    if( $type eq "parse" ){
	$name  = "PARSE RESULTS";
    }
    $string   .= join( "\n", 
		       "qstat -f -j \${JOB_ID}                             > \${LOG} 2>&1",
		       "uname -a                                          >> \${LOG} 2>&1",
		       "echo \"****************************\"             >> \${LOG} 2>&1",
		       "echo \"RUNNING " . uc($name) . " WITH \$*\"               >> \${LOG} 2>&1",
		       "echo \"INT_TASK_ID IS \${INT_TASK_ID}\"           >> \${LOG} 2>&1",
		       "date                                              >> \${LOG} 2>&1",
		       "\n" );
    return $string;
}


sub get_scratch_prefix{
    my $type   = shift;
    my $string = "";
    #DO SOME ACTUAL WORK: Clean old files
    if( $type eq "search" || $type eq "dbformat" ){
	$string   .= join( "\n",
			   "files=\$(ls ${scratch_path}/${db_name_stem}* 2> /dev/null | wc -l )  >> \${LOG} 2>&1",
			   "echo \$files                                             >> \${LOG} 2>&1",
			   "if [ \"\$files\" != \"0\" ]; then",
			   "    echo \"Removing cache files\"",
			   "    rm ${scratch_path}/${db_name_stem}*",
			   "else",
			   "    echo \"No cache files...\"",
			   "fi                                                       >> \${LOG} 2>&1",
			   "\n" );
	#Copy files over to the node's scratch dir
	$string   .= join( "\n",
			   "echo \"Copying dbfiles to scratch\"                      >> \${LOG} 2>&1",
			   "\n");
	$string   .= join( "\n",		       
			   "cp -f \${DBPATH}/\${DB}* $scratch_path/                   >> \${LOG} 2>&1",
			   "ls -ltr $scratch_path/\${DB}* >> \${LOG} 2>&1",
			   "gunzip -f $scratch_path/\${DB}*.gz                        >> \${LOG} 2>&1",
			   "\n");
    }
    if( $type eq "parse" || $type eq "search" ){
	$string .= join ( "\n",
			  "files=\$(ls $scratch_path/\${INPUT}* 2> /dev/null | wc -l )     >> \${LOG} 2>&1",
			  "echo \$files                                              >> \${LOG} 2>&1",
			  "if [ \"\$files\" != \"0\" ]; then",
 			  "    echo \"Removing cache files\"",
			  "    rm $scratch_path/\${INSTEM}*",
			  "else",
			  "echo \"No cache files...\"",
			  "fi                                                        >> \${LOG} 2>&1",
			  "\n" );
    }
    if( $type eq "orfs" ){
	$string .= join ( "\n",
			  "files=\$(ls $scratch_path/\${INSTEM}* 2> /dev/null | wc -l )     >> \${LOG} 2>&1",
			  "echo \$files                                              >> \${LOG} 2>&1",
			  "if [ \"\$files\" != \"0\" ]; then",
 			  "    echo \"Removing cache files\"",
			  "    rm $scratch_path/\${INSTEM}*",
			  "else",
			  "echo \"No cache files...\"",
			  "fi                                                        >> \${LOG} 2>&1",
			  "\n" );

    }
    if( $type eq "parse" || $type eq "search" || $type eq "orfs" ){
	$string .= join ( "\n",
			  "files=\$(ls $scratch_path/\${OUTSTEM}* 2> /dev/null | wc -l )     >> \${LOG} 2>&1",
			  "echo \$files                                              >> \${LOG} 2>&1",
			  "if [ \"\$files\" != \"0\" ]; then",
 			  "    echo \"Removing cache files\"",
			  "    rm $scratch_path/\${OUTSTEM}*",
			  "else",
			  "echo \"No cache files...\"",
			  "fi                                                        >> \${LOG} 2>&1",
			  "\n" );
    }
    if( $type eq "orfs" || $type eq "parse" ){
	$string   .= join ("\n", "echo \"Copying input file to scratch\"              >> \${LOG} 2>&1", 
			   "cp -f \${INPATH}/\${INPUT} $scratch_path/\${INPUT}        >> \${LOG} 2>&1",
			   "ls -ltrh $scratch_path/\${INPUT}*                         >> \${LOG} 2>&1",
			   "\n");
    }
    if( $type eq "parse" ){
	#remember, output is really the result file being parsed!
	$string .= "echo \"Copying search result file to scratch\"                   >> \${LOG} 2>&1\n";
	$string .= "cp -f \${OUTPATH}/\${OUTPUT} $scratch_path/                      >> \${LOG} 2>&1\n";
	$string .= "ls -ltrh $scratch_path/\${OUTPUT}*                               >> \${LOG} 2>&1\n";
	
    }
    if( $type eq "search" ){ #metatrans can deal with gz, but not all search algs can, so we have sep blocks
	$string   .= join ("\n", "echo \"Copying input file to scratch\"             >> \${LOG} 2>&1",
			   "cp -f \${INPATH}/\${INPUT}.gz $scratch_path/\${INPUT}.gz  >> \${LOG} 2>&1",
			   "\n");
	$string   .= 	   "gunzip -f $scratch_path/\${INPUT}.gz                      >> \${LOG} 2>&1\n";
    }
    return $string;
}

sub get_cleanup_strings{
    my $type        = shift;
    my $use_scratch = shift;
    my $delete_raw  = shift; #only used during type = parse
    my $string      = "";
    if( $use_scratch ){
       	if( $type eq "search"){
	    $string .= join( "\n",
			     "rm $scratch_path/\${DB}*                              >> \${LOG} 2>&1",
			     "\n" );
	}
	if( $type eq "search" || $type eq "orfs" ){
	    $string .= join( "\n",
			     "echo \"removing non-output files from scratch\" >> \${LOG} 2>&1",
			     "rm $scratch_path/\${INPUT}                            >> \${LOG} 2>&1",
			     "\n" );
	    $string  .= join( "\n",
			      "echo \"moving results to main\"                  >> \${LOG} 2>&1",
			      "mv $scratch_path/\${OUTPUT}* \${OUTPATH}/             >> \${LOG} 2>&1", #e.g., rapsearch generates .m8 and .aln suffixes on $OUTPUT
			      "echo \"moved to main (\${OUTPATH}/\${OUTPUT})\"       >> \${LOG} 2>&1",
			      "date                                             >> \${LOG} 2>&1",
			      "echo \"RUN FINISHED\"                            >> \${LOG} 2>&1",
			      "\n" );	
	}
	if( $type eq "dbformat" ){
	      $string .= join( "\n",
			       "echo \"removing input and dbfiles from scratch\" >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "echo \"moving results to main\"                  >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "gzip $scratch_path/\${DB}*                       >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "mv $scratch_path/\${DB}*.gz \${DBPATH}/          >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",			       
			       "echo \"moved to main (\${DBPATH}/\${DB})\"       >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "rm $scratch_path/\${DB}*                         >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "date                                             >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "echo \"RUN FINISHED\"                            >> \$LOGS/prerapsearch/\${JOB_ID}.\${SGE_TASK_ID}.all 2>&1",
			       "\n" );
	}
	if( $type eq "parse" ){	   
	    $string .= join( "\n",
			     "echo \"removing input and dbfiles from scratch\"    >> \${LOG} 2>&1",			     
			     "rm $scratch_path/\${INPUT}                          >> \${LOG} 2>&1",
			     "echo \"moving results to main\"                     >> \${LOG} 2>&1",			   
			     "echo \"moving parsed results to \${OUTPATH}/\"      >> \${LOG} 2>&1",
			     "mv \${RESULT}.mysqld.gz \${OUTPATH}/                >> \${LOG} 2>&1",
			     "date                                                >> \${LOG} 2>&1",
			     "echo \"RUN FINISHED\"                               >> \${LOG} 2>&1",			     
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
    # notice method specific values invoked below
    my $method       = $vals{"search_method"};
    my $use_scratch  = $vals{"use_scratch"};
    my $compress     = $vals{"compress"};
    my $type         = $vals{"type"};
    my $delete_raw   = $vals{"delete_raw"}; #only for type = parse
    my $string       = "";

    # set up a few universal vars
    my( $query, $db, $out, $cmd );
    if( $use_scratch ){
	$query   = "$scratch_path/\${INPUT}";
	$db      = "$scratch_path/\${DB}";
	$out     = "$scratch_path/\${OUTPUT}";
    } else {
	$query   = "\${INPATH}/\${INPUT}";
	$db      = "\${DBPATH}/\${DB}";
	$out     = "\${OUTPATH}/\${OUTPUT}";
    }    
    if( $type eq "search" ){
	$string .= join( "\n",
			 "ls -ltrh $query >> \${LOG} 2>&1",
			 "ls -ltrh " . $db . "*    >> \${LOG} 2>&1",
			 "\n"
	    );
    }

    $string .= "date  >> \${LOG} 2>&1\n";

    #####
    # PARSE RESULTS
    #####
    if( $type eq "parse" ){
	$cmd = "perl \${PARSE_RESULTS} --results-tab=" . $out . " --orfs-file=" . 
	    $query . " --sample-id=\${SAMPLE_ID} --algo=\${SEARCH_METHOD} " .
	    "--evalue=\${EVALUE} --coverage=\${COVERAGE} --score=\${SCORE}";
    } else {
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
	    $cmd = "python \${METATRANS} -m 6FT " . $query . " " . $out;	
	} elsif( $method eq "6FT_split" ){
	    my $length_cutoff = $vals{"metatrans_len_cutoff"};
	    $cmd = "python \${METATRANS} -m 6FT-split -l " . $length_cutoff . " " . $query . " " . $out;
	} elsif( $method eq "prodigal" ){
	    $cmd = "python \${METATRANS} -m Prodigal " . $query . " " . $out;
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
	}  
	else {
	    die( "I don't know how to build submission scripts for the search method $method\n" );
	} 
    }
    #print the command
    $string .= "echo \"" . $cmd . "\" >> \${LOG} 2>&1\n";
    #execute the command
    $string .= $cmd . ">> \${LOG} 2>&1\n";
    #quick check of results
    if( $type ne "parse" ){
	$string .= "ls -ltrh " . $out . "* >> \${LOG} 2>&1\n"; 
    } else {
	$string .= "RESULT=\$( echo " . $out . " | sed 's/\.gz\$//' )     >> \${LOG} 2>&1\n";
	$string .= "ls -ltrh \${RESULT}.mysqld* >> \${LOG} 2>&1\n"; 
    }
    #should we compress?
    if( $compress ){
	#we have to check file before zipping, in case we are removing raw
	if( $type ne "parse" ){ 
		$string .= "echo \"gzip " . $out . "*\" >> \${LOG} 2>&1\n";
		$string .= "gzip " . $out . "* >> \${LOG} 2>&1\n";
	} else {
	    if( $delete_raw ){
		# only delete the raw results if we successfully parsed data. else, we want to be able to try reparse
		# -s means "file is non-zero size"",
		$string .= join( "\n",	     
				 "if [ -s " . $out . " ]",
				 "then",
				 "gzip \${RESULT}.mysqld                               >> \${LOG} 2>&1",
				 "rm \${OUTPATH}/\${OUTPUT}                            >> \${LOG} 2>&1",
				 "fi",
				 "\n");
	    } else {
		$string .= "echo \"gzip \${RESULT}.mysqld\" >> \${LOG} 2>&1\n";
		$string .= "gzip \${RESULT}.mysqld          >> \${LOG} 2>&1\n";
	    }
	}
    }
    $string .= "date  >> \${LOG} 2>&1\n";
    return $string;
}

