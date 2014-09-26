package NTP::Client;

# Based on Net::NTP, which has the copyright 2009 by Ask Bjørn Hansen; 2004 by James G. Willmore
#
# This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

use strict;
use Socket qw(AF_INET AF_INET6 SOCK_DGRAM unpack_sockaddr_in);
use Socket6 qw(getaddrinfo unpack_sockaddr_in6 inet_ntop);
use Time::HiRes qw(gettimeofday tv_interval);
use NTP::Response;
use NTP::Common qw(NTP_ADJ frac2bin);

sub new {
  my $class = shift;
  my $self = {};
  bless($self,$class);

  return $self;
}

sub _time_to_pkt {
  my($self,$time) = @_;

  my $client_localtime      = $time;
  my $client_adj_localtime  = $client_localtime->[0] + NTP_ADJ;
  my $client_frac_localtime = frac2bin($client_localtime->[1]);

  return pack("B8 C3 N10 B32", '00011011', (0) x 12, $client_adj_localtime, $client_frac_localtime);
}

sub _pkt_to_raw {
  my($self,$data) = @_;

  my(%tmp_pkt);
  my(@ntp_fields) = qw/byte1 stratum poll precision delay delay_fb disp disp_fb ident ref_time ref_time_fb org_time org_time_fb recv_time recv_time_fb trans_time trans_time_fb/;
  @tmp_pkt{@ntp_fields} = unpack("a C3   n B16 n B16 N   N B32 N B32   N B32 N B32", $data);

  return %tmp_pkt;
}

sub get_ntp_response {
  my($self) = @_;

  my $data;

  my($sent,$sent2,$recv);
  my $ntp_msg = $self->_time_to_pkt([gettimeofday]);

  $sent = [gettimeofday];
  send($self->{"socket"},$ntp_msg,0,$self->{"addr"}) or die "send() failed: $!\n";
  $sent2 = [gettimeofday];

  eval {
    local $SIG{ALRM} = sub { die "Net::NTP timed out geting NTP packet\n"; };
    alarm(60);
    my $from = recv($self->{"socket"},$data,960,0)
      or die "recv() failed: $!\n";
    $recv = [gettimeofday];
    alarm(0);

    my($actual_port,$actual_ip);
    if($self->{family} == AF_INET6) {
      ($actual_port,$actual_ip) = unpack_sockaddr_in6($from);
    } else {
      ($actual_port,$actual_ip) = unpack_sockaddr_in($from);
    }
    $actual_ip = inet_ntop($self->{family},$actual_ip);
    if($actual_ip ne $self->{expected_ip}) {
      die("expected $self->{expected_ip} got $actual_ip");
    }
  };

  if ($@) {
    die "$@";
  }

  my %raw_pkt = $self->_pkt_to_raw($data);

  $raw_pkt{"sent"} = $sent;
  $raw_pkt{"sent2"} = $sent2;
  $raw_pkt{"recv"} = $recv;

  return NTP::Response->new(%raw_pkt);
}

sub lookup {
  my($self,$hostname,$force_proto) = @_;

  if($force_proto eq "inet6") {
    $force_proto = AF_INET6;
  } elsif($force_proto eq "inet") {
    $force_proto = AF_INET;
  } else {
    $force_proto = 0;
  }

  my @results = getaddrinfo($hostname, "ntp", $force_proto, SOCK_DGRAM, "udp");
  if(@results == 1) {
    die("".$results[0]);
  }

  if(defined($self->{"socket"}) and $self->{family} != $results[0]) { # family changed
    warn("address family changed from $self->{family} to $results[0]\n");

    close($self->{"socket"});
    $self->{"socket"} = undef;
  }

  $self->{family} = $results[0];
  $self->{type} = $results[1];
  $self->{protocol} = $results[2];
  $self->{addr} = $results[3];

  my($expected_port,$expected_ip);
  if($self->{family} == AF_INET6) {
    ($expected_port,$expected_ip) = unpack_sockaddr_in6($self->{addr});
  } else {
    ($expected_port,$expected_ip) = unpack_sockaddr_in($self->{addr});
  }
  $self->{expected_ip} = inet_ntop($self->{family},$expected_ip);

  if(not defined $self->{"socket"}) {
    socket($self->{"socket"}, $self->{family}, $self->{type}, $self->{protocol});
  }
}

1;
