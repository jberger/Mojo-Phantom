use Mojolicious::Lite;

use Test::More;
use Test::Mojo;

use Test::Mojo::Phantom;

use Test::Stream::Tester;

any '/' => { text => 'response' };

my $t = Test::Mojo->new;

my $grab = grab();

$t->phantom_ok('/' => <<'JS');
  perl.ok(1, 'dummy');
  // phantom.dozNotExists();
  throw 'argh';
JS

events_are(
  $grab->finish->[0]->events,
  check {
    directive seek => 1;
    event ok => { name => 'dummy' };
    event diag => { message => qr/argh/ };
  },
);

done_testing;


