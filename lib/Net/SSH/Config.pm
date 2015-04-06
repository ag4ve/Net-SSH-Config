package Net::SSH::Config;

use strict;
use warnings;
use 5.010;

use Data::Dumper;

use File::HomeDir;

our $VERSION = '0.01';
 
=encoding utf8

=head1 NAME

Net::SSH::Config - module for parsing ssh_config file(s).

=head1 SYNOPSIS

  use Data::Dumper;
  use Net::SSH::Config

  my $config = Net::SSH::Config->new;
  print Dumper($config->get_options("host", "user"));

=head1 DESCRIPTION

.

=cut

sub new
{
  my ($oClass, $hParams) = @_;

  $hParams //= {};

  my $oSelf = bless $hParams, $oClass;

  while (my ($key, $value) = each %{$hParams})
  {
    $oSelf->{$key} = $value;
  }

  return $oSelf;
}

sub _store_new_file
{
  my ($oSelf, $file) = @_;

  my $oFH = $oSelf->_get_fh($file);

  return $oSelf->store_parsed($oFH);
}

sub _get_fh
{
  my ($oSelf, $file) = @_;

  open (my $oFH, "<", "$file") or
    die "Unable to read $file: $!\n";

  return $oFH;
}

sub _default_fh
{
  my ($oSelf) = @_;

  return $oSelf->_get_fh(File::HomeDir->my_home . "/.ssh/config");
}

# TODO Should go through default paths for the config file
sub _choose_fh
{
  my ($oSelf, $file) = @_;

  my $oFH;
  if (defined($file))
  {
    $oFH = $oSelf->_get_fh($file);
  }
  elsif (exists($oSelf->{fh}))
  {
    $oFH = $oSelf->{fh};
  }
  else
  {
    $oFH = $oSelf->_default_fh();
  }

  return $oFH;
}

=head1 get_data([$file])

Return parsed data from a file

=cut

sub get_data
{
  my ($oSelf, $file) = @_;

  my $oFH = $oSelf->_choose_fh($file);

  return $oSelf->parse($oFH);
}

=head1 store_parsed($oFH)

Add data to internal structure

=cut

sub store_parsed
{
  my ($oSelf, $oFH) = @_;

  $oSelf->{data} //= [];
  my $sPreCount = scalar(@{$oSelf->{data}});

  push @{$oSelf->{data}}, $oSelf->parse($oFH);

  return (scalar(@{$oSelf->{data}}) - $sPreCount);
}

=head2 parse($oFH)

Determine which file to parse and return a data structure

=cut

# TODO Allow a string of config data to be passed
sub parse
{
  my ($oSelf, $oFH) = @_;

  die "Not a valid file handle\n" 
    if (not defined($oFH) or ref($oFH) ne 'GLOB');

  my $paData;
  while (my $sLine = <$oFH>)
  {
    chomp($sLine);
    # Blank line or comment
    next if ($sLine =~ /^[\t ]*(?:#.*)?$/);
    $sLine =~ s/^[\t ]*//;
    $sLine =~ s/[\t ]*$//;
    if ($sLine =~ /^host (.*)$/i)
    {
      my $sHosts = my $sOrig = $1;
      $sHosts =~ s/ +/ /g; # No multiple spaces
      my @aHosts = split(",", $sHosts);
      $sHosts =~ s/ /\|/g; # Replace space with regex OR
      $sHosts =~ s/\*/\.\*/g; # Replace * with ssh .*
      push @$paData, {
        'regex' => $sHosts,
        'hosts' => [@aHosts],
        'orig'  => $sOrig,
      };
    }
    elsif (ref($paData) eq 'ARRAY' and scalar(@$paData) and 
      exists($paData->[-1]{orig}) and 
      $sLine =~ /^([^ ]+) ([^ ]+.*)/)
    {
      # TODO Check valid parameters
      $paData->[-1]{$1} = $2;
    }
    elsif ($sLine =~ /^([^ ]+) ([^ ]+.*)/)
    {
      $paData->[0]{$1} = $2;
    }
    else
    {
      warn "There was a parser error with: " .
        " at line [$.] $sLine.\n";
    }
  }

  return $paData;
}

sub get_options
{
  my ($oSelf, $sHost, $sOpt) = @_;

  return "Bad hostname [$sHost]" if ($sHost =~ /[^a-zA-Z0-9*.:-]+/);

  my $paParseData;
  if (exists($oSelf->{data}) and scalar(@{$oSelf->{data}}))
  {
    $paParseData = $oSelf->{data};
  }
  else
  {
    $paParseData = $oSelf->get_data();
  }

  my $phData;
  foreach my $phHost (@{$paParseData})
  {
    next if ($sHost !~ /($phHost->{regex})/);
    foreach my $sKey (keys %{$phHost})
    {
      my $sLowerKey = lc($sKey);
      if ($sLowerKey =~ /identityfile/)
      {
        push @{$phData->{$sLowerKey}}, $phHost->{$sKey};
        $phData->{_data}{$phHost->{orig}}{'IdentityFile'}++;
      }
      elsif (not exists($phData->{$sLowerKey}))
      {
        $phData->{$sLowerKey} = $phHost->{$sKey};
        $phData->{_data}{$phHost->{orig}}{$sKey} = $phHost->{$sKey};
      }
    }
  }

  if (defined($sOpt))
  {
    my $sLowerOpt = lc($sOpt);
    return ($phData->{$sLowerOpt} // undef);
  }
  else
  {
    return $phData;
  }
}

  
1;

__END__

=head1 AUTHOR

Shawn Wilson E<lt>swilson@korelogic.comE<gt>

=head1 COPYRIGHT

Copyright 2014 - Shawn Wilson

=head1 LICENSE

The GNU Lesser General Public License, version 3.0 (LGPL-3.0)
http://opensource.org/licenses/LGPL-3.0

