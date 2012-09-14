#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# process command line arguments
my ( $fastq, $cutoff, $start, $end, $infile, $outfile,  ) = ( 'fastqsanger', 20, 0 );
GetOptions(
	'infile=s'  => \$infile, # --infile=<file> or -i <file>
	'outfile=s' => \$outfile, # --outfile=<file> or -o <file>
	'fastq=s'   => \$fastq, # --fastq=<dialect> or -f <dialect>
	'cutoff=f'  => \$cutoff, # --cutoff=<phred score> or -c <phred score>
	'start=i'   => \$start, # --start=<integer base pos> or -s <integer base pos>
	'end=i'     => \$end, # --end=<integer base pos> or -e <integer base pos>	
);

# range of characters that can occur in quality line
my %range = (
	'fastqsanger'   => [ 33 => 126, 0  => 93 ],
	'fastqsolexa'   => [ 59 => 126, -5 => 62 ],
	'fastqillumina' => [ 64 => 126, 0  => 62 ],
);

# get min and max phred score for current dialect
my $min      = $range{lc $fastq}->[0];
my $max      = $range{lc $fastq}->[1];
my $qual_min = $range{lc $fastq}->[2];
my $qual_max = $range{lc $fastq}->[3];

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
my $error = 0;
while(<$infh>) {
	chomp;
	
	# must be ID line
	if ( ( $lc - 1 ) == 0 || ( ( $lc - 1 ) % 4 ) == 0 ) {
		if ( /^\@(.+)$/ ) {
			print_seq($id,$seq,$repeat,$phred) if $id and not $error;
			$id = $1;
			$seq = '';
			$phred = '';
			$repeat = '';
			$error = 0;			
		}
		else {
			warn "Invalid ID at line $lc: $_";
			$error++;
		}
	}
	
	# must be seq line
	elsif ( ( $lc - 2 ) == 0 || ( ( $lc - 2 ) % 4 ) == 0 ) {
		if ( /^[GATCRYWSMKHBVDNU]*$/i ) {
			$seq = $_;
		}
		else {
			warn "Invalid seq at line $lc: $_";
			$error++;
		}
	}
	
	# must be + line
	elsif ( ( $lc - 3 ) == 0 || ( ( $lc - 3 ) % 4 ) == 0 ) {
		if ( /^\+(.+)$/ ) {
			$repeat = $1;
			if ( $repeat && $repeat ne $id ) {
				warn "ID not repeated after + at line $lc: $_";
				$error++;				
			}
		}
		elsif ( /^\+$/ ) {
			$repeat = '+';
		}
		else {
			warn "No + at line $lc: $_";
			$error++;			
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
			warn "Invalid phred @ints at line $lc: $_";
			$error++;			
		}
	}		
	
	$lc++;
}

# print out last record
print_seq($id,$seq,$repeat,$phred) if $id;

# not all parts were seen
if ( ( $lc - 1 ) % 4 ) {
	if ( ! $phred && $repeat && $seq && $id ) {
		warn "File truncated at line $lc before phred line";		
	}
	elsif ( ! $repeat && $seq && $id ) {
		warn "File truncated at line $lc before + line";
	}
	elsif ( ! $seq ) {
		warn "File truncated at line $lc before seq line";
	}
}

sub print_seq {
	my ($id,$seq,$repeat,$phred) = @_;
	$end = length($seq) if not $end;
	my @subseq   = split //, substr $seq,   $start, $end - $start;
	my @subphred = split //, substr $phred, $start, $end - $start;
	my ( @clipseq, @clipphred );
	for my $i ( 0 .. $#subphred ) {
		my $p = ord($subphred[$i]) - $min + $qual_min;
		if ( $p >= $cutoff ) {
			push @clipseq, $subseq[$i];
			push @clipphred, $subphred[$i];
		}
	}
	$repeat = "+$repeat" if $repeat ne '+';
	print $outfh '@', $id, "\n", join('',@clipseq), "\n", $repeat, "\n", join('',@clipphred), "\n";
}