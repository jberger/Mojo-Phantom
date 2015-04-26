use Mojolicious::Lite;

any '/' => { text => 'Hello World'};

use Test::More;
use Test::Mojo::WithRoles qw/Phantom/;

use Test::Stream::Tester;
use t::Helper 'no_event';

my $t = Test::Mojo::WithRoles->new;

my $grab = grab();

$t->phantom_ok('/', <<'JS');
  perl.ok(1, 'dummy test from javascript');
  var system = require('system');
  perl('CORE::die', "argh\n");
  perl.ok(1, "don't get here");
JS

events_are(
  $grab->finish->[1]->events,
  check {
    event ok => { pass => 1, name => qr/dummy/ };
    event diag => { message => qr/signal/ };
    event ok => { pass => 0, name => "argh\n" };
    directive \&no_event => { type => 'ok', name => "don't get here" };
  },
);

done_testing;

