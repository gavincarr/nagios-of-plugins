#
# Common stuff for Nagios plugins
#

package Nagios::Plugin;

use strict;
require Exporter;
use File::Basename;
use Config::Tiny;
use Carp;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $PLUGIN $TIMEOUT $VERBOSE $VERSION);

@ISA = qw(Exporter);
@EXPORT = qw($PLUGIN $TIMEOUT $VERBOSE nagios_exit exit_results);
@EXPORT_OK = qw(nagios_cmp load_config);
%EXPORT_TAGS = (
  std => [ @EXPORT ],
  all => [ @EXPORT, @EXPORT_OK ],
);

$TIMEOUT = 15;

BEGIN {
  my ($pkg, $filename) = caller(2);
  # basename $0 works fine for deriving plugin name except under ePN
  if ($filename && $filename !~ m/EVAL/i) {
    $PLUGIN = basename $filename;
  } else {
    # Nasty hack - under ePN, try and derive the plugin name from the pkg name
    $PLUGIN = lc $pkg;
    $PLUGIN =~ s/^.*:://;
    $PLUGIN =~ s/_5F/_/gi;
  }
}

my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# Nagios::Plugin version (not _plugin_ version)
$VERSION = 0.05;

# ------------------------------------------------------------------------
# Public subroutines

# load_config('section')
sub load_config {
  my ($section) = @_;
  $section ||= $PLUGIN;
  my $config_file = '/etc/nagios/plugins.cfg';
  return {} unless -f $config_file;
  my $ct = Config::Tiny->read($config_file);
  return { %{$ct->{$section} || {}} } if ref $ct;
  return {};
}

# nagios_cmp($var, $op, $critical, $warning), where op is a perl op e.g. le, lt, gt etc.
# Return "CRITICAL" if $var $op $critical, "WARNING" if $var $op $warning, and "OK" otherwise
sub nagios_cmp
{
  my ($var, $op, $critical, $warning) = @_;
  die "invalid op '$op'" unless grep /^\Q$op\E$/, qw(le <= lt < gt > ge >= eq == ne !=);
  if (eval "$var $op $critical") {
    return "CRITICAL";
  } 
  elsif (eval "$var $op $warning") {
    return "WARNING";
  }
  else {
    return "OK";
  }
}

# nagios_exit("CODE", "error string")
sub nagios_exit 
{
  my $code = shift;
  my $errstr = join ', ', @_;
  $code ||= "UNKNOWN";
  die "invalid code '$code'" unless exists $ERRORS{$code};
  if ($errstr && $errstr ne '1') {
    $errstr .= "\n" unless substr($errstr,-1) eq "\n";
    my $short_name = uc $PLUGIN;
    $short_name =~ s/^check_//i;
    print "$short_name $code - $errstr";
  }
  exit $ERRORS{$code};
}

# # Setup alarm handler (will handle any alarm($TIMEOUT) for plugin)
# $SIG{ALRM} = sub {
#   &nagios_exit("UNKNOWN", "no response from $PLUGIN (timeout, ${TIMEOUT}s)");
# };

# exit_results(%arg) 
#   returns CRITICAL if @{$arg{CRITICAL}}, WARNING if @{$arg{WARNING}}, else OK
#   uses $arg{results} for message if defined, else @{$arg{<STATUS>}}, 
#     where <STATUS> is the return code above
sub exit_results
{
  my (%arg) = @_;
  
  my %keys = map { $_ => 1 } qw(CRITICAL WARNING OK results);
  for (sort keys %arg) {
    croak "[Nagios::Plugin::exit_results] invalid argument $_" unless $keys{$_};
  }

  my $results = '';
  my $delim = ' : ';
  if ($arg{results}) {
    $results = ref $arg{results} eq 'ARRAY' ? 
      join($delim, @{$arg{results}}) : 
      $arg{results};
  }

  if ($arg{CRITICAL} && (ref $arg{CRITICAL} ne 'ARRAY' || @{$arg{CRITICAL}})) {
    &nagios_exit("CRITICAL", $results) if $results;
    &nagios_exit("CRITICAL", join($delim, @{$arg{CRITICAL}})) 
      if $arg{CRITICAL} && ref $arg{CRITICAL} eq 'ARRAY' && @{$arg{CRITICAL}};
    &nagios_exit("CRITICAL", $arg{CRITICAL}) if $arg{CRITICAL};
  }

  elsif ($arg{WARNING} && (ref $arg{WARNING} ne 'ARRAY' || @{$arg{WARNING}})) {
    &nagios_exit("WARNING", $results) if $results;
    &nagios_exit("WARNING", join($delim, @{$arg{WARNING}})) 
      if $arg{WARNING} && ref $arg{WARNING} eq 'ARRAY' && @{$arg{WARNING}};
    &nagios_exit("WARNING", $arg{WARNING}) if $arg{WARNING};
  }

  &nagios_exit("OK", $results) if $results;
  &nagios_exit("OK", join($delim, @{$arg{OK}})) 
    if $arg{OK} && ref $arg{OK} eq 'ARRAY' && @{$arg{OK}};
  &nagios_exit("OK", $arg{OK}) if $arg{OK};
  &nagios_exit("OK", "All okay");
}

# ------------------------------------------------------------------------

1;

__END__

=head1 NAME

Nagios::Plugin - Perl module for creating nagios plugins

=head1 SYNOPSIS

    # Nagios::Plugin exports $PLUGIN, $TIMEOUT, and $VERBOSE variables,
    #   and two subroutines by default: nagios_exit(), and exit_results(). 
    #   nagios_cmp() and load_config() can also be imported explicitly.
    use Nagios::Plugin;
    use Nagios::Plugin qw(:std nagios_cmp load_config);

    # nagios_exit($code, $msg) 
    #   where $code is qw(OK WARNING CRITICAL UNKNOWN DEPENDENT)
    nagios_exit("CRITICAL", "You're ugly and your mother dresses you funny");

    # exit_results - exit based on the given arrays
    exit_results(
      CRITICAL => \@crit,
      WARNING  => \@warn,
      OK       => $ok_message,
    );

    # nagios_cmp($var, $op, $critical, $warning) - comparison function
    #   returns "CRITICAL" if $var $op $critical, "WARNING" if $var $op $warning, 
    #   and "OK" otherwise
    nagios_cmp( $count, '>=', $critical, $warning );
    nagios_exit( nagios_cmp($count, '>=', $critical, $warning), $message);

    # load_config - load $section section of plugins.cfg config file
    #   If not set, $section default to plugin name.
    $config = load_config();
    $config = load_config($section);


=head1 DESCRIPTION

Nagios::Plugin is a perl module for simplifying the creation of 
nagios plugins, mainly by standardising some of the argument parsing
and handling stuff most plugins require.

Nagios::Plugin exports the following variables:

=over 4

=item $PLUGIN 

The name of the plugin i.e. basename($0).
  
=item $TIMEOUT 

The number of seconds before the plugin times out, set via the -t argument.

=item $VERBOSE 

The number of -v arguments to the plugin.
    
=back

Nagios::Plugin also exports two subroutines by default: nagios_exit(), 
for returning a standard Nagios return status plus a message; and 
exit_results(), for checking a set of message arrays and exiting 
appropriately. The following subroutines can also be imported 
explicitly: load_config(), for loading a set of config settings from 
the plugins.cfg config file.

=head2 nagios_exit

Convenience function, to exit with the given nagios status code 
and message:

  nagios_exit(OK => 'query successful');
  nagios_exit("CRITICAL", "You're ugly and your mother dresses you funny");

Valid status codes are "OK", "WARNING", "CRITICAL", "UNKNOWN".


=head2 exit_results

exit_results exits from the plugin after examining a supplied set of 
arrays. Syntax is:

  exit_results(
    CRITICAL => \@crit,
    WARNING  => \@warn,
    OK       => $ok_message,    # or \@ok_messages
  );

exit_results returns 'CRITICAL' if the @crit array is non-empty;
'WARNING' if the @warn array is non-empty; and otherwise 'OK'. The
text returned is typically the joined contents of @crit or @warn or
@ok_messages (or $ok_message).

Sometimes on error or warning you want to return more than just the 
error cases in the returned text. You can do this by passing a
'results' parameter containing the string or strings you want to use
for all status codes e.g.

  # Use the given $results string on CRITICAL, WARNING, and OK
  exit_results(
    CRITICAL => \@crit,
    WARNING  => \@warn,
    results => $results         # or \@results
  );


=head2 nagios_cmp

Comparison function, comparing a variable using the given perl
operator (e.g. 'lt', '<', 'le', '<=', etc.) with the given $critical 
and $warning thresholds. Returns "CRITICAL" if the comparison with 
the $critical threshold succeeds, "WARNING" if the comparison with 
the $warning threshold succeeds, and "OK" otherwise. e.g.

  nagios_cmp(100, '>=', 75, 50);   # returns 'CRITICAL'
  nagios_cmp(50,  '>=', 75, 50);   # returns 'WARNING'
  nagios_cmp(20,  '>=', 75, 50);   # returns 'OK


Note that if you want numeric comparisons you should use the 'symbol' 
ops ('<', '<=', '>', '>=', etc.) rather than the character ones
('lt', 'le', 'gt', 'ge', etc.), just like in perl.



=head2 load_config

Load a hashref of config variables from the given section of the 
plugins.cfg config file. Section defaults to plugin name.
e.g.

  $config = load_config();
  $config = load_config('prod_db');



=head1 CHANGES

Versions prior to 0.03 overrode the standard exit() function instead
of using a separate nagios_exit. This breaks under ePN with Nagios 2.0,
so the change to nagios_exit was made. Thanks to Håkon Løvdal for the
problem report.

The auto-exported $CONFIG variable was removed in 0.04, replaced with
the load_config function, again due to problems running under ePN.


=head1 AUTHOR

Gavin Carr <gavin@openfusion.com.au>


=head1 LICENCE

Copyright 2005-2006 Gavin Carr. All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under either the terms of the Perl Artistic 
License (see http://www.perl.com/perl/misc/Artistic.html)
or the GNU General Public Licence (see 
http://www.fsf.org/licensing/licenses/gpl.txt).

=cut

# arch-tag: 1495e893-2a66-4e61-a8eb-8bfa401b2a4f
# vim:ft=perl:ai:sw=2
