# check_file tests

use NOP::Test;
use IPC::Run3;
use FindBin qw($Bin);
use File::Basename;
use File::Touch;
use YAML;

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

sub check_file {
  my $arg = Load $_[0];
  my $file = $arg->{file} or die "Missing required arg 'file'";
  $file = "$Bin/$file" unless $file =~ m!^/!;
  -f $file or die "Bad file '$file'";
  touch $file if $arg->{touch};
  my @cmd = ( $cmd, "-f$file", $arg->{test} );
  my $out = '';
  run3 \@cmd, \undef, \$out, \$out;
  return $out;
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

=== modtime 1
--- input check_file
file: t01/services.new
touch: 1
test: -m900

--- output chomp regex
^FILE OK

=== modtime 2 (old)
--- input check_file
file: t01/services.old
test: -m900

--- output chomp regex
^FILE CRITICAL

=== size 1
--- input check_file
file: t01/services.old
test: -s362031

--- output chomp regex
^FILE OK

=== size 2 (k)
--- input check_file
file: t01/services.old
test: -s 362k

--- output chomp regex
^FILE OK

=== size 3 (small)
--- input check_file
file: t01/services.old
test: -s362032

--- output chomp regex
^FILE CRITICAL

=== size 4 (kB, small)
--- input check_file
file: t01/services.old
test: -s 400 kB

--- output chomp regex
^FILE CRITICAL

