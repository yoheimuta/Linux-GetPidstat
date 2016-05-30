use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;
use Test::Mock::Guard;

use Linux::GetPidstat::Reader;

my %opt = (
    pid_dir       => 't/assets/pid',
    include_child => '0',
);

is exception {
    my $instance = Linux::GetPidstat::Reader->new(%opt);
}, undef, "create ok";

my $guard = Test::Mock::Guard->new(
    'Linux::GetPidstat::Reader' => {
        _command_search_child_pids => sub {
            my ($pid) = shift;
            return "cat t/assets/source/pstree_$pid.txt";
        },
    },
);

subtest 'include_child 0' => sub {
    my $instance = Linux::GetPidstat::Reader->new(%opt);
    my $mapping  = $instance->get_program_pid_mapping;
    is scalar @$mapping, 2 or diag explain $mapping;

    my $got;
    for my $info (@$mapping) {
        my $program_name = $info->{program_name};
        my $pid          = $info->{pid};
        push @{$got->{$program_name}}, $pid;
    }
    is_deeply [sort { $a <=> $b } @{$got->{target_script}}] , [1] or diag explain $got;
    is_deeply [sort { $a <=> $b } @{$got->{target_script2}}], [2] or diag explain $got;
};

$opt{include_child} = 1;
subtest 'include_child 1' => sub {
    my $instance = Linux::GetPidstat::Reader->new(%opt);
    my $mapping  = $instance->get_program_pid_mapping;
    is scalar @$mapping, 7 or diag explain $mapping;

    my $got;
    for my $info (@$mapping) {
        my $program_name = $info->{program_name};
        my $pid          = $info->{pid};
        push @{$got->{$program_name}}, $pid;
    }

    is_deeply [sort { $a <=> $b } @{$got->{target_script}}] , [1] or diag explain $got;
    is_deeply [sort { $a <=> $b } @{$got->{target_script2}}],
        [2, 18352, 18353, 18360, 18366, 28264] or diag explain $got;
};

done_testing;
