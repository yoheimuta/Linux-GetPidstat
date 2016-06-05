use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;
use Test::Mock::Guard;
use Capture::Tiny qw/capture/;

use Linux::GetPidstat;

my %cli_default_opt = (
    pid_dir       => 't/assets/pid',
    include_child => '1',
    interval      => '60',
    dry_run       => '1'
);

my $guard = Test::Mock::Guard->new(
    'Linux::GetPidstat::Reader' => {
        _command_search_child_pids => sub {
            my ($pid) = shift;
            return "cat t/assets/source/pstree_$pid.txt";
        },
    },
    'Linux::GetPidstat::Collector' => {
        _command_get_pidstat => sub {
            return "cat t/assets/source/metric.txt";
        },
    },
);

my $instance = Linux::GetPidstat->new;

like exception {
    $instance->run;
}, qr/pid_dir required/, "no pid_dir is not allowed";

subtest 'output to a file' => sub {
    my ($stdout, $stderr) = capture {
        $instance->run(%cli_default_opt);
    };
    my @stdout_lines = split /\n/, $stdout;
    is scalar @stdout_lines, 25 or diag $stdout;
    is $stderr, '' or diag $stderr;
};

$cli_default_opt{mackerel_api_key}      = 'dummy_key';
$cli_default_opt{mackerel_service_name} = 'dummy_name';
subtest 'output to a file and mackerel' => sub {
    my ($stdout, $stderr) = capture {
        $instance->run(%cli_default_opt);
    };
    my @stdout_lines = split /\n/, $stdout;
    is scalar @stdout_lines, 43, or diag $stdout;
    is $stderr, '' or diag $stderr;
};

$cli_default_opt{pid_dir} = 't/assets/invalid_pid';
like exception {
    $instance->run(%cli_default_opt);
}, qr/Not found pids in pid_dir:/;

done_testing;
