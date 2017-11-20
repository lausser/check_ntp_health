package Classes::GenericDaemonWithPeers::Components::TimeSubsystem;
our @ISA = qw(Monitoring::GLPlugin::Item);
use strict;

sub check {
  my ($self) = @_;
  if (! $self->check_messages()) {
    if (my $sync_peer = $self->get_sync_peer()) {
      $sync_peer->check();
    } elsif (my @candidates = $self->get_candidates()) {
      foreach (@candidates) {
        $_->check();
      }
      $self->add_warning('no sync peer, only candidates');
    } else {
      $self->add_warning('no sync peer, no candidates. ');
    }
  }
}

sub get_sync_peer {
  my ($self) = @_;
  my @sync_peers = grep {
      $_->is_sys_peer() || $_->is_pps_peer() 
  } @{$self->{peers}};
  if (@sync_peers) {
    return $sync_peers[0];
  } else {
    return undef;
  }
}

sub get_candidates {
  my ($self) = @_;
  return grep { $_->is_candidate() } @{$self->{peers}};
}


