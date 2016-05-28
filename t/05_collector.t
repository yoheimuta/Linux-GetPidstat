use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;

use Linux::GetPidstat::Collector;

my %opt = (
    interval => '60',
    dry_run  => '1',
);

is exception {
    my $instance = Linux::GetPidstat::Collector->new(%opt);
}, undef, "create ok";

my $instance = Linux::GetPidstat::Collector->new(%opt);

{
    my $ret = $instance->get_pidstats_results([
        { cmd => 'backup_mysql' , pid => '14423' },
        { cmd => 'summarize_log', pid => '14530' },
    ]);
    is_deeply $ret, {
        'backup_mysql' => [
            {
                'cpu'                => '21.20',
                'cswch_per_sec'      => '19.87',
                'disk_read_per_sec'  => '0.00',
                'disk_write_per_sec' => '0.00',
                'memory_percent'     => '34.63',
                'memory_rss'         => '10881534000.00',
                'nvcswch_per_sec'    => '30.45',
                'stk_ref'            => '25500.00',
                'stk_size'           => '128500.00'
            }
        ],
        'summarize_log' => [
            {
                'cpu'                => '21.20',
                'cswch_per_sec'      => '19.87',
                'disk_read_per_sec'  => '0.00',
                'disk_write_per_sec' => '0.00',
                'memory_percent'     => '34.63',
                'memory_rss'         => '10881534000.00',
                'nvcswch_per_sec'    => '30.45',
                'stk_ref'            => '25500.00',
                'stk_size'           => '128500.00'
                }
        ]
    } or diag explain $ret;
}


{
    my $ret = $instance->get_pidstats_results([
        { cmd => 'backup_mysql' , pid => '14423' },
        { cmd => 'summarize_log', pid => '14530' },
        { cmd => 'summarize_log', pid => '14533' }, # child process
        { cmd => 'summarize_log', pid => '14534' }, # child process
    ]);
    is_deeply $ret, {
        'backup_mysql' => [
            {
                'cpu'                => '21.20',
                'cswch_per_sec'      => '19.87',
                'disk_read_per_sec'  => '0.00',
                'disk_write_per_sec' => '0.00',
                'memory_percent'     => '34.63',
                'memory_rss'         => '10881534000.00',
                'nvcswch_per_sec'    => '30.45',
                'stk_ref'            => '25500.00',
                'stk_size'           => '128500.00'
            }
        ],
        'summarize_log' => [
            {
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
            {
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
            {
                'cpu'                => '21.20',
                'cswch_per_sec'      => '19.87',
                'disk_read_per_sec'  => '0.00',
                'disk_write_per_sec' => '0.00',
                'memory_percent'     => '34.63',
                'memory_rss'         => '10881534000.00',
                'nvcswch_per_sec'    => '30.45',
                'stk_ref'            => '25500.00',
                'stk_size'           => '128500.00'
            }
        ]
    } or diag explain $ret;
}

done_testing;
