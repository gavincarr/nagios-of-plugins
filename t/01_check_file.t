# check_file tests

use NOP::Test;
use IPC::Run3;
use FindBin qw($Bin);
use File::Basename;

plan tests => 1 * blocks;

my $root_dir = dirname $Bin;
my $plugin = 'check_file';
my $cmd = "$root_dir/$plugin";

run_compare( input => 'output' );

sub execute {
  my @cmd = @_;
  my $out = '';
  unshift @cmd, $cmd;
  run3 \@cmd, \undef, \$out, \$out;
  return $out;
}

sub regex {
  my $regex = shift;
  return qr/$regex/;
}

__END__

=== usage 1
--- input chomp execute
-?
--- output chomp regex
^Usage: 
=== usage 2
--- input chomp execute
--usage
--- output chomp regex
^Usage: 
