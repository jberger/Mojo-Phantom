package Test::Mojo::Phantom;

use Mojo::Base -strict;

use Test::More ();
use File::Temp ();
use Mojo::Util;
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::JSON 'j';
use Mojo::Template;
use JavaScript::Value::Escape;

use constant DEBUG => $ENV{TEST_MOJO_PHANTOM_DEBUG};

sub import {
  my $class = shift;
  if ( @_ == 0 or $_[0] eq '-apply' ) {
    require Test::Mojo::Role::Phantom;
    Role::Tiny->apply_roles_to_package('Test::Mojo', 'Test::Mojo::Role::Phantom');
  }
}

sub _resolve {
  my ($function, $package) = @_;
  $package = $1 if $function =~ s/(.*+):://;
  return $package->can($function);
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

my $template = <<'TEMPLATE';
  % my ($t, $url, %opts) = @_;

  // Setup perl function
  function perl() {
    var system = require('system');
    var args = Array.prototype.slice.call(arguments);
    system.stdout.writeLine(JSON.stringify(args));
    system.stdout.writeLine('<%== $opts{sep} %>');
    system.stdout.flush();
  }
  perl.diag = function() {
    perl.apply(this, ['Test::More::diag'].concat(Array.prototype.slice.call(arguments)));
  };

  perl.is = function() {
    perl.apply(this, ['Test::More::is'].concat(Array.prototype.slice.call(arguments)));
  };

  perl.ok = function() {
    perl.apply(this, ['Test::More::ok'].concat(Array.prototype.slice.call(arguments)));
  };
  
  // Setup Cookies
  % foreach my $cookie ($t->ua->cookie_jar->all) {
    % my $name = $cookie->name;
    phantom.addCookie({
      name: '<%== $name %>',
      value: '<%== $cookie->value %>',
      domain: '<%== $cookie->domain || $opts{base}->host %>',
    }) || perl.diag('Failed to import cookie <%== $name %>');
  % }

  // Requst page and inject user-provided javascript
  var page = require('webpage').create();
  page.open('<%== $url %>', function(status) {

    <%= $opts{js} %>;

    phantom.exit();
  });
TEMPLATE

sub _phantom {
  my ($t, %opts) = @_;
  $opts{package} ||= 'Test::More';
  $opts{base}    ||= $t->ua->server->nb_url;
  $opts{sep}     ||= '--__TEST_MOJO_PHANTOM__--';
  
  my $url = $t->app->url_for(@{ $opts{url_for} || [] });
  unless ($url->is_abs) {
    $url = $url->to_abs($opts{base});
  }

  my $js = Mojo::Template->new(escape => \&javascript_value_escape)->render($template, $t, $url, %opts);


  warn "\nPerl >>>> Phantom:\n$js\n" if DEBUG;

  my $buffer = '';
  my $read = sub {
    my ($stream, $bytes) = @_;
    warn "\nPerl <<<< Phantom: $bytes\n" if DEBUG;
    $buffer .= $bytes;
    while ($buffer =~ s/^(.*)\n$opts{sep}\n//) {
      my ($test, @args) = @{ j $1 };
      _resolve($test, $opts{package})->(@args);
    }
  };

  Mojo::IOLoop->delay(sub{
    _phantom_raw($js, $read, shift->begin);
  })->wait;
}


1;

