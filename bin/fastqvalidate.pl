#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# for phred line regex
my $phredchars = join( '', map { chr } 33..126 );

# to hold state from one line to the next
my ( $id, $seq, $phred, $repeat );

my $lc = 1; # linecounter

while(<>) {
	chomp;
	
	# must be ID line
	if ( ( $lc - 1 ) == 0 || ( ( $lc - 1 ) % 4 ) == 0 ) {
		if ( /^\@(.+)$/ ) {
			$id = $1;
			$seq = '';
			$phred = '';
			$repeat = '';
		}
		else {
			die "Invalid ID at line $lc: $_";
		}
	}
	
	# must be seq line
	elsif ( ( $lc - 2 ) == 0 || ( ( $lc - 2 ) % 4 ) == 0 ) {
		if ( /^[GATCRYWSMKHBVDNU]*$/i ) {
			$seq = $_;
		}
		else {
			die "Invalid seq at line $lc: $_";
		}
	}
	
	# must be + line
	elsif ( ( $lc - 3 ) == 0 || ( ( $lc - 3 ) % 4 ) == 0 ) {
		if ( /^\+(.+)$/ ) {
			$repeat = $1;
			if ( $repeat && $repeat ne $id ) {
				die "ID not repeated after + at line $lc: $_";
			}
		}
		elsif ( /^\+$/ ) {
			$repeat = '+';
		}
		else {
			die "No + at line $lc: $_";
		}
	}
	
	# must be phred line
	elsif ( ( $lc - 4 ) == 0 || ( ( $lc - 4 ) % 4 ) == 0 ) {
		my $seqlength = length($seq);
		if ( /^([\Q$phredchars\E]{$seqlength})$/ ) {
			$phred = $1;
		}
		else {
			my @ints = map { ord } split //, $_;
			die "Invalid phred @ints at line $lc: $_";
		}
	}		
	
	$lc++;
}

# not all parts were seen
if ( ( $lc - 1 ) % 4 ) {
	if ( ! $phred && $repeat && $seq && $id ) {
		die "File truncated at line $lc before phred line";
	}
	elsif ( ! $repeat && $seq && $id ) {
		die "File truncated at line $lc before + line";
	}
	elsif ( ! $seq ) {
		die "File truncated at line $lc before seq line";
	}
}