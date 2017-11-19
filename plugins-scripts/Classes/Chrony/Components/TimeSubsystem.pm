package Classes::Chrony::Components::TimeSubsystem;
our @ISA = qw(Classes::GenericDaemonWithPeers::Components::TimeSubsystem);
use strict;

sub init {
  my ($self) = @_;
  $self->{peers} = [];
  my $chronyc = "/usr/bin/chronyc";
  if (open(NTPQ, $chronyc." sources 2>&1 |") ) {
    my $peer = {};
    while (<NTPQ>) {
      chomp;
      if (/^(.)(.)\s+([^\s]+?)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+?)\s+([+-]*\d+[\w]+)\s*\[\s*([+-]*\d+[\w]+)\]\s+\+\/\-\s+(\d+\w+)/) {
        push(@{$self->{peers}}, Classes::Chrony::Components::TimeSubsystem::Peer->new(
            mode => $1,
            state => $2,
            refid => $3,
            stratum => $4,
            poll => $5,
            reach => $6,
            lastrx => $7,
            adjusted => $8,
            measured => $9,
            error => $10,
            thresholds => $self->{thresholds},
        ));
      }
    }
    close NTPQ;
  } else {
    $self->add_critical(sprintf 'cannot open %s', $chronyc);
  }
}


package Classes::Chrony::Components::TimeSubsystem::Peer;
our @ISA = qw(Monitoring::GLPlugin::TableItem);

sub finish {
  my ($self) = @_;
  if ($self->{measured} =~ /([\+\-])(\d+)([nums])/) {
    $self->{measured} = $2 / 1000000000  if $3 eq 'n';
    $self->{measured} = $2 / 1000000  if $3 eq 'u';
    $self->{measured} = $2 / 1000  if $3 eq 'm';
    $self->{measured} *= -1 if $1 eq "-";
  }
}

sub synched {
  my ($self) = @_;
  return $self->{state} eq '*';
}

sub is_server {
  my ($self) = @_;
  return $self->{mode} eq '^';
}

sub is_peer {
  my ($self) = @_;
  return $self->{mode} eq '=';
}

sub is_candidate {
  my ($self) = @_;
  return $self->{state} eq '+';
}

sub check {
  my ($self) = @_;

  if (defined($self->{measured})) {
    $self->add_info(sprintf "Offset %.4f sec", $self->{measured});
    $self->set_thresholds(metric => 'offset', warning => 60, critical => 120);
    $self->add_message($self->check_thresholds(
        metric => 'offset', value => abs($self->{offset})
    ));
    $self->add_perfdata(
      label => 'offset',
      value => $self->{measured},
      places => 4,
      uom => 's',
    );
  } else {
    $self->add_unknown("Measured offset is unknown");
  }
}

