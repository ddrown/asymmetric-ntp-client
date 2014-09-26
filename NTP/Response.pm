package NTP::Response;

# This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

use strict;
use Time::HiRes qw(tv_interval);
use NTP::Common qw(bin2frac NTP_ADJ);

sub new {
  my $class = shift;
  my $self = {@_};
  bless($self,$class);
  $self->_process();
  return $self;
}

sub _process {
  my($self) = @_;

  $self->{"Local Transmit Time"} = $self->{"sent"};
  $self->{"Local Recv Time"} = $self->{"recv"};

  $self->{"Remote Recv Time"} = [
	$self->{"recv_time"} - NTP_ADJ(),
	bin2frac($self->{"recv_time_fb"})
	];
  $self->{"Remote Transmit Time"} = [
	$self->{"trans_time"} - NTP_ADJ(),
	bin2frac($self->{"trans_time_fb"})
	];
}

sub stratum {
  my($self) = @_;

  return $self->{"stratum"};
}

sub local_transmit_time {
  my($self) = @_;
  return $self->{"Local Transmit Time"}[0] + $self->{"Local Transmit Time"}[1] / 1000000;
}

sub local_transmit_time_after_processing {
  my($self) = @_;
  return $self->{"sent2"}[0] + $self->{"sent2"}[1] / 1000000;
}

sub local_recv_time {
  my($self) = @_;
  return $self->{"Local Recv Time"}[0] + $self->{"Local Recv Time"}[1] / 1000000;
}

sub remote_transmit_time {
  my($self) = @_;
  return $self->{"Remote Transmit Time"}[0] + $self->{"Remote Transmit Time"}[1] / 1000000;
}

sub remote_recv_time {
  my($self) = @_;
  return $self->{"Remote Recv Time"}[0] + $self->{"Remote Recv Time"}[1] / 1000000;
}

sub rtt {
  my($self) = @_;

  return tv_interval($self->{"Local Transmit Time"},$self->{"Local Recv Time"});
}

sub turn_around {
  my($self) = @_;

  return tv_interval($self->{"Remote Recv Time"},$self->{"Remote Transmit Time"});
}

sub offset {
  my($self) = @_;

  my $rtt = $self->rtt();
  my $offset = tv_interval($self->{"Local Transmit Time"},$self->{"Remote Recv Time"}) - $rtt/2;
  $offset -= tv_interval($self->{"Remote Recv Time"},$self->{"Remote Transmit Time"}); # remove any delay from processing

  return $offset;
}

sub request {
  my($self) = @_;

  return tv_interval($self->{"Local Transmit Time"},$self->{"Remote Recv Time"});
}

sub response {
  my($self) = @_;

  return tv_interval($self->{"Remote Transmit Time"},$self->{"Local Recv Time"});
}

sub when {
  my($self) = @_;

  return $self->{"Local Transmit Time"}[0];
}

1;
