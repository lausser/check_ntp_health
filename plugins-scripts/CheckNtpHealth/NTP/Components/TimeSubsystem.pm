package CheckNtpHealth::NTP::Components::TimeSubsystem;
our @ISA = qw(CheckNtpHealth::GenericDaemonWithPeers::Components::TimeSubsystem);
use strict;

sub init {
  my ($self) = @_;
  $self->{peers} = [];
  my $process = 0;
  my $ps = "/bin/ps -e -ocmd";
  if ($^O eq "aix") {
    $ps = "/bin/ps -e -ocomm,args";
  } elsif ($^O eq "solaris") {
    $ps = "/bin/ps -e -ocomm,args";
  } elsif ($^O eq "darwin") {
    $ps = "/bin/ps -e -ocomm,args";
  }
  if (open PS, $ps."|") {
    my @procs = <PS>;
    close PS;
    foreach (@procs) {
      $process = 1 if /ntpd/;
    }
  }
  if (! $process) {
    $self->add_critical("ntpd is not running");
    return;
  }
  my $ntpq = -x "/usr/bin/ntpq" ? "/usr/bin/ntpq" : "/usr/sbin/ntpq";
  my $ntpserver = $self->opts->hostname || "";
  if (open(NTPQ, $ntpq." -np ".$ntpserver." 2>&1 |") ) {
    while (<NTPQ>) {
      if (/^(.)(.+?)\s+(.+?)\s+(\d+)\s+(.)\s+((\-)|([\d]+[mhd]*))\s+(\d+[mhd]*)\s+(\d+)\s+(\-*[\d\.]+)\s+(\-*[\d\.]+)\s+(\-*[\d\.]+)/) {
        push(@{$self->{peers}}, CheckNtpHealth::NTP::Components::TimeSubsystem::Peer->new(
            fate => $1,
            remote => $2,
            refid => $3,
            stratum => $4,
            type => $5,
            when => $6,  # includes ($7|$8)
            poll => $9,
            reach => $10,
            delay => $11 / 1000.0,
            offset => $12 / 1000.0,
            jitter => $13 / 1000.0,
            thresholds => $self->{thresholds},
        ));
      } elsif (/===========/ || /remote.*refid.*st.*t.*when.*poll/) {
        # column headers and separator line
      } elsif (/timed out/) {
        $self->add_nagios_critical('ntpq timeout');
        last;
      } elsif (/Connection refused/) {
        $self->add_nagios_critical('ntpq connection refused');
        last;
      } elsif (/No association ID's returned/) {
        $self->add_nagios_critical('ntpq: No association ID\'s returned');
        last;
      } else {
        # 160.50.46.11    160.51.94.15     2 u 136m 1024
        die "cannot parse ".$_;
      }
    }
    close NTPQ;
  } else {
    $self->add_critical(sprintf 'cannot open %s', $ntpq);
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


package CheckNtpHealth::NTP::Components::TimeSubsystem::Peer;
our @ISA = qw(Monitoring::GLPlugin::TableItem);

sub finish {
  my ($self) = @_;
  if ($self->{when} =~ /(\d+)([mhd])/) {
    $self->{when} = $1 * 60 if $2 eq 'm';
    $self->{when} = $1 * 3600 if $2 eq 'h';
    $self->{when} = $1 * 3600 * 24 if $2 eq 'd';
  }
}

# space reject
# The peer is discarded as unreachable, synchronized to this server (synch loop)
# or outrageous synchronization distance.

# x  falsetick
# The peer is discarded by the intersection algorithm as a falseticker.

# .  excess
# The peer is discarded as not among the first ten peers sorted by
# synchronization distance and so is probably a poor candidate for
# further consideration.

# -  outlyer
# The peer is discarded by the clustering algorithm as an outlyer.

# +  candidat
# The peer is a survivor and a candidate for the combining algorithm.

# #  selected
# The peer is a survivor, but not among the first six peers sorted
# by synchronization distance. If the assocation is ephemeral,
# it may be demobilized to conserve resources.

# *  sys.peer
# The peer has been declared the system peer and lends its variables
# to the system variables.

# o  pps.peer
# The peer has been declared the system peer and lends its variables to the
# system variables. However, the actual system synchronization is derived
# from a pulse-per-second (PPS) signal, either indirectly via the PPS
# reference clock driver or directly via kernel interface.

sub is_sys_peer {
  my ($self) = @_;
  if ($self->{refid} eq ".LOCL.") {
  # 10.20.15.45  .XFAC.          16 u    - 1024    0    0.000    0.000   0.000
  # 10.20.15.46  .XFAC.          16 u    - 1024    0    0.000    0.000   0.000
  # 10.20.15.47  .XFAC.          16 u    - 1024    0    0.000    0.000   0.000
  # *127.127.1.0 .LOCL.          10 l   47   64  377    0.000    0.000   0.000
  # sehr schlecht!
    return 0;
  }
  return $self->{fate} eq '*';
}

sub is_pps_peer {
  my ($self) = @_;
  return $self->{fate} eq 'o';
}

sub is_candidate {
  my ($self) = @_;
  return $self->{fate} eq '+';
}

sub is_falsetick {
  my ($self) = @_;
  return $self->{fate} eq 'x';
}

sub is_excess {
  my ($self) = @_;
  return $self->{fate} eq '.';
}

sub is_outlyer {
  my ($self) = @_;
  return $self->{fate} eq '-';
}

sub is_selected {
  my ($self) = @_;
  return $self->{fate} eq '#';
}

sub is_reject {
  my ($self) = @_;
  return $self->{fate} eq ' ';
}

sub check {
  my ($self) = @_;
  if (defined($self->{offset})) {
    $self->add_info(sprintf "Offset %.4f sec", $self->{offset});
    $self->set_thresholds(metric => 'offset', warning => 60, critical => 120);
    $self->add_message($self->check_thresholds(
        metric => 'offset', value => abs($self->{offset})
    ));
    $self->add_perfdata(
      label => 'offset',
      value => $self->{offset},
      places => 4,
      uom => 's',
    );
  }
  if (defined($self->{jitter})) {
    $self->add_info(sprintf "Jitter %.4f sec", $self->{jitter});
    $self->set_thresholds(metric => 'jitter', warning => 5, critical => 10);
    $self->add_message($self->check_thresholds(
        metric => 'jitter', value => abs($self->{jitter})
    ));
    $self->add_perfdata(
      label => 'jitter',
      value => $self->{jitter},
      places => 4,
      uom => 's',
    );
  }
  if (defined($self->{stratum})) {
    $self->add_perfdata(
      label => 'stratum',
      value => $self->{stratum},
    );
  }
  if (! defined($self->{offset}) && ! defined($self->{jitter})) {
    $self->add_unknown("Offset and jitter are unknown");
  }
}

