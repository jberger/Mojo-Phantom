package Test::Mojo::Phantom;

use Mojo::Base -base;

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

has base => sub { shift->t->ua->server->nb_url };

has bind => sub { {
  ok   => 'Test::More::ok',
  is   => 'Test::More::is',
  diag => 'Test::More::diag',
} };

has package => 'Test::More';
has sep => '--__TEST_MOJO_PHANTOM__--';
has t => sub { die 't is required' };

has template => <<'TEMPLATE';
  % my ($self, $url, $js) = @_;
  % my $t = $self->t;

  // Setup perl function
  function perl() {
    var system = require('system');
    var args = Array.prototype.slice.call(arguments);
    system.stdout.writeLine(JSON.stringify(args));
    system.stdout.writeLine('<%== $self->sep %>');
    system.stdout.flush();
  }

  // Setup bound functions
  % my $bind = $self->bind || {};
  % foreach my $func (keys %$bind) {
    % my $target = $bind->{$func} || $func;
    perl.<%= $func %> = function() {
      perl.apply(this, ['<%== $target %>'].concat(Array.prototype.slice.call(arguments)));
    };
  % }
  
  // Setup Cookies
  % foreach my $cookie ($t->ua->cookie_jar->all) {
    % my $name = $cookie->name;
    phantom.addCookie({
      name: '<%== $name %>',
      value: '<%== $cookie->value %>',
      domain: '<%== $cookie->domain || $self->base->host %>',
    }) || perl.diag('Failed to import cookie <%== $name %>');
  % }

  // Requst page and inject user-provided javascript
  var page = require('webpage').create();
  page.open('<%== $url %>', function(status) {

    <%= $js %>;

    phantom.exit();
  });
TEMPLATE

sub _resolve {
  my ($function, $package) = @_;
  $package = $1 if $function =~ s/(.*+):://;
  return $package->can($function);
}

sub _tmp_file {
  my $content = shift;
  my $tmp = File::Temp->new(SUFFIX => '.js');
  Mojo::Util::spurt($content => "$tmp");
  return $tmp;
}

sub _phantom_raw {
  my ($self, $file, $cb) = @_;
  # note that $file might be an object that needs to have a strong reference
 
  my $pid = open my $pipe, '-|', 'phantomjs', "$file";
  die 'Could not spawn' unless defined $pid;
  my $stream = Mojo::IOLoop::Stream->new($pipe);
  my $id = Mojo::IOLoop->stream($stream);

  my $sep = $self->sep;
  my $package = $self->package;
  my $buffer = '';
  
  $stream->on(read => sub {
    my ($stream, $bytes) = @_;
    warn "\nPerl <<<< Phantom: $bytes\n" if DEBUG;
    $buffer .= $bytes;
    while ($buffer =~ s/^(.*)\n$sep\n//) {
      my ($function, @args) = @{ j $1 };
      _resolve($function, $package)->(@args);
    }
  });

  $stream->on(close => sub {
    waitpid $pid, 0;
    undef $file;
    Mojo::IOLoop->remove($id);
    $cb->(undef);
  });
}

sub _phantom {
  my ($self, %opts) = @_;

  my $url = $self->t->app->url_for(@{ $opts{url_for} || [] });
  $url = $url->to_abs($self->base) unless $url->is_abs;

  my $js = Mojo::Template
    ->new(escape => \&javascript_value_escape)
    ->render($self->template, $self, $url, $opts{js});

  warn "\nPerl >>>> Phantom:\n$js\n" if DEBUG;
  my $tmp = _tmp_file($js);

  Mojo::IOLoop->delay(sub{
    $self->_phantom_raw($tmp, shift->begin);
  })->wait;
}


1;

