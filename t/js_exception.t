use Mojolicious::Lite;

use Test::More;
use Test::Mojo::WithRoles qw/Phantom/;

use Test::Stream::Tester;
use t::Helper 'no_event';

any '/' => { text => 'response' };

my $t = Test::Mojo::WithRoles->new;

my $grab = grab();

$t->phantom_ok('/' => <<'JS');
  perl.ok(1, 'dummy');
  page.evaluate(function(){
    window.dozNotExistz();
  });
  perl.ok(1, "don't get here");
JS

events_are(
  $grab->finish->[1]->events,
  check {
    event ok => { name => 'dummy' };
    event diag => { message => qr/signal/ };
    event ok => { pass => 0, name => qr/PHANTOM ERROR.*dozNotExistz/ };
    directive \&no_event => { type => 'ok', name => "don't get here" };
  },
);

done_testing;


