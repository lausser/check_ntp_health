package Classes::Centrify::Components::TimeSubsystem;
our @ISA = qw(Monitoring::GLPlugin::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->trace("running /usr/bin/adinfo --domain");
  open(ADINFO, "/usr/bin/adinfo --domain|");
  my @domains = <ADINFO>;
  close ADINFO;
  if (@domains) {
    chomp($self->{domain} = $domains[0]);
  }
  if ($self->{domain} && $self->{domain} =~ /^[\w\.\-_]+$/) {
    $self->create_statefilesdir();
    my $cmd = sprintf "/usr/share/centrifydc/bin/adcheck %s --alldc --test ad --bigdomain 1 --tmp_path %s", $self->{domain}, $self->statefilesdir();
    $self->trace("running ".$cmd);
    open(ADCHECK, $cmd."|");
    my @checks = <ADCHECK>;
    close ADCHECK;
    foreach (@checks) {
      chomp;
      if (/^TIME.*Check clock synchronization.*:\s*(.*)/) {
        $self->{clock_sync} = lc $1;
      }
    }
    if (! $self->{clock_sync}) {
      $self->{clock_sync} = "failed";
    }
  } else {
    $self->{domain} = "adinfo error: ".$self->{domain};
  }
}

sub check {
  my ($self) = @_;
  $self->add_info("domain: ". $self->{domain});
  if ($self->{domain} =~ /^adinfo error/) {
    $self->add_critical($self->{domain});
  } else {
    $self->add_info("clock (centrify sntp) synchronization status: ".$self->{clock_sync});
    if ($self->{clock_sync} ne "pass") {
      $self->add_critical();
    } else {
      $self->add_ok("clock (centrify sntp) is in sync with domain ". $self->{domain});
    }
  }
}

