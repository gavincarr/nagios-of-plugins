
use Test::More;
use File::Basename;
use FindBin qw($Bin);
use IPC::Run3;

my $root_dir = dirname $Bin;
my $plugin = 'check_interface';
my $cmd = "$root_dir/$plugin";

SKIP: {
  skip('IO::Interface::Simple required for check_interface', 19)
    unless eval { require IO::Interface::Simple };

  # Setup
  my @if = IO::Interface::Simple->interfaces;
  ok(@if > 0, 'fetch interface list');
  my ($loopback, $up, $down);
  foreach (@if) {
    if ($_->is_running) {
      if ($_->is_loopback) {
        $loopback ||= $_;
      } elsif ($_->is_pt2pt) {
        $ptp ||= $_;
      } else {
        $up ||= $_;
      }
    } else {
      $down ||= $_;
    }
  }

  # Usage failures
  is(check_interface(), 'INTERFACE UNKNOWN - no interface specified', 
    'unknown with no interface');
  is(check_interface(qw(eth0 eth1)), 'INTERFACE UNKNOWN - multiple interfaces specified', 
    'unknown with multiple interfaces');
  is(check_interface(qw(foo12345)), 'INTERFACE UNKNOWN - invalid interface foo12345', 
    'unknown with invalid interface');
  is(check_interface(qw(--up --down eth0)), 'INTERFACE UNKNOWN - cannot specify both --up and --down',
    'unknown with both --up and --down');

  # Up tests
  if ($up) {
    like(check_interface("$up"), qr/^INTERFACE OK/, 
      "ok up interface $up" );
    like(check_interface('--up', "$up"), qr/^INTERFACE OK/, 
      'ok up interface with --up');
    like(check_interface('--down', "$up"), qr/^INTERFACE CRITICAL/, 
      'critical up interface with --down');
    like(check_interface('--ip', '1.1.1.1', "$up"), qr/^INTERFACE CRITICAL/, 
      'critical up interface with --ip 1.1.1.1');
    like(check_interface("--ip", $up->address, "$up"), qr/^INTERFACE OK/, 
      'ok up interface with --ip ' . $up->address) if $up->address;
    like(check_interface("--ptp", "$up"), qr/^INTERFACE CRITICAL/, 
       "critical up interface with --ptp");
   }

  # Down tests
  if ($down) {
    like(check_interface("$down"), qr/^INTERFACE CRITICAL/, 
      "critical down interface $down" );
    like(check_interface('--down', "$down"), qr/^INTERFACE OK/, 
      'ok down interface with --down');
    like(check_interface('--up', "$down"), qr/^INTERFACE CRITICAL/, 
      'critical down interface with --down');
  }

  # PTP tests
  if ($ptp) {
    like(check_interface("$ptp"), qr/^INTERFACE OK/, 
      "ok ptp interface $ptp" );
    like(check_interface('--up', "$ptp"), qr/^INTERFACE OK/, 
      'ok ptp interface with --up');
    like(check_interface('--ptp', "$ptp"), qr/^INTERFACE OK/, 
      'ok ptp interface with --ptp');
    like(check_interface('--up', '--ptp', "$ptp"), qr/^INTERFACE OK/, 
      'ok ptp interface with --up --ptp');
    SKIP: {
      skip('Net::Ping required for ptp-pingable tests', 2)
        unless eval { require Net::Ping };
      like(check_interface('--ptp-pingable', "$ptp"), qr/^INTERFACE OK/, 
        'ok ptp interface with --ptp-pingable');
      like(check_interface("--ptp-pingable", "$up"), qr/^INTERFACE CRITICAL/, 
         "critical up interface with --ptp-pingable");
    }
  }
}

done_testing;

sub check_interface {
  my @cmd = ( $cmd, @_ );
  my $out = '';
  run3 \@cmd, \undef, \$out, \$out;
  chomp $out;
  return $out;
}

