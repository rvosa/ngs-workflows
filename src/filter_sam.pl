#!/usr/bin/perl
use strict;

my $VERSION = 0.02;

my $usage = $0.' [-v][-a][-u]'."\n-v prints Script name, hashsum, and version, and exits\n-a prints sam header and aligned sequences to STDOUT\n-u prints sam header and unaligned sequences to STDOUT\none of -a or -u required\n";
my $flag = shift or die $usage;

if ($flag eq '-v') {
    print "${0} Version ${VERSION}\n".`md5sum $0`."\n";
    exit;
}

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
