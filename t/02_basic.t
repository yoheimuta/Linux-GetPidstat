use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;
use Capture::Tiny qw/capture/;
use Data::Section::Simple qw(get_data_section);

use Linux::GetPidstat;

my %cli_default_opt = (
    pid_dir       => './pid',
    include_child => '1',
    interval      => '60',
    dry_run       => '1'
);

subtest 'output to a file' => sub {
    my $instance = Linux::GetPidstat->new(%cli_default_opt);
    my ($stdout, $stderr) = capture {
        $instance->run;
    };
    my @stdout_lines = split /\n/, $stdout;
    is scalar @stdout_lines, 25 or diag @stdout_lines;
    is $stderr, '';
};

$cli_default_opt{mackerel_api_key}      = 'dummy_key';
$cli_default_opt{mackerel_service_name} = 'dummy_name';

subtest 'output to a file and mackerel' => sub {
    my $instance = Linux::GetPidstat->new(%cli_default_opt);
    my ($stdout, $stderr) = capture {
        $instance->run;
    };
    my @stdout_lines = split /\n/, $stdout;
    is scalar @stdout_lines, 43, or diag @stdout_lines;
    is $stderr, '';
};

done_testing;
