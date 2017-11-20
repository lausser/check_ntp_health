package Classes::Centrify;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::time/) {
    $self->analyze_and_check_clock_subsystem('Classes::Centrify::Components::TimeSubsystem');
  } else {
    $self->no_such_mode();
  }
}

