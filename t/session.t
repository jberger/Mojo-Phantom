use Mojolicious::Lite;

use Test::More;
use Test::Mojo;

use Test::Mojo::Phantom;

my $phantom = \&Test::Mojo::Phantom::phantom;

any '/set' => sub {
  my $c = shift;
  $c->session(val => 'pass');
  $c->render(text => 'set');
};

any '/get' => 'get';

my $t = Test::Mojo->new;
$t->get_ok('/set')
  ->status_is(200)
  ->content_is('set');

$t->$phantom('get', <<'JS');
  var text = page.evaluate(function(){
    return document.getElementsByTagName('p')[0].innerHTML;
  });

  test(['is', text, 'pass', 'cookie seen from phantom']);
JS

done_testing;

__DATA__

@@ get.html.ep

<!DOCTYPE html>
<html>
<head></head>
<body>
  %= tag p => session('val') || 'fail';
</body>
</html>

