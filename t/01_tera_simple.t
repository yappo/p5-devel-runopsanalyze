use strict;
use warnings;
use Test::More tests => 1;
use Devel::RunOpsAnalyze;

isa_ok(analyze { +{} }, 'Devel::RunOpsAnalyze::Trace');

