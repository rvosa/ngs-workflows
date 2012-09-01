#!/usr/bin/perl
use strict;
use warnings;
use Parallel::MPI::Simple;

warn "mpirun -np 5 perl mpi.pl";

MPI_Init();
my $rank = MPI_Comm_rank(MPI_COMM_WORLD);

# we are a child process
if ($rank > 0) {
	while(1) {
		my $msg = "Hello, I'm $rank";
		MPI_Send($msg, 0, 123, MPI_COMM_WORLD);
		sleep 5;
	}
}

# we are the parent
else {
	while(1) {
		for my $i ( 1 .. MPI_Comm_size(MPI_COMM_WORLD) - 1 ) {
			my $msg = MPI_Recv($i, 123, MPI_COMM_WORLD);
			print "$rank received: '$msg'\n";
		}
		sleep 5;
	}
}
MPI_Finalize();