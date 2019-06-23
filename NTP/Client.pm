package NTP::Client;

# Based on Net::NTP, which has the copyright 2009 by Ask Bjørn Hansen; 2004 by James G. Willmore
#
# This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

use strict;
use Socket qw(AF_INET AF_INET6 SOCK_DGRAM unpack_sockaddr_in getaddrinfo unpack_sockaddr_in6 inet_ntop SOL_SOCKET MSG_ERRQUEUE MSG_DONTWAIT);
use constant {
  SO_TIMESTAMPING => 37,
  SOF_TIMESTAMPING_SOFTWARE => 1<<4,
  SOF_TIMESTAMPING_TX_SOFTWARE => 1<<1,
  SOF_TIMESTAMPING_RX_SOFTWARE => 1<<3
};
use Socket::MsgHdr;
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

  return pack("B8 C3 N10 B32", '00100011', (0) x 12, $client_adj_localtime, $client_frac_localtime);
}

sub _pkt_to_raw {
  my($self,$data) = @_;

  my(%tmp_pkt);
  my(@ntp_fields) = qw/byte1 stratum poll precision delay delay_fb disp disp_fb ident ref_time ref_time_fb org_time org_time_fb recv_time recv_time_fb trans_time trans_time_fb/;
  @tmp_pkt{@ntp_fields} = unpack("C3c   n B16 n B16 N   N B32 N B32   N B32 N B32", $data);

  return %tmp_pkt;
}

sub _kernel_timestamp {
  my($self,$kernelbytes) = @_;

  my($tv_sec,$tv_nsec) = unpack("qq", $kernelbytes);
  return ($tv_sec, $tv_nsec);
}

sub _msg_to_timestamp {
  my($self,$msg) = @_;

  my @cmsg = $msg->cmsghdr();
  while (my ($level, $type, $data) = splice(@cmsg, 0, 3)) {
    if($level == SOL_SOCKET and $type == SO_TIMESTAMPING) {
      my $kernel_ts = substr($data,0,16,"");
      return $self->_kernel_timestamp($kernel_ts);
    }
  }

  return ();
}

sub get_ntp_response {
  my($self) = @_;

  my($sent,$sent2,$recv,@rx_timestamp,@tx_timestamp);
  my $recvmsg = new Socket::MsgHdr(buflen => 960, namelen => 16, controllen => 256);
  my $sentmsg = new Socket::MsgHdr(buflen => 960, namelen => 16, controllen => 256);
  my $ntp_msg = $self->_time_to_pkt([gettimeofday]);

  $sent = [gettimeofday];
  send($self->{"socket"},$ntp_msg,0,$self->{"addr"}) or die "send() failed: $!\n";
  $sent2 = [gettimeofday];

  eval {
    local $SIG{ALRM} = sub { die "Net::NTP timed out geting NTP packet\n"; };
    alarm(60);
    my $bytes = recvmsg($self->{"socket"},$recvmsg,0)
      or die "recvmsg() failed: $!\n";
    my $sentbytes = recvmsg($self->{"socket"},$sentmsg,MSG_ERRQUEUE|MSG_DONTWAIT)
      or die "recvmsg_errqueue() failed: $!\n";
    $recv = [gettimeofday];
    alarm(0);
    @rx_timestamp = $self->_msg_to_timestamp($recvmsg);
    @tx_timestamp = $self->_msg_to_timestamp($sentmsg);

    my($actual_port,$actual_ip);
    if($self->{family} == AF_INET6) {
      ($actual_port,$actual_ip) = unpack_sockaddr_in6($recvmsg->name);
    } else {
      ($actual_port,$actual_ip) = unpack_sockaddr_in($recvmsg->name);
    }
    $actual_ip = inet_ntop($self->{family},$actual_ip);
    if($actual_ip ne $self->{expected_ip}) {
      die("expected $self->{expected_ip} got $actual_ip");
    }
  };

  if ($@) {
    die "$@";
  }

  my %raw_pkt = $self->_pkt_to_raw($recvmsg->buf);

  if(@tx_timestamp) {
    $tx_timestamp[1] /= 1000; # ns to us
    $raw_pkt{"sent"} = \@tx_timestamp;
  } else {
    $raw_pkt{"sent"} = $sent;
  }
  $raw_pkt{"sent2"} = $sent2;
  if(@rx_timestamp) {
    $rx_timestamp[1] /= 1000; # ns to us
    $raw_pkt{"recv"} = \@rx_timestamp;
  } else {
    $raw_pkt{"recv"} = $recv;
  }
  $raw_pkt{"ip"} = $self->{expected_ip};

  return NTP::Response->new(%raw_pkt);
}

sub lookup {
  my($self,$hostname,$port,$force_proto) = @_;

  if($force_proto eq "inet6") {
    $force_proto = AF_INET6;
  } elsif($force_proto eq "inet") {
    $force_proto = AF_INET;
  } else {
    $force_proto = 0;
  }

  my($err, @results) = getaddrinfo($hostname, $port, {protocol => "udp", socktype => SOCK_DGRAM, family => $force_proto});
  if($err) {
    die("getaddrinfo failed: $err");
  }

  if(defined($self->{"socket"}) and $self->{family} != $results[0]) { # family changed
    warn("address family changed from $self->{family} to $results[0]\n");

    close($self->{"socket"});
    $self->{"socket"} = undef;
  }

  $self->{family} = $results[0]{family};
  $self->{type} = $results[0]{socktype};
  $self->{protocol} = $results[0]{protocol};
  $self->{addr} = $results[0]{addr};

  my($expected_port,$expected_ip);
  if($self->{family} == AF_INET6) {
    ($expected_port,$expected_ip) = unpack_sockaddr_in6($self->{addr});
  } else {
    ($expected_port,$expected_ip) = unpack_sockaddr_in($self->{addr});
  }
  $self->{expected_ip} = inet_ntop($self->{family},$expected_ip);

  if(not defined $self->{"socket"}) {
    socket($self->{"socket"}, $self->{family}, $self->{type}, $self->{protocol});
    setsockopt($self->{"socket"}, SOL_SOCKET, SO_TIMESTAMPING, SOF_TIMESTAMPING_SOFTWARE|SOF_TIMESTAMPING_TX_SOFTWARE|SOF_TIMESTAMPING_RX_SOFTWARE);
  }
}

1;
