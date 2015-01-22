package Test::Mojo::Role::Phantom;

use Role::Tiny;
use Test::More 1.301001_097 ();
use Test::Stream::Toolset;

require Test::Mojo::Phantom;

sub phantom_ok {
  my $t = shift;
  my $opts = ref $_[-1] ? pop : {};
  my $name = $opts->{name} || 'all phantom tests successful';
  my $ctx = Test::Stream::Toolset::context();
  my $st = do {
    $ctx->subtest_start($name);
    my $subtest_ctx = Test::Stream::Toolset::context();
    $subtest_ctx->plan($opts->{plan}) if $opts->{plan};
    Test::Mojo::Phantom::_phantom($t, @_);
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

