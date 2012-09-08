#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# process command line arguments
my ( $fastq, $cutoff, $start, $end, $infile, $outfile,  ) = ( 'fastqsanger', 20, 0 );
GetOptions(
	'infile=s'  => \$infile,
	'outfile=s' => \$outfile,
	'fastq=s'   => \$fastq,
	'cutoff=f'  => \$cutoff,
	'start=i'   => \$start,
	'end=i'     => \$end,
);

# range of characters that can occur in quality line
my %range = (
	'fastqsanger'   => [ 33, 126 ],
	'fastqsolexa'   => [ 59, 126 ],
	'fastqillumina' => [ 64, 126 ],
);

# get min and max phred score for current dialect
my $min = $range{lc $fastq}->[0];
my $max = $range{lc $fastq}->[1];

# for phred line regex
my $phredchars = join '', map { chr } $min .. $max;

# to hold state from one line to the next
my ( $id, $seq, $phred, $repeat );

# read from standard in or file
my $infh;
if ( $infile ) {
	open $infh, '<', $infile or die $!;
}
else {
	$infh = \*STDIN;
}

# write to standard out or out file
my $outfh;
if ( $outfile ) {
	open $outfh, '>', $outfile or die $!;
}
else {
	$outfh = \*STDOUT;
}

# iterate over lines
my $lc = 1; # linecounter
while(<$infh>) {
	chomp;
	
	# must be ID line
	if ( ( $lc - 1 ) == 0 || ( ( $lc - 1 ) % 4 ) == 0 ) {
		if ( /^\@(.+)$/ ) {
			print_seq($id,$seq,$repeat,$phred) if $id;
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

# print out last record
print_seq($id,$seq,$repeat,$phred) if $id;

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

sub print_seq {
	my ($id,$seq,$repeat,$phred) = @_;
	$end = length($seq) if not $end;
	my @subseq   = split //, substr $seq,   $start, $end - $start;
	my @subphred = split //, substr $phred, $start, $end - $start;
	my ( @clipseq, @clipphred );
	for my $i ( 0 .. $#subphred ) {
		my $p = ( ord($subphred[$i]) - $min ) * 100 / ( $max - $min );
		if ( $p >= $cutoff ) {
			push @clipseq, $subseq[$i];
			push @clipphred, $subphred[$i];
		}
	}
	$repeat = "+$repeat" if $repeat ne '+';
	print $outfh '@', $id, "\n", join('',@clipseq), "\n", $repeat, "\n", join('',@clipphred), "\n";
}