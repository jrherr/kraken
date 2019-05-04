package krakenlib;

# Copyright 2013-2019, Derrick Wood, Jennifer Lu <jlu26@jhmi.edu>
#
# This file is part of the Kraken taxonomic sequence classification system.
#
# Kraken is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Kraken is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Kraken.  If not, see <http://www.gnu.org/licenses/>.

# Common subroutines for other Kraken scripts

use strict;
use warnings;

# Input: the argument for a --db option (possibly undefined)
# Returns: the DB to use, taking KRAKEN_DEFAULT_DB and KRAKEN_PATH
#   into account.
sub find_db {
  my $supplied_db_prefix = shift;
  my $db_prefix;
  if (! defined $supplied_db_prefix) {
    if (! exists $ENV{"KRAKEN_DEFAULT_DB"}) {
      die "Must specify DB with either --db or \$KRAKEN_DEFAULT_DB\n";
    }
    $supplied_db_prefix = $ENV{"KRAKEN_DEFAULT_DB"};
  }
  my @db_path = (".");
  if (exists $ENV{"KRAKEN_DB_PATH"}) {
    my $path_str = $ENV{"KRAKEN_DB_PATH"};
    # Allow zero-length path to be current dir
    $path_str =~ s/^:/.:/;
    $path_str =~ s/:$/:./;
    $path_str =~ s/::/:.:/;

    @db_path = split /:/, $path_str;
  }
  
  # Use supplied DB if abs. or rel. path is given
  if ($supplied_db_prefix =~ m|/|) {
    $db_prefix = $supplied_db_prefix;
  }
  else {
    # Check all dirs in KRAKEN_DB_PATH
    for my $dir (@db_path) {
      my $checked_db = "$dir/$supplied_db_prefix";
      if (-e $checked_db && -d _) {
        $db_prefix = $checked_db;
        last;
      }
    }
    if (! defined $db_prefix) {
      my $printed_path = exists $ENV{"KRAKEN_DB_PATH"} ? qq|"$ENV{'KRAKEN_DB_PATH'}"| : "undefined";
      die "unable to find $supplied_db_prefix in \$KRAKEN_DB_PATH ($printed_path)\n";
    }
  }

  for my $file (qw/database.kdb database.idx/) {
    if (! -e "$db_prefix/$file") {
      die "database (\"$db_prefix\") does not contain necessary file $file\n";
    }
  }

  return $db_prefix;
}

# Input: a FASTA sequence ID
# Output: either (a) a taxonomy ID number found in the sequence ID,
#   (b) an NCBI accession number found in the sequence ID, or undef
sub check_seqid {
  my $seqid = shift;
  my $taxid = undef;
  # Note all regexes here use ?: to avoid capturing the ^ or | character
  if ($seqid =~ /(?:^|\|)kraken:taxid\|(\d+)/) {
    $taxid = $1;  # OK, has explicit taxid
  }
  elsif ($seqid =~ /^(\d+)$/) {
    $taxid = $1;  # OK, has explicit taxid (w/o token)
  }
  # Accession number check
  elsif ($seqid =~ /(?:^|\|)         # Begins seqid or immediately follows pipe
                     ([A-Z]+         # Starts with one or more UC alphas
                        _?           # Might have an underscore next
                        [A-Z0-9]+)   # Ends with UC alphas or digits
                     (?:\||\b|\.)/x  # Followed by pipe, word boundary, or period
        )
  {
    $taxid = $1;  # A bit misleading - failure to pass /^\d+$/ means this is
                  # OK, but requires accession -> taxid mapping
  }
  return $taxid;
}

1;
