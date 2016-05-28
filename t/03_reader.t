use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;

use Linux::GetPidstat::Reader;

my %opt = (
    pid_dir       => './pid',
    include_child => '0',
    dry_run       => '1'
);

is exception {
    my $instance = Linux::GetPidstat::Reader->new(%opt);
}, undef, "create ok";

subtest 'include_child 0' => sub {
    my $instance = Linux::GetPidstat::Reader->new(%opt);
    my $mapping  = $instance->get_cmd_pid_mapping;
    is scalar @$mapping, 2 or diag explain $mapping;

    my $got;
    for my $info (@$mapping) {
        my $cmd_name    = $info->{cmd};
        my $pid         = $info->{pid};
        push @{$got->{$cmd_name}}, $pid;
    }
    is_deeply [sort { $a <=> $b } @{$got->{target_script}}] , [1] or diag explain $got;
    is_deeply [sort { $a <=> $b } @{$got->{target_script2}}], [2] or diag explain $got;
};

$opt{include_child} = 1;
subtest 'include_child 1' => sub {
    my $instance = Linux::GetPidstat::Reader->new(%opt);
    my $mapping  = $instance->get_cmd_pid_mapping;
    is scalar @$mapping, 7 or diag explain $mapping;

    my $got;
    for my $info (@$mapping) {
        my $cmd_name    = $info->{cmd};
        my $pid         = $info->{pid};
        push @{$got->{$cmd_name}}, $pid;
    }

    is_deeply [sort { $a <=> $b } @{$got->{target_script}}] , [1] or diag explain $got;
    is_deeply [sort { $a <=> $b } @{$got->{target_script2}}],
        [2, 18352, 18353, 18360, 18366, 28264] or diag explain $got;
};

done_testing;
