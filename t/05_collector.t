use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;
use Test::Mock::Guard;

use Linux::GetPidstat::Collector;

my %opt = (
    interval => '60',
);

is exception {
    my $instance = Linux::GetPidstat::Collector->new(%opt);
}, undef, "create ok";

my $guard = Test::Mock::Guard->new(
    'Linux::GetPidstat::Collector' => {
        _command_get_pidstat => sub {
            return "cat t/assets/source/metric.txt";
        },
    },
);

my $instance = Linux::GetPidstat::Collector->new(%opt);

{
    my $ret = $instance->get_pidstats_results([
        { program_name => 'backup_mysql' , pid => '14423' },
        { program_name => 'summarize_log', pid => '14530' },
    ]);
    is_deeply $ret, {
        'backup_mysql' => {
            'cpu' => '21.2',
            'cswch_per_sec' => '19.87',
            'disk_read_per_sec' => '0',
            'disk_write_per_sec' => '0',
            'memory_percent' => '34.63',
            'memory_rss' => '10881534000',
            'nvcswch_per_sec' => '30.45',
            'stk_ref' => '25500',
            'stk_size' => '128500'
        },
        'summarize_log' => {
            'cpu' => '21.2',
            'cswch_per_sec' => '19.87',
            'disk_read_per_sec' => '0',
            'disk_write_per_sec' => '0',
            'memory_percent' => '34.63',
            'memory_rss' => '10881534000',
            'nvcswch_per_sec' => '30.45',
            'stk_ref' => '25500',
            'stk_size' => '128500'
        }
    } or diag explain $ret;
}

{
    my $ret = $instance->get_pidstats_results([
        { program_name => 'backup_mysql' , pid => '14423' },
        { program_name => 'summarize_log', pid => '14530' },
        { program_name => 'summarize_log', pid => '14533' }, # child process
        { program_name => 'summarize_log', pid => '14534' }, # child process
    ]);
    is_deeply $ret, {
        'backup_mysql' => {
            'cpu' => '21.2',
            'cswch_per_sec' => '19.87',
            'disk_read_per_sec' => '0',
            'disk_write_per_sec' => '0',
            'memory_percent' => '34.63',
            'memory_rss' => '10881534000',
            'nvcswch_per_sec' => '30.45',
            'stk_ref' => '25500',
            'stk_size' => '128500'
        },
        'summarize_log' => {
            'cpu' => '63.6',
            'cswch_per_sec' => '59.61',
            'disk_read_per_sec' => '0',
            'disk_write_per_sec' => '0',
            'memory_percent' => '103.89',
            'memory_rss' => '32644602000',
            'nvcswch_per_sec' => '91.35',
            'stk_ref' => '76500',
            'stk_size' => '385500'
        }
    } or diag explain $ret;
}

done_testing;
