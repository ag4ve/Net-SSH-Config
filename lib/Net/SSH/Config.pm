package Net::SSH::Config;

use strict;
use warnings;
use 5.010;

use Data::Dumper;

use File::HomeDir;

our $VERSION = '0.01';
 
=encoding utf8

=head1 NAME

Net::SSH::Config

=head1 SYNOPSIS

  use Net::SSH::Config

=head1 DESCRIPTION

.

=cut

my $config = File::HomeDir->my_home . "/.ssh/config";
my $raValues = [
  'file',
  'host',
  'attr',
];

sub new
{
  my ($class, $hParams) = @_;

  my $self = bless $hParams, $class;

  $hParams = $self->_new_param($hParams);
  while (my ($key, $value) = each %{$hParams})
  {
    $self->{$key} = $value;
  }
  if ($hParams->{file})
  {
    ($self->{fh}, $self->{mtime}) = $self->_init({}, $hParams);
  }

  return $self;
}

sub _new_param
{
  my ($self, $hParams) = @_;

  my ($ret, $trash);
  foreach my $val (@$raValues)
  {
    ($ret->{$val}) = $self->$val;
  }

  return $ret;
}

sub file
{
  my ($self, $file) = @_;

  my $old_file = $self->{file};
  $file //= $self->{file};

  return ($file, $old_file);
}

sub host
{
  my ($self, $host) = @_;

  my $old_host = $self->{host};
  $host //= $self->{host};

  return ($host, $old_host);
}

sub attr
{
  my ($self, $attr) = @_;

  my $ret;
  $ret = $self->{attr} if (defined($self->{attr}));
  push @$ret, (ref($attr) eq 'ARRAY' ? @{$attr} : $attr)
    if (defined($attr));
  
  return ($ret);
}

sub parse
{
  my ($self, $hParams) = @_;

  my $hTempParams = $self->_new_param($hParams);

  return if (not defined($hTempParams->{host}));

  my ($fh) = $self->_init($hTempParams);
  return if (not defined($fh));

  # Nothing has changed.
  return if (not $fh);

  my ($host, $ret);
  while (my $line = <$fh>)
  {
    # Blank line or comment
    next if ($line =~ /^ *#? *$/);
    if ($line =~ /^ *host (.*)$/i)
    {
      my @hosts_re = map {$_ =~ s/\*/\.\*/r} split(" ", $1);
      $host = (grep {$hTempParams->{host} =~ /\Q$_/} @hosts_re ? 1 : 0);
    }
    elsif ($host and $line =~ /^ *([a-zA-Z0-9]+) (.*)$/)
    {
      $ret->{$1} //= $2;
    }
    else
    {
      warn "There was a parser error with: " . $hTempParams->{file} . 
        " at line [$.] $line.\n";
    }
  }

  return $ret;
}

sub _init
{
  my ($self, $hParams) = @_;

  die "No file specified\n"
    if (not defined($hParams->{file}));

  my $mtime = (stat $hParams->{file})[9];

  if (exists($self->{mtime})
    and $self->{mtime} eq $mtime
    and defined($hParams->{config})
    and defined($self->{config})
    and $self->{config} eq $hParams->{config})
  {
    return 0;
  }

  open(my $fh, "<", $hParams->{config})
    or die "Could not open " . $hParams->{config} . ": $!";

  return ($fh, $mtime);
}
  
1;
