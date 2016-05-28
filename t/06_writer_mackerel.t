use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;
use Test::Mock::Guard;
use Capture::Tiny qw/capture/;

use Time::Piece;
use WebService::Mackerel;
use Linux::GetPidstat::Writer::Mackerel;

my $t = localtime 12345;
my %opt = (
    mackerel_api_key      => 'dummy_key',
    mackerel_service_name => 'dummy_name',
    now                   => $t,
    dry_run               => '1',
);

is exception {
    my $instance = Linux::GetPidstat::Writer::Mackerel->new(%opt);
}, undef, "create ok";

{
    my $guard = Test::Mock::Guard->new(
        'WebService::Mackerel' => {
            new => sub {
                my ($self, %args) = @_;
                is $args{api_key}     , 'dummy_key';
                is $args{service_name}, 'dummy_name';
            },
        },
    );

    my $instance = Linux::GetPidstat::Writer::Mackerel->new(%opt);
    my ($stdout, $stderr) = capture {
        $instance->output('backup_mysql', 'cpu', '21.20');
    };

    my @stdout_lines = split /\n/, $stdout;
    is scalar @stdout_lines, 1 or diag $stdout;
    is $stdout_lines[0],
        'mackerel post: name=custom.batch_cpu.backup_mysql, time=12345, metric=21.20';
    is $stderr, '';

    is $guard->call_count('WebService::Mackerel', 'new'), 1;
}

$opt{dry_run} = 0;

{
    my $guard = Test::Mock::Guard->new(
        'WebService::Mackerel' => {
            post_service_metrics => sub {
                my ($self, $args) = @_;
                is $args->[0]->{name} , 'custom.batch_cpu.backup_mysql';
                is $args->[0]->{time} , '12345';
                is $args->[0]->{value}, '21.20';
            },
        },
    );

    my $instance = Linux::GetPidstat::Writer::Mackerel->new(%opt);
    $instance->output('backup_mysql', 'cpu', '21.20');
    is $guard->call_count('WebService::Mackerel', 'post_service_metrics'), 1;
}

done_testing;
