package CheckNtpHealth::Device;
our @ISA = qw(Monitoring::GLPlugin);
use strict;

sub classify {
  my $self = shift;
  if (1) {
    $self->check_ntp_method();
    if (! $self->check_messages()) {
      if ($self->opts->verbose && $self->opts->verbose) {
        printf "I am a %s\n", $self->{productname};
      }
      if ($self->opts->mode =~ /^my-/) {
        $self->load_my_extension();
      } elsif ($self->{productname} =~ /ntp/) {
        bless $self, 'CheckNtpHealth::NTP';
        $self->debug('using CheckNtpHealth::NTP');
      } elsif ($self->{productname} =~ /chrony/) {
        bless $self, 'CheckNtpHealth::Chrony';
        $self->debug('using CheckNtpHealth::Chrony');
      } elsif ($self->{productname} =~ /centrify/) {
        bless $self, 'CheckNtpHealth::Centrify';
        $self->debug('using CheckNtpHealth::Centrify');
      } else {
        $self->no_such_device();
      }
    }
  }
  return $self;
}

sub check_ntp_method {
  my $self = shift;
  my $techniques = {
    "chrony" => 0,
    "ntp" => 0,
    "centrify" => 0,
  };
  if (-x "/usr/bin/chronyc") {
    $self->debug("found a chronyc");
    $techniques->{chrony}++;
  }
  if (-x "/usr/bin/ntpq" || -x "/usr/sbin/ntpq") {
    $self->debug("found a ntpq");
    $techniques->{ntp}++;
  }
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
      $techniques->{ntp}++ if /ntpd(?!:)/; # NO ntpd: asynchronous dns resolver
      $techniques->{chrony}++ if /chrony/;
      $techniques->{centrify}++ if /centrify/;
      $self->debug("found a ntpd process") if /ntpd(?!:)/;
      $self->debug("found a chrony process") if /chrony/;
      $self->debug("found a centrify process") if /centrify/;
    }
  }
  if (-x "/usr/share/centrifydc/bin/adcheck") {
    if (-f "/etc/centrifydc/centrifydc.conf") {
      $self->debug("found a centrifydc config");
      if (open(CENTRIFY, "/etc/centrifydc/centrifydc.conf")) {
        foreach (<CENTRIFY>) {
          $techniques->{centrify} = 0 if /^\s*adclient\.sntp\.enabled:\s+false/;
          $self->{centrify_disabled} = 1 if /^\s*adclient\.sntp\.enabled:\s+false/;
        }
        close CENTRIFY;
      }
    }
  }
  my @sorted_techniques = reverse sort {
    $techniques->{$a} <=> $techniques->{$b}
  } grep {
    $_ ne "centrify";
  } keys %{$techniques};
  my $technique = $sorted_techniques[0];
  if ($techniques->{$technique} == 0) {
    if ($techniques->{centrify} == 0) {
      $self->add_unknown("no known time daemon found");
      $self->add_ok("centrify sntp is disabled") if $self->{centrify_disabled};
    } else {
      $self->{productname} = "centrify";
    }
  } else {
    $self->{productname} = $technique;
    if ($techniques->{centrify} != 0) {
      $self->{productname} .= "_and_centrify";
    }
  }
  $self->debug("the technique used is ".($self->{productname} || "-none-"));
}

