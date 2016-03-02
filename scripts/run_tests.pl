#!/usr/bin/perl -w

use strict;
use File::Spec;

my $output = $ARGV[0];

if( ! -d $output ) {
    `mkdir -p $output`;
}

my $master = $ENV{'SHOTMAP_LOCAL'};
my $data   = File::Spec->catdir( $master, "data" );
my $t_fams = File::Spec->catdir( $data, "quick_test", "test_family_database" );
my $s_fams = File::Spec->catdir( $data, "sfams_v0_slim" );
my $t_data = File::Spec->catdir( $data, "quick_test", "testdata" );

##FAST
#test building a search database
my $t_fam_db = File::Spec->catdir( $output, "test_family_smdb" );
my $cmd1 = "perl ${master}/scripts/build_shotmap_searchdb.pl -r $t_fams -d $t_fam_db --force-searchdb --verbose" ;
print $cmd1 . "\n";
`$cmd1`;
#test shotmap on a single, specified sample, w/in sample ffdb
my $stem   = "sample_1.fa";
my $sample = File::Spec->catfile( $t_data, $stem );
`cp $sample $output`;
my $cmd2 = "perl ${master}/scripts/shotmap.pl -i ${output}/${stem} -d $t_fam_db --ags-method=none --clobber --verbose";
print $cmd2 . "\n";
`$cmd2`;
#test shotmap on a single, specified sample, distinct ffdb
my $out3 = File::Spec->catdir( $output, $stem . "_sm_ffdb");
my $cmd3 = "perl ${master}/scripts/shotmap.pl -i $sample -d $t_fam_db -o $out3 --ags-method=none --clobber --verbose";
print $cmd3 . "\n";
`$cmd3`;
#test shotmap on a directory of samples, w/in sample ffdb
my $dir_stem = "testdata";
my $samp_dir = File::Spec->catdir( $output, $dir_stem );
`cp $t_data $samp_dir`;
my $cmd4 = "perl ${master}/scripts/shotmap.pl -i $samp_dir -d $t_fam_db --ags-method=none --clobber --verbose";
print $cmd4 . "\n";
`$cmd4`;
#test shotmap on a directory of samples, distinct ffdb
my $out5 = File::Spec->catdir( $output, $dir_stem . "_sm_ffdb");
my $cmd5 = "perl ${master}/scripts/shotmap.pl -i $samp_dir -d $t_fam_db -o $out5 --ags-method=none --clobber --verbose";
print $cmd5 . "\n";
`$cmd5`;
##################
# ADD TESTS HERE
