#!/usr/bin/perl -w 

use strict;
use Getopt::Long;

#parse_results.pl - Parses sequence search result files and produces mysql data tables for bulk loading. Is run on remote server and called by run_parse_results.sh 

print "parse_results.pl @ARGV";

my ( $results_tab, $query_orfs_file,
     $sample_id,   $algo,            $trans_method,
     $t_evalue,    $t_coverage,      $t_score, 
    );

my $parse_type = "best_hit"; #use this to save space. Will still have to look across searchdb splits for top hit.

GetOptions(
    "results-tab=s"  => \$results_tab,
    "orfs-file=s"    => \$query_orfs_file,
    "sample-id=i"    => \$sample_id,
#    "class-id=i"     => \$classification_id,
    "algo=s"         => \$algo,
    "trans-method=s" => \$trans_method,
    "evalue=s"       => \$t_evalue,     #thresholds might be float, might be "NULL" via bash. if float, perl will coerse from string
    "coverage=s"     => \$t_coverage,
    "score=s"        => \$t_score,
    "parse-type=s"   => \$parse_type, #what results should we store? 'best_hit' (per read), 'best_per_fam' (per read), 'all' (above thresholds)
    );

if( $t_evalue eq "NULL" && $t_coverage eq "NULL" && $t_score eq "NULL" ){
    warn( "You haven't defined any threshold settings (e.g., evalue, coverage, score), so I will parse ALL search results data. I recommend using at least a permissive "
	  . "score threshold reduce the amount of data that you insert into the database. You can set thesholds by calling this script with any of the following: "
	  . "--evalue --coverage --score\n" );
}
if( $t_coverage eq "NULL" ){
    $t_coverage = undef;
}
if( $t_evalue eq "NULL" ){
    $t_evalue = undef;
}
if( $t_score  eq "NULL" ){
    $t_score = undef;
}

#blast, last, rapsearch don't have sequence lengths in table, so we have to look them up for coverage calculation.
#if we wanted to calculate target coverage, we could do something similar using the db split file
my %seqlens    = ();
if( $algo eq "blast" || $algo eq "last" || $algo eq "rapsearch" ){
    %seqlens   = %{ get_sequence_lengths_from_file( $query_orfs_file ) };
}

my $hitmap = {};

open( RES, "$results_tab" ) || die "can't open $results_tab for read: $!\n";    
my $output = $results_tab . ".mysqld";
open( OUT, ">$output" ) || die "Can't open $output for write: $!\n";
while(<RES>){
    chomp $_;
    if( $_ =~ m/^\#/ || $_ =~ m/^$/) {
	next; # skip comments (lines starting with a '#') and completely-blank lines
    }
    my($qid, $qlen, $tid, $tlen, $evalue, $score, $start, $stop);
    if( $algo eq "hmmscan" ){
	my @data = split( ' ', $_ );
	$qid    = $data[3];
	$qlen   = $data[5];
	$tid    = $data[0];
	$tlen   = $data[2];
	$evalue = $data[12]; #this is dom_ievalue
	$score  = $data[7];  #this is dom score
	$start  = $data[19]; #this is env_start
	$stop   = $data[20]; #this is env_stop
    }    
    if ( $algo eq "hmmsearch" ){
	#regex is ugly, but very fast
	if( $_ =~ m/(.*?)\s+(.*?)\s+(\d+?)\s+(\d+?)\s+(.*?)\s+(\d+?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s(.*)/ ){
	    $qid    = $1;
	    $qlen   = $3;
	    $tid    = $4;
	    $tlen   = $6;
	    $evalue = $13; #this is dom_ievalue
	    $score  = $8;  #this is dom score
	    $start  = $20; #this is env_start
	    $stop   = $21; #this is env_stop
	} else{
	    warn( "couldn't parse results from $algo file:\n$_ ");
	    next;
	}
    }
    if( $algo eq "blast" || $algo eq "rapsearch" ){
	if( $_ =~ m/^(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)$/ ){
	    $qid    = $1;
	    $tid    = $2;
	    $start  = $9; 
	    $stop   = $10; 
	    $evalue = $11; 
	    $score  = $12;
	    $qlen   = $seqlens{$qid};	    
	} else{
	    warn( "couldn't parse results from $algo file:\n$_ ");
	    next;
	}
    }
    if ($algo eq "last") {
	if($_ =~ m/^(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)\s+(.*?)$/ ){
	    $score  = $1;
	    $tid    = $2;
	    $qid    = $7;
	    $start  = $8;
	    $stop   = $start + $9;
	    $qlen   = $11;
	    $evalue = 0; #hacky - no evalue reported for last, but want to use the same code below
	} else {
	    warn( "couldn't parse results from $algo file:\n$_ ");
	    next;
	}
    }
    my $famid;
    if( $algo eq "blast" || $algo eq "last" || $algo eq "rapsearch"){
	$famid = parse_famid_from_ffdb_seqid( $tid );
    } else{
	$famid = $tid;
    }	    
    #depending on parse_type, do we need to retain this result?
    if( $parse_type eq 'best_hit' ){
	next unless $hitmap->{$qid}->{"topscore"} < $score;
    } elsif( $parse_type eq 'best_per_fam' ){
	next unless $hitmap->{$qid}->{$famid}->{"topscore"} < $score;
    } elsif( $parse_type eq 'all' ){
	#do nothing
    }
    #calculate coverage from query perspective
    if( !defined( $qlen ) ){
	die( "Can't calculate the query sequence length for ${qid} using orf_file ${query_orfs_file}\n" );
    }
    my ( $aln_len, $coverage );
    if ($stop > $start) {
	$aln_len  = $stop - $start + 1; # <-- coverage calc must include ****first base!*****, so add one
    } elsif ($stop < $start) {
	$aln_len  = $start - $stop + 1;
    } elsif ($stop == $start) {
	$aln_len  = 0;
    }
    $coverage = $aln_len / $qlen; # <-- coverage calc must include ****first base!*****, so add one	
    #do we pass the defined thresholds?
    if( defined( $t_score ) ){
	next unless $score >= $t_score;
    }
    if( defined( $t_evalue ) ){
	next unless $evalue <= $t_evalue;
    }
    if( defined( $t_coverage ) ){
	next unless $coverage >= $t_coverage;
    }
    my $read_alt_id = parse_orf_id( $qid, $trans_method );
#print mysql data row to file
    my @fields = ( $qid, $read_alt_id, $sample_id, $tid, $famid, $score, $evalue, $coverage, $aln_len );
    my $row    = join( ",", @fields, "\n" );
    $row       =~ s/\,$//;
    if( $parse_type eq 'all' ){
	print OUT $row;
    } else {
	if( $parse_type eq 'best_hit' ){
	    $hitmap->{$qid}->{"topscore"} = $score;
	    $hitmap->{$qid}->{"data"}     = $row;
	} elsif( $parse_type eq 'best_per_family' ){
	    $hitmap->{$qid}->{$famid}->{"topscore"} = $score;
	    $hitmap->{$qid}->{$famid}->{"data"}     = $row;
	}	
    }
}
#need to print the data if the parse types were not 'all'
if( $parse_type eq 'best_hit' ){
    foreach my $qid( keys( %{ $hitmap } ) ){
	my $row = $hitmap->{$qid}->{"data"};
	print OUT $row;
    }
} 
elsif( $parse_type eq 'best_per_family' ){
    foreach my $qid( keys( %{ $hitmap } ) ){
	foreach my $famid( keys( %{ $hitmap->{$qid} } ) ){
	    	my $row = $hitmap->{$qid}->{$famid}->{"data"};
		print OUT $row;
	}
    }
}

close OUT;

#DONE.

    
sub parse_orf_id{
    my $orfid  = shift;
    my $method = shift;
    my $read_id = ();
    if( $method eq "transeq" ){
	if( $orfid =~ m/^(.*?)\_\d$/ ){
	    $read_id = $1;
	}
	else{
	    die "Can't parse read_id from $orfid\n";
	}
    }
    if( $method eq "transeq_split" ){
	if( $orfid =~ m/^(.*?)\_\d_\d+$/ ){
	    $read_id = $1;
	}
	else{
	    die "Can't parse read_id from $orfid\n";
	}
    }
    return $read_id;
}


sub get_sequence_lengths_from_file{
    my( $file ) = shift;    
    my %seqlens = ();
    open( FILE, "$file" ) || die "Can't open $file for read: $!\n";
    my($header, $sequence);
    while(<FILE>){
	chomp $_;
	if (eof) { # this is the last line I guess
	    $sequence .= $_; # append to the sequence
	    $seqlens{$header} = length($sequence);
	}

	if( $_ =~ m/\>(.*)/ ){
	    # Starts with a '>' so this is a header line!
	    if (defined($header)) { # <-- process the PREVIOUSLY READ sequence, which we have now completed
		$seqlens{$header} = length($sequence);
	    }
	    $header   = $1; # save the header apparently...
	    $sequence = ""; # sequence is just plain nothing at this point
	} else {
	    $sequence .= $_;
	}
    }
    return \%seqlens;
}

sub parse_famid_from_ffdb_seqid {
    my $hit = shift;
    my $famid;
    if( $hit =~ m/^(.*?)\_(\d+)$/ ){
	$famid = $2;
    }
    else{
	warn( "Can't parse famid from $hit in _parse_famid_from_ffdb_seqid!\n" );
	die;
    }
    return $famid;
}

