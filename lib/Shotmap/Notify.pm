#!/usr/bin/perl -w

#MRC.pm - The MRC workflow manager
#Copyright (C) 2011  Thomas J. Sharpton 
#author contact: thomas.sharpton@gladstone.ucsf.edu
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program (see LICENSE.txt).  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

package Shotmap::Notify;

use Shotmap;
use IPC::System::Simple qw(capture $EXITVAL);

my $USE_COLORS_CONSTANT = 1; ## Set this to '0' to avoid printing colored output to the terminal, or '1' to print colored output.

sub tryToLoadModule($) {
    # Tries to load a module. Returns a true value (1) if it succeeds. Otherwise, returns a false value (0).
    my $x = eval("require $_[0]");
    if ((defined($@) && $@)) {
	warn "Module loading of $_[0] FAILED. Skipping this module.";
	return 0;
    } else {
	$_[0]->import();
	return 1;
    }
}

if (!tryToLoadModule("Term::ANSIColor")) {
    $USE_COLORS_CONSTANT = 0; # Failed to load the ANSI color terminal, so don't use colors! Not sure how reliable this actually is.
}

sub safeColor($;$) { # one required and one optional argument
    ## Prints colored text, but only if USER_COLORS_CONSTANT is set.
    ## Allows you to totally disable colored printing by just changing USE_COLORS_CONSTANT to 0 at the top of this file
    my ($str, $color) = @_;
    return (($USE_COLORS_CONSTANT) ? Term::ANSIColor::colored($str, $color) : $str);
}

sub dryNotify { # one optional argument
    my ($self, $msg) = @_;
    $msg = (defined($msg)) ? $msg : "This was only a dry run, so we skipped executing a command.";
    chomp($msg);
    print STDERR safeColor("[DRY RUN]: $msg\n", "black on_magenta");
}

sub notifyAboutScp {
    my ($self, $msg) = @_;
    chomp($msg);
    my $parentFunction = defined((caller(2))[3]) ? (caller(2))[3] : '';
    print STDERR (safeColor("[SCP]: $parentFunction: $msg\n", "green on_black")); ## different colors from normal notification message
    # no point in printing the line number for an SCP command, as they all are executed from Run.pm anyway
}

sub notifyAboutRemoteCmd{
    my ($self, $msg) = @_;
    chomp($msg);
    my $parentFunction = defined((caller(2))[3]) ? (caller(2))[3] : '';
    print STDERR (safeColor("[REMOTE CMD]: $parentFunction: $msg\n", "black on_green")); 
    ## different colors from normal notification message
    # no point in printing the line number for a remote command, as they all are executed from Run.pm anyway
}

sub notify {
    my ($self, $msg) = @_;
    chomp($msg);
    print STDERR (safeColor("[NOTE]: $msg\n", "cyan on_black"));
}

sub dieWithUsageError {
    my ($self, $msg) = @_;
    chomp($msg);
    print("[TERMINATED DUE TO USAGE ERROR]: " . $msg . "\n");
    print STDOUT <DATA>;
    die(MRC::safeColor("[TERMINATED DUE TO USAGE ERROR]: " . $msg . " ", "yellow on_red"));
}

sub exec_and_die_on_nonzero {
    my ( $cmd ) = @_;
    my $results = IPC::System::Simple::capture($cmd);
    (0 == $EXITVAL) or die "Error:  non-zero exit value: $results";
    return($results);
}

sub pipeline_params{
    my ( $self ) = @_;

    $self->Shotmap::Notify::notify("Starting a classification run using the following settings:\n");
    ($self->remote)                      && $self->Shotmap::Notify::notify("   * Use the remote server <" . $self->remote_host . ">\n");
    if( defined( $self->db_host ) ){        $self->Shotmap::Notify::notify("   * Database host: <"        . $self->db_host     . ">\n") };
    if( defined( $self->db_name  ) ){       $self->Shotmap::Notify::notify("   * Database name: <"        . $self->db_name     . ">\n") };
    ($self->use_search_alg("last"))      && $self->Shotmap::Notify::notify("   * Algorithm: last\n");
    ($self->use_search_alg("blast"))     && $self->Shotmap::Notify::notify("   * Algorithm: blast\n");
    ($self->use_search_alg("hmmscan"))   && $self->Shotmap::Notify::notify("   * Algorithm: hmmscan\n");
    ($self->use_search_alg("hmmsearch")) && $self->Shotmap::Notify::notify("   * Algorithm: hmmsearch\n");
    ($self->use_search_alg("rapsearch")) && $self->Shotmap::Notify::notify("   * Algorithm: rapsearch\n");
    ($self->stage)                       && $self->Shotmap::Notify::notify("   * Staging: Will copy the search databaase to " . $self->remote_host    . "\n");
    if( defined( $self->class_evalue )   ){ $self->Shotmap::Notify::notify("   * Evalue threshold: "          . $self->class_evalue   . "\n") };
    if( defined( $self->class_coverage ) ){ $self->Shotmap::Notify::notify("   * Coverage threshold: "        . $self->class_coverage . "\n") };
    if( defined( $self->class_score )    ){ $self->Shotmap::Notify::notify("   * Score threshold: "           . $self->class_score    . "\n") };

    return $self;
}

sub printBanner($$) {
    my ($self, $string) = @_;
    my $dateStr = `date`;
    chomp($string); # remove any ending-of-string newline that might be there
    chomp($dateStr); # remote always-there newline from the `date` command
    my $stringWithDate = $string . " ($dateStr)";
    my $pad  = "#" x (length($stringWithDate) + 4); # add four to account for extra # and whitespce on either side of string
    print STDERR MRC::safeColor("$pad\n" . "# " . $stringWithDate . " #\n" . "$pad\n", "cyan on_blue");
}

sub check_env_var{
    my ( $self, $env ) = @_;
    if (!defined( $env )) {
	print STDOUT ("[ERROR]: The MRC_LOCAL environment variable was NOT EXPORTED and is UNDEFINED.\n");
	print STDOUT ("[ERROR]: MRC_LOCAL needs to be defined as the local code directory where the MRC files are located.\n");
	print STDOUT ("[ERROR]: This is where you'll do the github checkout, if you haven't already.\n");
	print STDOUT ("[ERROR]: I recommend setting it to a location in your home directory. Example: export MRC_LOCAL='/some/location/MRC'\n");
	die "Environment variable MRC_LOCAL must be EXPORTED. Example: export MRC_LOCAL='/path/to/your/directory/for/MRC'\n";
    }
}

sub warn_ssh_keys{
    my ( $self ) = @_;
    print STDERR "Please remember that you will need passphrase-less SSH set up already.\nNote that if you see a prompt for a password in your connection to <" . $self->remote_host . "> below, that would mean that you did not have passphrase-less SSH set up properly. Instructions for setting it up can be found by searching google for the term \"passphraseless ssh\".\n";
    my $likely_location_of_ssh_public_key = $ENV{'HOME'} . "/.ssh/id_rsa.pub";
    if (!(-s $likely_location_of_ssh_public_key)) {
	print "WARNING: I notice that you do not have an SSH public key (expected to be found in <$likely_location_of_ssh_public_key>), which means you most likely do not have passphrase-less ssh set up with the remote machine (<" . $self->remote_host . ">).\n";
    }
    return $self;
}

1;

__DATA__

mrc_handler.pl  [OPTIONS]

Last updated Feb 2013.

MRC (Metagenomic Read Classifier) program by Tom Sharpton.

Handles a bunch of database and cluster stuff.

See the examples below for more information.

EXAMPLES:

1. You have to set your MRC_LOCAL environment variable.
export MRC_LOCAL=/my/home/directory/MRC       <-- this is your github-checked-out copy of MRC

2. Now you need to store your MySQL database password in a local variable, since we have to (insecurely!) use this.
I recommend typing this:
PASS=yourMysqlPassword

3. You have to set up passphrase-less SSH to your computational cluster. In this example, the cluster is "compute.cluster.university.edu".
Follow the links at "https://www.google.com/search?q=passphraseless+ssh" in order to find some solutions for setting this up. It is quite easy!

4. Then you can run mrc_handler.pl as follows. Sorry the command is so long!

Note that the FIRST TIME you run it, you need to calculat the HMM database (--hdb) and the blast database (--bdb), and you have to STAGE (i.e. copy) the files to the remote cluster with the --stage option.
So your first run will look something like this:
   perl $MRC_LOCAL/scripts/mrc_handler.pl --hdb --bdb --stage [...the rest of the options should be copied from the super long command below...]

On subsequent runs, you can omit "--hdb" and "--bdb" and "--stage" , and run just this:
   perl $MRC_LOCAL/scripts/mrc_handler.pl --dbuser=sqlusername --dbpass=$PASS --dbhost=data.your.university.edu --rhost=compute.cluster.university.edu --ruser=clusterusername --rdir=/cluster_temp_storage/MRC --ffdb=/local_database/MRC_ffdb --refdb=/local_home/sifting_families --projdir=./MRC/data/randsamp_subset_perfect_2/


(put some more examples here)

OPTIONS:

--ffdb=/PATH/TO/FLATFILES  (or -d /PATH/TO/FLATFILES)     (REQUIRED argument)
    local flat file database path


--refdb=/PATH/TO/REFERENCE/FLATFILES     (REQUIRED argument)
    Location of the reference flatfile data (HMMs, aligns, seqs for each family). The subdirectories for the above should be fci_N, where N is the family construction_id in the Sfams database that points to the families encoded in the dir. Below that are HMMs/ aligns/ seqs/ (seqs for blast), with a file for each family (by famid) within each.

--projdir=/PATH/TO/PROJECT/DIR (or -i /PATH/TO/PROJECT/DIR)     (REQUIRED argument)
    project directory? Local?

DATABASE ARGUMENTS:

--dbhost=YOUR.DATABASE.SERVER.COM           (REQUIRED argument)
    The machine that hosts the remote MySQL database.

--dbuser=MYSQL_USERNAME                     (REQUIRED argument)
    MySQL username for logging into mysql on the remote database server.

--dbpass=MYSQL_PASSWORD (in plain text)     (REQUIRED argument)
    The MySQL password for <dbuser>, on the remote database server.
    This is NOT VERY SECURE!!! Note, in particular, that it gets saved in your teminal history.

--dbname=DATABASENAME (OPTIONAL argument: default is "Sfams_hmp")
    The database name. Usually something like "Sfams_lite" or "Sfams_hmp".

--dbschema=SCHEMANAME (OPTIONAL argument: default is "Sfams::Schema")
    The schema name.

--searchdb-prefix=STRING (Optional: default is "SFams_all")
    The prefix string that defines the search databases (sequence and HMM) that we will build.

REMOTE COMPUTATIONAL CLUSTER ARGUMENTS:

--rhost=SOME.CLUSTER.HEAD.NODE.COM     (REQUIRED argument)
    The machine that manages the remote computational cluster. Usually this is a cluster head node.

--ruser=USERNAME                       (REQUIRED argument)
    Remote username for logging into the remote computational cluster / machine.
    Note that you have to set up passphrase-less SSH for this to work. Google it!

--rdir=/PATH/ON/REMOTE/SERVER          (REQUIRED, no default)
    Remote path where we will save results

--rpath=COLON_DELIMITED_STRING         (optional, default assumes that the executables will just be on your user path)
    Example: --rpath=/remote/exe/path/bin:/somewhere/else/bin:/another/place/bin
    The PATH on the remote computational server, where we find various executables like 'lastal'.
    COLONS delimit separate path locations, just like in the normal UNIX path variable.

--remote  (Default: ENABLED)
    (or --noremote to disable it)
    Use a remote compute cluster. Specify --noremote to run locally (note: local running has NOT BEEN DEBUGGED much!)



--hmmdb=STRING (or -h STRING) (Optional: automatically set to a default value)
   HMM database name

--blastdb=STRING (or -b STRING)
   BLAST database name

--sub=STRING
    Not sure what this is. ("FAMILY SUBSET LIST")

--stage  (Default: disabled (no staging))
    Causes the remote database to get copied, I think. Slow!

--hdb
    Should we build the hmm db?

--bdb
    Should we build the blast db?

--forcedb
    Force database build.

-n INTEGER
    HMM database split size.

--wait=SECONDS (or -w SECONDS)
    How long to wait for... something.


--pid=INTEGER
    Process ID for something (?)

--goto=STRING
    Go to a specific step in the computation.
    Valid options are:
      * 'B' or 'BUILD'
      * 'R' or 'REMOTE'
      * 'S' or 'SCRIPT'
      * 'H' or 'HMM'
      * 'G' or 'GET'
      * 'C' or 'CLASSIFY'
      * 'O' or 'OUTPUT'

-z INTEGER
    n seqs per sample split (??)

-e FLOAT
    E-value

-c FLOAT
    Coverage (?)

--verbose (or -v)
    Output verbose messages.


KNOWN BUGS:

  None known at the moment...

--------------

