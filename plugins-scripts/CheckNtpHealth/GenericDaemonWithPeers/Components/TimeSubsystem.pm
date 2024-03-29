package CheckNtpHealth::GenericDaemonWithPeers::Components::TimeSubsystem;
our @ISA = qw(Monitoring::GLPlugin::Item);
use strict;

sub check {
  my ($self) = @_;
  (my $type = ref($self)) =~ s/CheckNtpHealth::(.*?)::.*/$1/g;
  if (! $self->check_messages()) {
    if (my $sync_peer = $self->get_sync_peer()) {
      $sync_peer->check();
    } elsif (my @candidates = $self->get_candidates()) {
      foreach (@candidates) {
        $_->check();
      }
      $self->add_warning(sprintf 'no %s sync peer/server, only candidates', lc $type);
    } else {
      $self->add_warning(sprintf 'no %s sync peer/server, no candidates', lc $type);
    }
  }
}


