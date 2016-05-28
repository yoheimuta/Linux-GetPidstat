use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;
use Capture::Tiny qw/capture/;

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

subtest 'output to a file' => sub {
    my $instance = Linux::GetPidstat::Writer->new(%opt);
    my ($stdout, $stderr) = capture {
        $instance->output({
            'backup_mysql' => {
                'cpu'                => '21.20',
                'cswch_per_sec'      => '19.87',
                'disk_read_per_sec'  => '0.00',
                'disk_write_per_sec' => '0.00',
                'memory_percent'     => '34.63',
                'memory_rss'         => '10881534000.00',
                'nvcswch_per_sec'    => '30.45',
                'stk_ref'            => '25500.00',
                'stk_size'           => '128500.00'
            },
            'summarize_log' => {
                'cpu'                => '21.20',
                'cswch_per_sec'      => '19.87',
                'disk_read_per_sec'  => '0.00',
                'disk_write_per_sec' => '0.00',
                'memory_percent'     => '34.63',
                'memory_rss'         => '10881534000.00',
                'nvcswch_per_sec'    => '30.45',
                'stk_ref'            => '25500.00',
                'stk_size'           => '128500.00'
            },
        });
    };
    my @stdout_lines = split /\n/, $stdout;
    is scalar @stdout_lines, 18 or diag $stdout;
    is $stderr, '';
};

$opt{mackerel_api_key}      = 'dummy_key';
$opt{mackerel_service_name} = 'dummy_name';

subtest 'output to a file and mackerel' => sub {
    my $instance = Linux::GetPidstat::Writer->new(%opt);
    my ($stdout, $stderr) = capture {
        $instance->output({
            'backup_mysql' => {
                'cpu'                => '21.20',
                'cswch_per_sec'      => '19.87',
                'disk_read_per_sec'  => '0.00',
                'disk_write_per_sec' => '0.00',
                'memory_percent'     => '34.63',
                'memory_rss'         => '10881534000.00',
                'nvcswch_per_sec'    => '30.45',
                'stk_ref'            => '25500.00',
                'stk_size'           => '128500.00'
            },
            'summarize_log' => {
                'cpu'                => '21.20',
                'cswch_per_sec'      => '19.87',
                'disk_read_per_sec'  => '0.00',
                'disk_write_per_sec' => '0.00',
                'memory_percent'     => '34.63',
                'memory_rss'         => '10881534000.00',
                'nvcswch_per_sec'    => '30.45',
                'stk_ref'            => '25500.00',
                'stk_size'           => '128500.00'
            },
        });
    };
    my @stdout_lines = split /\n/, $stdout;
    is scalar @stdout_lines, 36 or diag $stdout;
    is $stderr, '';
};

done_testing;
