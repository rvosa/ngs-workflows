#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::SeqIO;
use Bio::Phylo::Util::Logger ':levels';
use Bio::Tools::Run::StandAloneBlast;

# process command line options
my ( $program, $expect ) = ( 'blastn', 1e-30 ); # have defaults
my ( $verbosity, $database ); # no defaults
GetOptions(
	'program=s'  => \$program,
	'database=s' => \$database,
	'expect=s'   => \$expect,
	'verbose+'   => \$verbosity,
);

# create remote blaster
my $blast = Bio::Tools::Run::StandAloneBlast->new(
	'-program'  => $program,
	'-expect'   => $expect,
	'-database' => $database,
);

# create seq reader
my $reader = Bio::SeqIO->new(
	'-format' => 'fasta',
	'-fh'     => \*STDIN,
);

# create logger, report status
my $log = Bio::Phylo::Util::Logger->new(
	'-class' => 'main',
	'-level' => $verbosity
);
$log->info("program => $program");
$log->info("data    => $database");
$log->info("expect  => $expect");

# submit each seq as job
while( my $seq = $reader->next_seq ) {
	my $report = $blast->blastall($seq);
	$log->info("submitted job");
	
	# iterate over result sets
	while( my $result = $report->next_result ) {
		my ( $query, $score, %accessions ) = ( $result->query_name );
		$log->debug("query: $query");
		
		# iterate over hits in result set
		HIT: while( my $hit = $result->next_hit ) {
			my $name;
			
			# retain names of all hits with highest score
			if ( not defined $score ) {
				$score = $hit->significance;
				$name = $hit->name;
			}
			elsif ( $score == $hit->significance ) {
				$name = $hit->name;
			}
			else {			
				last HIT;
			}
			$accessions{$name} = $score;
			$log->debug("name: $name score: $score");	
		}
		print join("\t",$query, keys %accessions), "\n";
	}
}


