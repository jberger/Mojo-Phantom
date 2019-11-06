use Mojolicious::Lite;

any '/' => 'main';

use Test::More;
use Test::Mojo::WithRoles qw/Phantom/;

my $t = Test::Mojo::WithRoles->new;

my $js = <<'JS';
  perl('ok', 1, 'ok from phantomjs');
  setTimeout(function() { perl('ok', 1, 'ok from timeout'); phantom.exit(0); }, 15500 );
JS

$t->phantom_ok('main', $js, { plan => 2, no_exit => 1, timeout => 20 });

done_testing;

__DATA__

@@ main.html.ep

<!DOCTYPE html>
<html>
  <head></head>
  <body>
  </body>
</html>

