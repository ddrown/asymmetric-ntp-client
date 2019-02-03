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

sub is_kod {
  my($self) = @_;

  return(($self->stratum() == 0) and ($self->ident() eq "RATE"));
}

sub ident {
  my($self) = @_;

  if($self->{stratum} < 2) {
    return sprintf("%c%c%c%c", $self->{"ident"} >> 24, ($self->{"ident"} >> 16) & 0xff, ($self->{"ident"} >> 8) & 0xff, $self->{"ident"} & 0xff);
  } else {
    return sprintf("%d.%d.%d.%d", $self->{"ident"} >> 24, ($self->{"ident"} >> 16) & 0xff, ($self->{"ident"} >> 8) & 0xff, $self->{"ident"} & 0xff);
  }
}

sub stratum {
  my($self) = @_;

  return $self->{"stratum"};
}

sub _format_ts {
  my($self,$ts) = @_;
  return sprintf("%d.%06d",$ts->[0],$ts->[1]); # full timestamp as float hits precision limits
}

sub local_transmit_time {
  my($self) = @_;
  return $self->_format_ts($self->{"Local Transmit Time"});
}

sub local_transmit_time_after_processing {
  my($self) = @_;
  return $self->_format_ts($self->{"sent2"});
}

sub local_recv_time {
  my($self) = @_;
  return $self->_format_ts($self->{"Local Recv Time"});
}

sub remote_transmit_time {
  my($self) = @_;
  return $self->_format_ts($self->{"Remote Transmit Time"});
}

sub remote_recv_time {
  my($self) = @_;
  return $self->_format_ts($self->{"Remote Recv Time"});
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

sub local_ts {
  my($self) = @_;

  return $self->{"Local Transmit Time"};
}

sub local_delta {
  my($self,$start) = @_;
  return tv_interval($start, $self->{"Local Transmit Time"});
}

sub leap {
  my($self) = @_;
  return $self->{"byte1"} >> 6;
}
sub version {
  my($self) = @_;
  return ($self->{"byte1"} >> 3) & 0b111;
}
sub mode {
  my($self) = @_;
  return $self->{"byte1"} & 0b111;
}
sub poll {
  my($self) = @_;
  return $self->{"poll"};
}
sub precision {
  my($self) = @_;
  return $self->{"precision"};
}
sub ip {
  my($self) = @_;
  return $self->{"ip"};
}
sub root_delay {
  my($self) = @_;
  return $self->_format_ts([
                $self->{"delay"},
                bin2frac($self->{"delay_fb"})
                ]);
}
sub root_dispersion {
  my($self) = @_;
  return $self->_format_ts([
                $self->{"disp"},
                bin2frac($self->{"disp_fb"})
                ]);
}
sub reference_time {
  my($self) = @_;

  return $self->_format_ts([
      $self->{"ref_time"} - NTP_ADJ(),
      bin2frac($self->{"ref_time_fb"})
      ]);
}
sub originate_time {
  my($self) = @_;

  return $self->_format_ts([
      $self->{"org_time"} - NTP_ADJ(),
      bin2frac($self->{"org_time_fb"})
      ]);
}

1;
