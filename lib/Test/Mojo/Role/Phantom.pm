package Test::Mojo::Role::Phantom;

use Role::Tiny;

use Test::More 1.301001_097 ();
use Test::Stream::Toolset;

require Test::Mojo::Phantom;

sub phantom_ok {
  my $t = shift;
  my $opts = ref $_[-1] ? pop : {};
  my $js = pop;

  my $base = $t->ua->server->nb_url;

  my $url = $t->app->url_for(@_);
  unless ($url->is_abs) {
    $url = $url->to_abs($base);
  }

  my $phantom = $opts->{phantom} || do {
    my %bind = (
      ok    => 'Test::More::ok',
      is    => 'Test::More::is',
      diag  => 'Test::More::diag',
      fail  => 'Test::More::fail',
      %{ $opts->{bind} || {} },
    );

    Test::Mojo::Phantom->new(
      base    => $base,
      bind    => \%bind,
      cookies => [ $t->ua->cookie_jar->all ],
      package => $opts->{package} || caller,
    );
  };

  my $name = $opts->{name} || 'all phantom tests successful';
  my $ctx = Test::Stream::Toolset::context();
  my $st = do {
    $ctx->subtest_start($name);
    my $subtest_ctx = Test::Stream::Toolset::context();
    $subtest_ctx->plan($opts->{plan}) if $opts->{plan};
    Mojo::IOLoop->next_tick(sub{
      $phantom->execute_url($url, $js, sub {
        my ($phantom, $error, $status) = @_;
        if ($status) {
          my $exit = $status >> 8;
          my $sig  = $status & 127;
          my $msg  = $exit ? "status: $exit" : "signal: $sig";
          Test::More::diag("phantom exitted with $msg");
        }
        Test::More::fail($error) if $error;
        Mojo::IOLoop->stop;
      });
    });
    Mojo::IOLoop->start;
    $ctx->subtest_stop($name);
  };

  my $e = $ctx->subtest(
    # Stuff from ok (most of this gets initialized inside)
    undef, # real_bool, gets set properly by initializer
    $st->{name}, # name
    undef, # diag
    undef, # bool
    undef, # level

    # Subtest specific stuff
    $st->{state},
    $st->{events},
    $st->{exception},
    $st->{early_return},
    $st->{delayed},
    $st->{instant},
  );

  return $t->success($e->bool);
}

1;

=head1 NAME

Test::Mojo::Role::Phantom - Adds phantom_ok to Test::Mojo

=head1 SYNOPSIS

  use Mojolicious::Lite;

  use Test::More;
  use Test::Mojo;

  # -- this --
  use Test::Mojo::Phantom;

  # -- or this --
  require Test::Mojo::Role::Phantom;
  Role::Tiny->apply_roles_to_package('Test::Mojo', 'Test::Mojo::Role::Phantom');

  any '/' => 'index';

  my $t = Test::Mojo->new;

  # -- or this --
  require Test::Mojo::Role::Phantom;
  Role::Tiny->apply_roles_to_object($t, 'Test::Mojo::Role::Phantom');

  $t->phantom_ok('/' => <<'JS');
    var text = page.evaluate(function(){
      return document.getElementById('name').innerHTML;
    });
    perl.is(text, 'Bender', 'name changed after loading');
  JS

  done_testing;

  __DATA__

  @@ index.html.ep

  <!DOCTYPE html>
  <html>
    <head></head>
    <body>
      <p id="name">Leela</p>
      <script>
        (function(){ document.getElementById('name').innerHTML = 'Bender' })();
      </script>
    </body>
  </html>

=head1 DESCRIPTION

L<Test::Mojo::Role::Phantom> is a L<Role::Tiny> role which adds a L<phantom_ok> method to L<Test::Mojo> or a L<Test::Mojo> instance.
This method tests the javascript behavior of the app via an external L<PhantomJS|http://phantomjs.org/> process.
You must install that program and it must be in your C<PATH> in order to use this method.
The low level interaction is handled by a L<Test::Mojo::Phantom> instance, but for the most part that is transparent to the test method.

=head1 METHODS

=head2 phantom_ok

 $t = $t->phantom_ok(@url_for, $js, \%opts)

The arguments are as follows

=head3 url specification

L<phantom_ok> takes a url or arguments for L<Mojolicious::Controller/url_for>, a required string of javascript and and optional hash reference of additional arguments.

=head3 javascript

The javascript string will be executed once the phantom object has loaded the page in question.
At this point, it will have access to all the symbols of a typical phantom process as well as

=over

=item page

The page object.

=item status

The page request status, should be C<success>.

=item perl

A function which takes the name of a perl function and arguments for that function.
The function name and the arguments are serialized as JSON and then executed on the perl side.

If the function dies (or is L<CORE::die>), the test fails.

=back

Since it would be prohibitively expensive to start up a new phantom process for each test in the string, the entire string is executed as a subtest.
The test result will be success if the entire subtest is a success.

If there is a javascript error, the subtest will fail.

=head3 options

The method also takes a hashreference of additional options.
They are as follows:

=over

=item name

The name of the subtest

=item plan

The number of tests that are expected.
While not required, this is more useful than most plans in L<Test::More> since the transport of the commands is volatile.
By specifying a plan in this way, if the process exits (status zero) early or never starts, the test will still fail rather than silently pass assuming there were no tests.

=item package

The package that is searched for Perl functions if the function name is not fully qualified.

=item bind

A hash reference of key-value pairs which then have shortcuts built in the phantom process.
The pairs passed are merged into

  {
    ok    => 'Test::More::ok',
    is    => 'Test::More::is',
    diag  => 'Test::More::diag',
    fail  => 'Test::More::fail',
  }

In the phantom process you may then use the shortcut as

  perl.ok(@args)

Which is handy if you are using a certain function often.

Note that if the value is falsey, the key name is use as the target.

=item phantom

If you need even more control, you may pass in an instance of L<Test::Mojo::Phantom> and it will be used.

=back

=head1 NOTES

This module requires a VERY modern L<Test::More> because it requires L<Test::Stream>.

