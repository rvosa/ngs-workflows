#!/usr/bin/perl
use strict;

while (my $sam_line = <>) {
    if ($sam_line =~ m/^\@/) {
        print $sam_line;
        print STDERR $sam_line;
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
        print STDERR $sam_line;
    }
    else {
        print $sam_line;
    }
}
