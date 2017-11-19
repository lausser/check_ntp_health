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
  };
  if (-x "/usr/bin/chronyc") {
    $techniques->{chrony}++;
  }
  if (-x "/usr/bin/ntpq" || -x "/usr/sbin/ntpq") {
    $techniques->{ntp}++;
  }
  if (open PS, "/bin/ps -e -ocmd|") {
    my @procs = <PS>;
    close PS;
    foreach (@procs) {
      $techniques->{ntp}++ if /ntpd/;
      $techniques->{chrony}++ if /chrony/;
    }
  }
  if ($techniques->{chrony} == $techniques->{ntp} &&
      $techniques->{ntp} == 0) {
    $self->add_unknown("no known time daemon found");
  } elsif ($techniques->{chrony} >= $techniques->{ntp}) {
    $self->{productname} = "chronyc";
  } else {
    $self->{productname} = "ntp";
  }
}

