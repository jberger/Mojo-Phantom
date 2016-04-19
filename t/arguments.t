use Mojolicious::Lite;

any '/' => sub {
    my $c = shift;
    $c->cookie( chocolate_chip => "yummy", { expires => time + 60 } );
    return $c->render( text => 'Cookie has been set.' );
};

use Test::More;
use Test::Mojo::WithRoles qw/Phantom/;

use File::Temp ();
use Mojo::Util qw(slurp);

my $t = Test::Mojo::WithRoles->new;

my $js = <<'JS';
    perl.ok(phantom.cookiesEnabled, 'cookies are enabled');
    perl.is(phantom.cookies.length, 1, "cookie has been set");
JS

my $cookie_file = File::Temp->new();
my $options = { phantom_args => ["--cookies-file=$cookie_file"], plan => 2 };

$t->phantom_ok('/', $js, $options);

my $cookies = slurp $cookie_file;

like($cookies, qr/chocolate_chip=yummy/, 'cookie found in cookie file');

done_testing;

=head1 DESCRIPTION

Verify that arguments are passed correctly to PhantomJS.

=cut
