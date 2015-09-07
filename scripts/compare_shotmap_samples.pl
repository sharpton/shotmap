#!/usr/bin/perl -w

use lib ($ENV{'SHOTMAP_LOCAL'} . "/scripts"); ## Allows shotmap scripts to be found in the SHOTMAP_LOCAL directory
use lib ($ENV{'SHOTMAP_LOCAL'} . "/lib"); ## Allows "Shotmap.pm and Schema.pm" to be found in the SHOTMAP_LOCAL directory. DB.pm needs this.
use lib ($ENV{'SHOTMAP_LOCAL'} . "/ext/lib/perl5");     

use strict;
use Getopt::Long;
use File::Spec;
use File::Basename; 

use Benchmark;
use Carp;

use Data::Dumper;

$SIG{ __DIE__ } = sub { Carp::confess( @_ ) }; # prints a STACK TRACE whenever there is a fatal error! Very handy

#update $PATH to place shotmap installed binaries at the front. This can be turned off or amended per user needs
local $ENV{'PATH'} = $ENV{'SHOTMAP_LOCAL'} . "/bin/" . ":" . $ENV{'PATH'};
my $r_lib = File::Spec->catdir( $ENV{'SHOTMAP_LOCAL'}, "ext", "R" );

print STDERR ">> ARGUMENTS TO compare_shotmap_samples.pl: perl compare_shotmap_samples.pl @ARGV\n";

my( $input, $datatype, $metadata, $output, $cat_fields_file, $filtered_hits );
GetOptions(
    "input|i=s"           => \$input,
    "datatype|d=s"        => \$datatype,
    "metadata|m:s"        => \$metadata, #optional, include more categories, restrict samples
    "output|o=s"          => \$output,
    "cat-fields-file|c:s" => \$cat_fields_file, #a list of categorical metadata fields
    "filtered-hits!"      => \$filtered_hits,
    );

#validate input variables
my $vals = _validate_inputs( "input"      => $input, 
			     "datatype"   => $datatype,
			     "metadata"   => $metadata, 
			     "output"     => $output,
			     "cat-fields-file" => $cat_fields_file,
			     "filtered-hits"   => $filtered_hits,
    );

#create output and tmp directories
mkdir( $output );
my $tmp = $output . "/_tmp/";
mkdir( $tmp );
my $abund_dir = $output . "/Abundances/";
mkdir( $abund_dir );

#put symlinked output files in tmp
print( "Obtaining ShotMAP $datatype and metadata result files...\n" );
_link_input_files( $vals->{"input"}, $vals->{"in_type"}, $vals->{"filtered-hits"}, $tmp );

#do we need to get metadata table?
print( "Producing merged metadata file...\n" );
my $merged_metadata = File::Spec->catfile( $output, "Merged_Metadata.tab" );
_merge_metadata( $merged_metadata, $tmp, $metadata );
_check_metadata( $merged_metadata, "xls" );
print( "Created merged metadata file here: $merged_metadata\n" );

#build merged data tables
my $merge_script = $ENV{'SHOTMAP_LOCAL'} . "/scripts/external/merge_abundance_tables_across_projects.R";
print "R --slave --args ${tmp} ${merged_metadata} ${abund_dir} ${r_lib} < $merge_script\n";
system( "R --slave --args ${tmp} ${merged_metadata} ${abund_dir} ${r_lib} < $merge_script" );

#run statistical tests using shotmap.R
my $stats_script = $ENV{'SHOTMAP_LOCAL'} . "/scripts/R/compare_shotmap_results.R";
my $stats_file;
if( $datatype eq "abundances" ){
    $stats_file = "${abund_dir}/Merged_Abundances.tab";
} elsif( $datatype eq "relative-abundances" ){
    $stats_file = "${abund_dir}/Merged_Relative_abundances.tab";
} elsif( $datatype eq "counts" ){
    $stats_file = "${abund_dir}/Merged_Counts.tab";
}
#integrate cat_fields_file into this command
if( ! defined( $cat_fields_file ) ){
    $cat_fields_file = "NULL";
}
print "R --slave --args ${stats_file} ${merged_metadata} ${output} ${cat_fields_file} ${r_lib} < $stats_script\n";
system( "R --slave --args ${stats_file} ${merged_metadata} ${output} ${cat_fields_file} ${r_lib} < $stats_script" );

###############
# SUBROUTINES #
###############

sub _link_input_files{
    my( $input, $in_type, $filtered, $tmp ) = @_;
    if( $in_type eq "dir" ){
	#get all of the sample abundance files in the dir
	_link_from_ffdb( $input, $tmp, $filtered, "Abundances" );
	_link_from_ffdb( $input, $tmp, $filtered, "Metadata" );
    } elsif( $in_type eq "file" ){
	#get all of the sample abundance files in all of the dirs
	open( FILE, $input ) || die "Can't open $input for read: $!\n";
	while( <FILE> ){
	    chomp $_;
	    my $path = $_;
	    _link_from_ffdb( $path, $tmp, $filtered, "Abundances" );
	    _link_from_ffdb( $path, $tmp, $filtered, "Metadata" );
	}
    }
    return;
}

sub _get_proj_name_from_path{
    my $path = shift;
    my $proj_name = basename( $path );
    return $proj_name;
}

#type = Abundances, Metadata, Classification_Maps
sub _link_from_ffdb{
    my( $path, $tmp, $filtered, $type ) = @_;
    my $output_path;
    if( $filtered ){
	if( $type eq "Classification_Maps" ){
	    $output_path   = $path . "/output/${type}_Filtered_Mammal/";
	} else {
	    $output_path   = $path . "/output/${type}_Filtered/";
	}
    } else {
	$output_path   = $path . "/output/${type}/";
    }
    if( ! -d $output_path ){
	die( "Can't locate $output_path. Are you certain that you are pointing --input ". 
	     "to the top level of the shotmap flat file database? Are you certain that " .
	     "the samples processed in this flat file database ran to completion?" );
    }
    opendir( DIR, $output_path ) || die "Can't open $output_path for read: $!\n";
    my @files = readdir( DIR );
    closedir( DIR );
    foreach my $file( @files ){
	my $filepath = File::Spec->catfile( $output_path, $file );
	if( $type eq "Abundances" ){
	    next unless( $file =~ m/Data_Frame/ );
	    _link_file( $filepath, $tmp );
	} elsif( $type eq "Metadata" ){
	    next unless( $file =~ m/Metadata/ );
	    #Metadata files don't have sample names in them, (multiple samples per)
	    #so we copy to keep from overwriting in the tmp directory
	    my $proj_name = _get_proj_name_from_path( $path );
	    my $out = File::Spec->catfile( $tmp, $file . "_${proj_name}" );
	    _cp_file( $filepath, $out );
	} elsif( $type eq "Classification_Maps" ){
	    next unless( $file =~ m/Classification/ );	    
	    _link_file( $filepath, $tmp );
	} else {
	    die( "An improper option (type) was passed to _link_from_ffdb\n" );
	}
    }
    return;
}

sub _cp_file{
    my( $file, $out ) = @_;
    system( "cp $file $out" );
}

sub _link_file{
    my( $file, $dir ) = @_;
    my $pwd = $ENV{'PWD'}; 
    system( "ln -s ${pwd}/${file} $dir" );
}

sub _validate_inputs{
    my %vals = @_;
    my $input      = _validate_var( "input",    $vals{"input"}    );
    my $datatype   = _validate_var( "datatype", $vals{"datatype"} );
    my $metadata   = _validate_var( "metadata", $vals{"metadata"} );
    my $output     = _validate_var( "output",   $vals{"output"}   );   
    my $cat_fields    = _validate_var( "cat-fields-file", $vals{"cat_fields"} );
    my $filtered_hits = _validate_var( "filtered-hits", $vals{"filtered_hits"} );
    my $in_type    = _check_input( $input );
    $vals{"in_type"} = $in_type;
    return \%vals;
}

sub _validate_var{
    my $type = shift;
    my $var  = shift;
    #these are optional command line inputs:
    unless( $type eq "metadata" || 
	    $type eq "cat-fields-file" ||
	    $type eq "filtered-hits"
	){
	if( !defined( $var ) ){
	    die( "You did not specify a value for --${type}. Exiting." );
	}
    }
    #check each var type. Note that we handle input in its own subroutine
    if( $type eq "datatype" ){
	if( $var ne "abundances" &&
	    $var ne "relative-abundances" &&
	    $var ne "counts" ){
	    die( "The value for option --${type} must be one of the following:\n" .
		 "abundances\n" .
		 "relative-abundances" .
		 "counts" .
		 "You specified $var. Exiting"
		);
	}
    }
    if( $type eq "output" ){
	if( -d $var ){
	    die( "The specified output directory exists. I will not overwrite! You specified:\n" .
		 "${var}\n" .
		 "Exiting." 
		);
	} 
    }
    if( $type eq "metadata" && defined( $var) ){
	if(  ! -e $var ){
	    die( "The specified metadata file does not exist. You specified:\n" .
		 "${var}\n" .
		 "Exiting." 
		);
	}
	_check_metadata( $var, "xls" );
    }
    if( $type eq "cat-fileds-file" ){
	if( ! -e $var ){
	    die( "The specified cat-fields-file does not exist. You specified:\n" .
		 "${var}\n" .
		 "Exiting." 
		);
	}
    }
    if( $type eq "filtered" ){
	if( $var ){
	    print "Grabbing filtered hits results since --filtered-hits is set\n";
	}
    }
    return $var;
}

sub _check_input{
    my $input = shift;
    my $in_type;
    if( -d $input ){
	$in_type = "dir";
    }
    elsif( -f $input ){
	$in_type = "file";
	open( IN, $input ) || die "Can't open $input for read: $!\n";
	while( <IN> ){
	    my $dir = $_;
	    chomp $dir;
	    if( ! -d $dir ){
		die( "The specified input $input contains items that are not directories. For example,\n".
		     "$dir\n" .
		     "is not a directory that exists on your system. Please ensure that only directories that " .
		     "exist on your system are included in your input file\n" 
		    );
	    }
	}	
	close IN;
    } else {
	die( "I cannot determine what to do with your input file:\n" .
	     "$input\n" .
	     "Please either point --input to a shotmap_ffdb output directory or a file that contains a list of such directories"
	    );
    }    
    return $in_type;
}

#fmt is either "R", with row identifiers, or "xls" with no row identifiers
sub _check_metadata{
    my ( $file, $fmt ) = @_;
    if( ! -e $file ){
	die( "The metadata file $file does not exist!\n" );
    }
    open( FILE, $file ) || die "Can't open metadata file $file for read: $!\n";
    my $head = <FILE>;
    if( $head !~ m/^Sample\.Name/ ){
	die( "The metadata file $file does not seem to be properly formatted. " .
	     "Please ensure you have a tab-delimited file that contains a header " .
	     "row which starts with the field Sample.Name. I got:\n" .
	     $head
	    );
    }
    my @data = split( ' ', $head );
    my $ncol = scalar( @data );
    while( <FILE> ){
	chomp $_;
	my @data       = split(' ', $_ );
	my $row_ncol   = scalar( @data );
	
	if( ( $fmt eq "xls" && $row_ncol != $ncol ) || 
	    ( $fmt eq "R"   && $row_ncol != ( $ncol + 1 ) ) 
	    ) {
	    my $sample_id = $data[0];
	    die( "The metadata file $file contains an error: The row for sample " .
		 "$sample_id does not contain the same number of tab-delimited columns " .
		 "as the header row in the file. This row has $row_ncol and the header " .
		 "has $ncol\n" 
		);
	}
    }
    close FILE;
}

sub _merge_metadata{
    my( $outtable, $indir, $external_metadata ) = @_;
    #create a hashref that logs all metadata across all samples
    my $data;
    #process all of the tmp dir files
    opendir( IN, $indir );
    while( my $file = readdir( IN ) ){
	next if ( $file !~ m/Metadata/ );
	_check_metadata( File::Spec->catfile( $indir, $file ), "R" );
	$data = _parse_metadata( File::Spec->catfile( $indir, $file ) , $data, "raw", "R" );
    }
    closedir( IN );
    #process the external_metadata file. it's already been checked
    if( defined( $external_metadata ) ){
	$data = _parse_metadata( $external_metadata, $data, "external", "xls" );
    }
    #produce the output from $data using $external_metadata as a guide
    _print_metadata( $data, $outtable );
}

sub _parse_metadata{
    my( $metadata, $data, $type, $fmt ) = @_;
    open( META, $metadata ) || die "Can't open $metadata for read";
    my $header = <META>;
    chomp $header;
    my @cols   = split( ' ', $header );
    #add col names to data for logging across files
    $data = _add_fields( $data, \@cols );
    #now get the data for each sample
    while( <META> ){
	chomp $_;
	my @vals = split( ' ', $_ );
	if( $type eq "raw" ){
	    if( $fmt eq "xls" ){
		my $sample = $vals[0];
		for( my $i=1; $i<scalar(@cols); $i++ ){
		    $data->{"raw"}->{$sample}->{$cols[$i]} = $vals[$i];
		}
	    } elsif( $fmt eq "R" ){
		my $sample = $vals[1];
		for( my $i=2; $i<scalar(@cols+1); $i++ ){
		    $data->{"raw"}->{$sample}->{$cols[$i-1]} = $vals[$i];
		}		
	    } else {
		die( "I don't know what to do with the fmt value $fmt in _parse_metadata\n");
	    }
	} elsif( $type eq "external" ){
	    my $sample = $vals[0];
	    for( my $i=1; $i<scalar(@cols); $i++ ){
		$data->{"external"}->{$sample}->{$cols[$i]} = $vals[$i];
	    }
	} else {
	    die( "I don't understand the value (${type}) passed to parameter type in _parse_metadata\n" );
	}
    }
    close META;
    return $data;
}

sub _add_fields{
    my( $data, $ra_cols ) = @_;
    foreach my $col( @{ $ra_cols } ){
	next if( $col eq "Sample.Name" );
	$data->{"fields"}->{$col}++;
    }
    return $data;
}

sub _print_metadata{
    my( $data, $outtable ) = @_;
    open( OUT, ">$outtable" ) || die "Can't open $outtable for write:\n";
    my $count = 0;
    my @fields = keys( %{ $data->{"fields"} } );
    #print join ( "\n", @fields, "\n" );
    my @samples = ();
    if( defined( $data->{"external"} ) ){
	@samples = keys( %{ $data->{"external"} } );
    } else {
	@samples = keys( %{ $data->{"raw"} } );
    }
    foreach my $sample( @samples ) {
	if( $count == 0 ){
	    print OUT join( "\t", "Sample.Name", @fields) . "\n";
	}
	print OUT $sample . "\t";
	for( my $i=0; $i<scalar(@fields); $i++ ){
	    my $field = $fields[$i];
	    my $val   = "NA"; #we use this for R compatibility, assume by default
	    if( defined( $data->{"raw"}->{$sample}->{$field} ) ){
		$val = $data->{"raw"}->{$sample}->{$field};
	    } elsif( defined( $data->{"external"}->{$sample}->{$field} ) ){
		$val = $data->{"external"}->{$sample}->{$field};
	    }
	    unless( $i == ( scalar(@fields) - 1 ) ){
		print OUT $val . "\t";
	    } else {
		print OUT $val . "\n";
	    }
	}
	$count++;
    }
    close OUT;
}
