use Mojolicious::Lite;

use Test::More;
use Test::Mojo::WithRoles qw/Phantom/;

any '/' => 'index';

my $t = Test::Mojo::WithRoles->new;

use Test::Stream::Tester;

my $grab = grab();

my $opts = { setup => <<'SETUP' };
  page.onConsoleMessage = function(msg) {
    perl.diag(msg);
  }
SETUP

$t->phantom_ok('/' => <<'JS', $opts);
  page.evaluate(function(){
    console.log('test message');
  });
JS

events_are(
  $grab->finish->[0]->events,
  check {
    event diag => { message => 'startup message' };
    event diag => { message => 'test message' };
    directive 'end';
  },
);

done_testing;

__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
  <head></head>
  <body>
    Dummy
    %= javascript begin
      console.log('startup message');
    % end
  </body>
</html>
