#!/usr/bin/perl
use strict;
use Bio::SeqIO;

# simple example script to translate FASTQ to FASTA
# using BioPerl.

my $reader = Bio::SeqIO->new(
	'-fh'     => \*STDIN,
	'-format' => 'fastq',
);

while ( my $seq = $reader->next_seq ) {
	my $name   = $seq->display_id;
	my $string = $seq->seq;
	print '>', $name, "\n", $string, "\n";
}