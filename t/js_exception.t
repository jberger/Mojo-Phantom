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
  page.evaluate(function(){
    window.dozNotExistz();
  });
  perl.ok(1, "don't get here");
JS

events_are(
  $grab->finish->[0]->events,
  check {
    event ok => { name => 'dummy' };
    event ok => { bool => 0, name => qr/PHANTOM ERROR.*dozNotExistz/ };
    event ok => { bool => 0, name => qr/signal/};
    directive 'end';
  },
);

done_testing;


