#!/usr/bin/perl -w

use strict;
use warnings;
use Getopt::Long;

#if there are extra characters in the header, such as a description, we don't want them when we modify the sequence id
sub get_header_part_before_whitespace($) {
    my ($header) = @_;
    if($header =~ m/^(.*?)\s/){
	return($1); # looks like we only want... the part BEFORE the space?
    } else {
	return $header; # unmodified header is just fine, thank you
    }
}



my( $inseqs, $outseqs );
my $seq_len_min = 0; #in AA length, filter is inclusive; 
GetOptions(
    "i=s" => \$inseqs,
    "o=s" => \$outseqs,
    "l=i" => \$seq_len_min,
    );

open( IN,  $inseqs )     || die "Can't open $inseqs for read: $!\n";
open( OUT, ">$outseqs" ) || die "Can't open $outseqs for write: $!\n";
my $out = *OUT;
my $infile = 0;
my $header = ();
my $seq    = ();
while( <IN> ){
    chomp $_;
    if( $_ =~ m/\>/ ){
	if($infile) {
	    process_seq( $header, $seq, $seq_len_min, $out );
	    $header = get_header_part_before_whitespace($_);
	    $seq    = ();
	} else{
	    $header = get_header_part_before_whitespace($_);
	    $infile = 1;
	}
    }
    else{
	$seq = $seq . $_;
    }
}
close IN;
close OUT;


sub process_seq{
    my( $header, $sequence, $seq_len_min, $out) = @_;
    my $count = 1;
    if ($sequence =~ m/\*/){ # we are looking for literal asterisks
	my @allSeqs  = split( "\\*", $sequence ); # split on asterisks
	foreach my $seq(@allSeqs){
	    if(length($seq) <= $seq_len_min){
		next; # guess it's too short
	    }
	    my $id = "${header}_${count}"; # looks like we have the original header line plus a count
	    print $out "$id\n$seq\n";
	    $count++; # hmm. Increment count here.
	}
    } else{
	#no stops (no asterisks??), but still want consistant format
	my $id = "${header}_${count}"; # looks like we have the original header line plus a count
	print $out "$id\n$sequence\n";       
    }
}
