use Mojolicious::Lite;

any '/' => { text => 'Hello World'};

use Test::More;
use Test::Mojo;

use Test::Mojo::Phantom;

my $t = Test::Mojo->new;

my $success = 1;
my $id = Mojo::IOLoop->timer(10 => sub { $success = 0; Mojo::IOLoop->stop });

$t->phantom_ok('/', <<'JS');
  perl.ok(1, 'dummy test from javascript');
  var system = require('system');
  perl('CORE::die', 'die');
  system.stdin.read(20); // sleep 20
JS

Mojo::IOLoop->remove($id);
ok $success, 'kill the phantom process on perl-side error';
#TODO kill the test on failure

done_testing;

