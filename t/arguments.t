use Mojolicious::Lite;

any '/' => sub {
    my $c = shift;
    $c->cookie( chocolate_chip => "yummy", { expires => time + 60 } );
    return $c->render( text => 'Cookie has been set.' );
};

use Mock::MonkeyPatch;
use Test::More;
use Test::Mojo::WithRoles qw/Phantom/;

use File::Temp ();
use Mojo::File qw(tempfile);

my $t = Test::Mojo::WithRoles->new;

my $js = <<'JS';
    perl.ok(phantom.cookiesEnabled, 'cookies are enabled');
    perl.is(phantom.cookies.length, 1, "cookie has been set");
JS

my $cookie_file = tempfile();
my $options = { phantom_args => ["--cookies-file=$cookie_file"], plan => 2 };

$t->phantom_ok('/', $js, $options);

my $cookies = $cookie_file->slurp;

like($cookies, qr/chocolate_chip=yummy/, 'cookie found in cookie file');

do {    # Test passing 'exe' option
    my $exe;
    my $mock = Mock::MonkeyPatch->patch(
        'Mojo::Phantom::Process::start' => sub {
            my ($self) = @_;
            $exe = $self->exe;
            $self->exe('phantomjs');    # Override the value so it can actually run
            Mock::MonkeyPatch::ORIGINAL(@_);
        }
    );
    $t->phantom_ok('/', 'perl.ok(1, "Test ran with default exe");');
    is($exe, 'phantomjs', 'exe - default value');

    $t->phantom_ok('/', 'perl.ok(1, "Test ran with custom exe");', { exe => 'myphantom' } );
    is($exe, 'myphantom', 'exe - custom value');
};

done_testing;

