BEGIN { require './t/TestHelper.pm' }
use Test;
use File::Spec;

plan(tests => 4);

ok(TestHelper->create_dist('Foo'));
ok(TestHelper->build_dist('Foo'));
ok(-f File::Spec->catfile(qw(t Foo CPAN MakeMaker.pm)));
ok(TestHelper->kill_dist('Foo'));
