package Classes::Device;
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
        bless $self, 'Classes::NTP';
        $self->debug('using Classes::NTP');
      } elsif ($self->{productname} =~ /chrony/) {
        bless $self, 'Classes::Chrony';
        $self->debug('using Classes::Chrony');
      } elsif ($self->{productname} =~ /centrify/) {
        bless $self, 'Classes::Centrify';
        $self->debug('using Classes::Centrify');
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
    $techniques->{chrony}++;
  }
  if (-x "/usr/bin/ntpq" || -x "/usr/sbin/ntpq") {
    $techniques->{ntp}++;
  }
  my $ps = "/bin/ps -e -ocmd";
  if ($^Oeq "aix") {
    $ps = "/bin/ps -e -ocomm,args";
  }
  if (open PS, $ps."|") {
    my @procs = <PS>;
    close PS;
    foreach (@procs) {
      $techniques->{ntp}++ if /ntpd(?!:)/; # NO ntpd: asynchronous dns resolver
      $techniques->{chrony}++ if /chrony/;
      $techniques->{centrify}++ if /centrify/;
    }
  }
  if (-x "/usr/share/centrifydc/bin/adcheck") {
    if (-f "/etc/centrifydc/centrifydc.conf") {
      if (open(CENTRIFY, "/etc/centrifydc/centrifydc.conf")) {
        foreach (<CENTRIFY>) {
          $techniques->{centrify} = 0 if /^\s*adclient\.sntp\.enabled:\s+false/;
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
    } else {
      $self->{productname} = "centrify";
    }
  } else {
    $self->{productname} = $technique;
    if ($techniques->{centrify} != 0) {
      $self->{productname} .= "_and_centrify";
    }
  }
}

