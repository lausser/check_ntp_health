package CheckNtpHealth::Centrify;
our @ISA = qw(CheckNtpHealth::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::time/) {
    $self->analyze_and_check_clock_subsystem('CheckNtpHealth::Centrify::Components::TimeSubsystem');
  } else {
    $self->no_such_mode();
  }
}

