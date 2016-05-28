use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;

use Linux::GetPidstat::Writer;

my %opt = (
    res_file              => '',
    mackerel_api_key      => '',
    mackerel_service_name => '',
    dry_run               => '1',
);

is exception {
    my $instance = Linux::GetPidstat::Writer->new(%opt);
}, undef, "create ok";

done_testing;
