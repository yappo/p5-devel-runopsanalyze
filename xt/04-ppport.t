use strict;
use warnings;
use Test::More;
eval "use Test::PPPort";
plan skip_all => "Test::PPPort required for testing ppport.h" if $@;
ppport_ok();
