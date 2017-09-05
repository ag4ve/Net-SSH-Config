#!perl

use strict;
use warnings;

use lib 't';
use Util;

use Net::SSH::Config;

my $oConfig = Net::SSH::Config->new({
    "file" => "./t/config.0",
    "host" => "foo",
    "attr" => "IdentityFile",
  });

my $paTests = [
   [[$oConfig->{file}], "./config.0", "Config file defined."],
   [[$oConfig->{host}], "foo", "Host defined."],
   [[$oConfig->{attr}], "IdentityFile", "Attr defined."],
   [[$oConfig->parse()], "~/.ssh/id_rsa", "Print IdentityFile."],
   [[$oConfig->parse(attr => "User")], "doe", "Print User."],
   [[$oConfig->parse(attr => "Port")], "22", "Print Port."],
];

test($paTests);
