#!/usr/bin/perl
use strict;

my $usage = $0.' [-a][-u]'."\n-a prints sam header and aligned sequences to STDOUT\n-u prints sam header and unaligned sequences to STDOUT\none of -a or -u required\n";
my $flag = shift or die $usage;

while (my $sam_line = <>) {
    if ($sam_line =~ m/^\@/) {
        print $sam_line;
        next;
    }
    &filter($sam_line);
}
exit;

sub filter {
    my $sam_line = shift;

    my @samFields = split /\s/, $sam_line;
    my $samFlag = $samFields[1];

    if ($samFlag & 0x0004) {
        print $sam_line if ($flag eq '-u');
    }
    else {
        print $sam_line if ($flag eq '-a');
    }
}
