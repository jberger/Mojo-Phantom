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

  my %bind = (
    ok    => 'Test::More::ok',
    is    => 'Test::More::is',
    diag  => 'Test::More::diag',
    error => 'Test::More::fail',
    %{ $opts->{bind} || {} },
  );

  my $phantom = Test::Mojo::Phantom->new(
    base    => $base,
    bind    => \%bind,
    cookies => [ $t->ua->cookie_jar->all ],
    package => $opts->{package} || caller,
  );

  my $name = $opts->{name} || 'all phantom tests successful';
  my $ctx = Test::Stream::Toolset::context();
  my $st = do {
    $ctx->subtest_start($name);
    my $subtest_ctx = Test::Stream::Toolset::context();
    $subtest_ctx->plan($opts->{plan}) if $opts->{plan};
    Mojo::IOLoop->next_tick(sub{
      $phantom->execute_url($url, $js, sub { Mojo::IOLoop->stop } );
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

