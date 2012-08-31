use strict;
use warnings;
use Bio::SeqIO;
use Getopt::Long;
use Bio::Phylo::Util::Logger;

# process command line arguments
my ( $keep, $verbosity );
GetOptions(
	'keep=s'   => \$keep,
	'verbose+' => \$verbosity,
);

# create logger
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity,
);

# create genbank reader
my $reader = Bio::SeqIO->new(
	'-format' => 'genbank',
	'-fh'     => \*STDIN,
);

# iterate over sequences, write those of interest out as FASTA
while ( my $seq = $reader->next_seq ) {
	eval {
		if ( my $species = $seq->species ) {
			my %classification = map { $_ => 1 } $species->classification;
			if ( ! $keep ^ !! $classification{$keep} ) {
				print '>', $seq->primary_id, '|', $species->ncbi_taxid, "\n";		
				print $seq->seq, "\n";
			}
		}
	};
	if ( $@ ) {
		$log->warn( "problem with $seq: $@" );
	}
}