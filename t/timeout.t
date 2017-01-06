use Test2::Bundle::Extended;
use Mojolicious::Lite;

any '/' => 'main';

use Test::Mojo::WithRoles qw/Phantom/;

my $t = Test::Mojo::WithRoles->new;

my $js = <<'JS';
  setTimeout(function() { perl('ok', 1, 'ok from timeout'); phantom.exit(0); }, 2000 );
JS

is(
  intercept { $t->phantom_ok('main', $js, { plan => 1, no_exit => 1, timeout => 1 }); },
  array {
    event Note => sub {
      call message => 'Subtest: all phantom tests successful';
    };
    event Subtest => sub {
      call name => 'all phantom tests successful';
      call pass => 0;
      call effective_pass => 0;

      call subevents => array {
        event Plan => sub {
          call max => 1;
        };
        event Ok => sub {
          call name => 'Aborting test due to timeout';
          call pass => 0;
          call effective_pass => 0;
        };
        event Diag => sub {
          call message => "  Failed test 'Aborting test due to timeout'\n";
        };
        event Diag => sub {
          call message => match qr/^  at /;
        };
        event Diag => sub {
          call message => "phantom exitted with signal: 9";
        };
        event Diag => sub {
          call message => "Looks like you failed 1 test of 1.\n";
        };
        end();
      };
    };
    event Diag => sub {
      call message => "  Failed test 'all phantom tests successful'\n";
    };
    event Diag => sub {
      call message => match qr/^  at /;
    };
    end;
  },
  'Test exited because timeout was reached',
);

$t->phantom_ok('main', $js, { plan => 1, no_exit => 1, timeout => 0, name => "No timeout, test ok" });

$js = <<'JS';
  perl('ok', 1, 'ok from phantomjs');
  phantom.exit(0);
JS

$t->phantom_ok('main', $js, { plan => 1, no_exit => 1, name => "Default timeout, test exits cleanly" });

done_testing;

__DATA__

@@ main.html.ep

<!DOCTYPE html>
<html>
  <head></head>
  <body>
  </body>
</html>

