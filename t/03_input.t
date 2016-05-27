use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;

use Linux::GetPidstat::Input;

my %opt = (
    pid_dir       => './pid',
    include_child => '0',
    dry_run       => '1'
);

is exception {
    my $instance = Linux::GetPidstat::Input->new(%opt);
}, undef, "create ok";

subtest 'include_child 0' => sub {
    my $instance = Linux::GetPidstat::Input->new(%opt);
    my $pids_info = $instance->get_pids;
    is scalar @$pids_info, 2 or diag explain $pids_info;

    my $got;
    for my $info (@$pids_info) {
        while (my ($cmd_name, $pid) = each %$info) {
            push @{$got->{$cmd_name}}, $pid;
        }
    }
    is_deeply [sort { $a <=> $b } @{$got->{target_script}}] , [1] or diag explain $got;
    is_deeply [sort { $a <=> $b } @{$got->{target_script2}}], [2] or diag explain $got;
};

$opt{include_child} = 1;
subtest 'include_child 1' => sub {
    my $instance = Linux::GetPidstat::Input->new(%opt);
    my $pids_info = $instance->get_pids;
    is scalar @$pids_info, 7 or diag explain $pids_info;

    my $got;
    for my $info (@$pids_info) {
        while (my ($cmd_name, $pid) = each %$info) {
            push @{$got->{$cmd_name}}, $pid;
        }
    }
    is_deeply [sort { $a <=> $b } @{$got->{target_script}}] , [1] or diag explain $got;
    is_deeply [sort { $a <=> $b } @{$got->{target_script2}}],
        [2, 18352, 18353, 18360, 18366, 28264] or diag explain $got;
};

done_testing;
