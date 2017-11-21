package Classes::GenericDaemonWithPeers;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my ($self) = @_;
  (my $type = ref($self)) =~ s/Classes::(.*?)/$1/g;
  if ($self->mode =~ /device::time/) {
    $self->analyze_and_check_clock_subsystem(ref($self).'::Components::TimeSubsystem');
    my ($code, $message) = $self->check_messages();
    if ($code && $self->{productname} =~ /centrify/) {
      $self->clear_messages(1);
      $self->clear_messages(2);
      $self->analyze_and_check_clock_subsystem('Classes::Centrify::Components::TimeSubsystem');
      $self->add_ok(sprintf "(%s check said: %s)", lc $type, $message);
    }
  } else {
    $self->no_such_mode();
  }
}

