package NTP::Common;

# Based on Net::NTP, which has the copyright 2009 by Ask Bjørn Hansen; 2004 by James G. Willmore
#
# This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

use strict;
use Exporter 'import';
our(@EXPORT_OK) = qw(NTP_ADJ bin2frac frac2bin unpack_ip);

use constant NTP_ADJ => 2208988800;

sub bin2frac {
  my($bin) = @_;

  my @bin = split '', $bin;
  my $frac = 0;
  while (@bin) {
      $frac = ($frac + pop @bin) / 2;
  }
  $frac *= 10**6; # convert from s to us
  return $frac;
}

sub frac2bin {
  my($frac) = @_;
  my $bin  = '';

  $frac = int($frac * 2**32/10**6);
  while (length($bin) < 32) {
    $bin = ($frac % 2) . $bin;
    $frac = int($frac / 2);
  }
  return $bin;
}

sub unpack_ip {
  my($stratum,$tmp_ip) = @_;

  my $ip;
  if ($stratum < 2) {
    $ip = unpack("A4", pack("H8", $tmp_ip));
  }
  else {
    $ip = sprintf("%d.%d.%d.%d", unpack("C4", pack("H8", $tmp_ip)));
  }
  return $ip;
}

1;
