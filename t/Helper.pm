package t::Helper;

use Exporter 'import';

our @EXPORT_OK = (qw/no_event/);

sub no_event {
  my ($checks, $events, $spec) = @_;
  @$spec{qw/debug_package debug_file debug_line/} = (caller)[0..2];
  my $check = Test::Stream::Tester::Checks::Event->new(%$spec);
  my $type = $check->get('type');
  $events = $events->clone;
  while (my $got = $events->next($type)) {
    my ($ret, @ignore) = $checks->check_event($check, $got);
    return (0, "  Event '$type' like the spec does exist when it should not") if $ret;
  }
  return (1);
}

1;

