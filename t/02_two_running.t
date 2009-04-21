use strict;
use warnings;
use Test::More tests => 2;
use Devel::RunOpsAnalyze;

isa_ok(analyze { +{} }, 'Devel::RunOpsAnalyze::Trace');
isa_ok(analyze { +{} }, 'Devel::RunOpsAnalyze::Trace');
