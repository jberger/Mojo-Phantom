use Mojolicious::Lite;

any '/' => 'main';

use Test::More;
use Test::Mojo;

use Test::Mojo::Phantom -apply;

my $t = Test::Mojo->new;

ok 1, 'from mojo';

my $js = <<'JS';
  test(['ok', 1, 'ok from phantomjs']);
  test(['is', status, 'success', 'status check']);

  var text = page.evaluate(function(){
    return document.getElementsByTagName('p')[0].innerHTML;
  })

  test(['is', text, 'Goodbye', 'code evaluation']);
JS

$t->phantom_ok('main', $js, {plan => 3});

done_testing;

__DATA__

@@ main.html.ep

<!DOCTYPE html>
<html>
  <head>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.2/jquery.min.js"></script>
  </head>
  <body>
    <p>Hello</p>
    %= javascript begin
      $(function(){ $('p').text('Goodbye') });
    % end
  </body>
</html>

