use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;

use Linux::GetPidstat;

my %cli_default_opt = (
    pid_dir       => './pid',
    include_child => '1',
    interval      => '60',
    dry_run       => '1'
);

is exception {
    my $instance = Linux::GetPidstat->new(%cli_default_opt);
}, undef, "create ok";

done_testing;
