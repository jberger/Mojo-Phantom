package Test::Mojo::Phantom;

use Mojo::Base -strict;

use Test::More ();
use File::Temp ();
use Mojo::Util;
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::JSON 'j';

use constant DEBUG => $ENV{TEST_MOJO_PHANTOM_DEBUG};

sub import {
  my $class = shift;
  if ( @_ == 0 or $_[0] eq '-apply' ) {
    require Test::Mojo::Role::Phantom;
    Role::Tiny->apply_roles_to_package('Test::Mojo', 'Test::Mojo::Role::Phantom');
  }
}

sub _phantom_raw {
  my $cb = pop;
  my ($js, $read) = @_;

  my $tmp = File::Temp->new(SUFFIX => '.js');
  Mojo::Util::spurt($js => "$tmp");

  my $pid = open my $phantom, '-|', 'phantomjs', "$tmp";
  die 'Could not spawn' unless defined $pid;

  my $stream = Mojo::IOLoop::Stream->new($phantom);
  if ($read) { $stream->on(read => $read) }
  my $id = Mojo::IOLoop->stream($stream);
  $stream->on(close => sub {
    waitpid $pid, 0;
    undef $tmp;
    Mojo::IOLoop->remove($id);
    $cb->(undef);
  });
}

sub _phantom {
  my ($t, %opts) = @_;

  my $base = $t->ua->server->nb_url;
  my $url = $t->app->url_for(@{ $opts{url_for} || [] });
  unless ($url->is_abs) {
    $url = $url->to_abs($base);
  }

  my $sep = '--__TEST_MOJO_PHANTOM__--';

  my $js = '';

  $js .= sprintf <<'  JS', $sep;
    // Setup test function
    function test(args) {
      var system = require('system');
      system.stdout.writeLine(JSON.stringify(args));
      system.stdout.writeLine('%s');
      system.stdout.flush();
    }
  JS

  $js .= "\n    // Setup Cookies\n";
  foreach my $cookie ($t->ua->cookie_jar->all) {
    my $name = $cookie->name;
    $js .= sprintf <<'    JS', $name, $cookie->value, $cookie->domain || $base->host, $name;
      phantom.addCookie({
        name: '%s',
        value: '%s',
        domain: '%s',
      }) || test(['diag', 'Failed to import cookie %s']);
    JS
  }

  $js .= sprintf <<'  JS', $url, $opts{js};
    // Requst page and inject user-provided javascript
    var page = require('webpage').create();
    page.open('%s', function(status) {

      %s;

      phantom.exit();
    });
  JS

  warn "\nPerl >>>> Phantom:\n$js\n" if DEBUG;

  my $buffer = '';
  my $read = sub {
    my ($stream, $bytes) = @_;
    warn "\nPerl <<<< Phantom: $bytes\n" if DEBUG;
    $buffer .= $bytes;
    while ($buffer =~ s/^(.*)\n$sep\n//) {
      my ($test, @args) = @{ j $1 };
      Test::More->can($test)->(@args);
    }
  };

  Mojo::IOLoop->delay(sub{
    _phantom_raw($js, $read, shift->begin);
  })->wait;
}


1;

