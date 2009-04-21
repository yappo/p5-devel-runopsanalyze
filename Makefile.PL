use inc::Module::Install;
name 'Devel-RunOpsAnalyze';
all_from 'lib/Devel/RunOpsAnalyze.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
#auto_set_repository;
WriteAll;
