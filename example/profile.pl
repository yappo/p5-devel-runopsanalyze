use strict;
use warnings;
use blib;
use Devel::RunOpsAnalyze;

sub rolling {
    my $x = 0;
    for my $i (0..10) {
        $x += $i;
    }
}
sub unrolling {
    my $x = 0;
    $x += 0;
    $x += 1;
    $x += 2;
    $x += 3;
    $x += 4;
    $x += 5;
    $x += 6;
    $x += 7;
    $x += 8;
    $x += 9;
    $x += 10;
}

print "rolling op\n";
print analyze(\&rolling)->as_term;

print "\nunrolling op\n";
print analyze(\&unrolling)->as_term;
