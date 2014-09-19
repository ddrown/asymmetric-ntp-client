package NTP::Client;

# Based on Net::NTP, which has the copyright 2009 by Ask Bjørn Hansen; 2004 by James G. Willmore
#
# This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

use strict;
use Socket;
use Socket6;
use Time::HiRes qw(gettimeofday tv_interval);
use IO::Socket::INET6;
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
  @tmp_pkt{@ntp_fields} = unpack("a C3   n B16 n B16 H8   N B32 N B32   N B32 N B32", $data);

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

    my($actual_port,$actual_ip) = unpack_sockaddr_in6($from);
    $actual_ip = inet_ntop(AF_INET6,$actual_ip);
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
  my($self,$hostname) = @_;

  my @results = getaddrinfo($hostname, "ntp", AF_INET6, SOCK_DGRAM, "udp");
  if(@results == 1) {
    die("".$results[0]);
  }
  if($results[0] != AF_INET6) {
    die("type $results[0] != ".AF_INET6 );
  }
  $self->{family} = $results[0];
  $self->{type} = $results[1];
  $self->{protocol} = $results[2];
  $self->{addr} = $results[3];

  my($expected_port,$expected_ip) = unpack_sockaddr_in6($self->{addr});
  $self->{expected_ip} = inet_ntop(AF_INET6,$expected_ip);

  if(not defined $self->{"socket"}) {
    socket($self->{"socket"}, $self->{family}, $self->{type}, $self->{protocol});
  }
}

1;
