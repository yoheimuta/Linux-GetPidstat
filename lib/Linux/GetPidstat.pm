package Linux::GetPidstat;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use Time::Piece;
use Parallel::ForkManager;
use WebService::Mackerel;
use Linux::GetPidstat::Input;
use Linux::GetPidstat::Output;

my $t = localtime;
my $convert_from_kilobytes = sub { my $raw = shift; return $raw * 1000 };
my $metric_param = {
    cpu => {
        column_num   => 6,
    },
    memory_percent => {
        column_num   => 12,
    },
    memory_rss => {
        column_num   => 11,
        convert_func => $convert_from_kilobytes,
    },
    stk_size => {
        column_num   => 13,
        convert_func => $convert_from_kilobytes,
    },
    stk_ref => {
        column_num   => 14,
        convert_func => $convert_from_kilobytes,
    },
    disk_read_per_sec => {
        column_num   => 15,
        convert_func => $convert_from_kilobytes,
    },
    disk_write_per_sec => {
        column_num   => 16,
        convert_func => $convert_from_kilobytes,
    },
    cswch_per_sec => {
        column_num   => 18,
    },
    nvcswch_per_sec => {
        column_num   => 19,
    },
};

sub new {
    my ( $class, %opt ) = @_;
    bless \%opt, $class;
}

sub run {
    my $self = shift;

    my $cmd_pid_mapping = Linux::GetPidstat::Input->new(
        pid_dir       => $self->{pid_dir},
        include_child => $self->{include_child},
        dry_run       => $self->{dry_run},
    )->get_cmd_pid_mapping;

    my $ret_pidstats;

    my $pm = Parallel::ForkManager->new(scalar @$cmd_pid_mapping);
    $pm->run_on_finish(sub {
        if (my $ret = $_[5]) {
            my ($cmd_name, $ret_pidstat) = @$ret;
            push @{$ret_pidstats->{$cmd_name}}, $ret_pidstat;
        } else {
            print "failed to collect metrics\n";
        }
    });

    METHODS:
    for my $info (@$cmd_pid_mapping) {
        my $cmd_name    = $info->{cmd};
        my $pid         = $info->{pid};

        if (my $child_pid = $pm->start) {
            printf "child_pid=%d, cmd_name=%s, target_pid=%d\n",
                $child_pid, $cmd_name, $pid;
            next METHODS;
        }

        my $ret_pidstat = $self->get_pidstat($pid);
        unless ($ret_pidstat && %$ret_pidstat) {
            die "failed getting pidstat: pid=$$, target_pid=$pid, cmd_name=$cmd_name";
        }

        $pm->finish(0, [$cmd_name, $ret_pidstat]);
    }
    $pm->wait_all_children;

    Linux::GetPidstat::Output->new(
        res_file              => $self->{res_file},
        mackerel_api_key      => $self->{mackerel_api_key},
        mackerel_service_name => $self->{mackerel_service_name},
        dry_run               => $self->{dry_run},
    )->output($ret_pidstats);
}

sub get_pidstat {
    my ($self, $pid) = @_;
    my $command = do {
        if ($self->{dry_run}) {
            "cat ./source/metric.txt";
        } else {
            my $run_sec = $self->{interval};
            "pidstat -h -u -r -s -d -w -p $pid 1 $run_sec";
        }
    };
    my $output = `$command`;
    die "failed command: $command, pid=$$" unless $output;

    my @lines = split '\n', $output;
    return $self->_parse_ret(\@lines);
}

sub _parse_ret {
    my ($self, $lines) = @_;

    my $ret;

    while (my ($mname, $param) = each %$metric_param) {
        my @metrics;
        for (@$lines) {
            my @num = split " ";
            #print "$_,\n" for @num;
            my $m = $num[$param->{column_num}];
            next unless $m;
            next unless $m =~ /^[0-9.]+$/;
            if (my $cf = $param->{convert_func}) {
                push @metrics, $cf->($m);
            } else {
                push @metrics, $m;
            }
        }
        unless (@metrics) {
            printf "empty metrics: mname=%s, lines=%s\n",
                $mname, join ',', @$lines;
            next;
        }

        my $average = do {
            my $sum = 0;
            $sum += $_ for @metrics;
            sprintf '%.2f', $sum / (scalar @metrics);
        };

        $ret->{$mname} = $average;
    }

    return $ret;
}

1;
__END__

=encoding utf-8

=head1 NAME

Linux::GetPidstat - Run pidstat -w -s -u -d -r commands in parallel to monitor each process metrics avg/1min

=head1 SYNOPSIS

    use Linux::GetPidstat;

    my $stat = Linux::GetPidstat->new(%opt);
    $stat->run;

=head1 DESCRIPTION

Run C<pidstat -w -s -u -d -r> commands in parallel to monitor each process metrics avg/1min.

Output to stdout, a specified file or C<Mackerel> https://mackerel.io.

=head2 Motivation

A batch server runs many batch scripts at the same time.

When this server suffers by a resource short, it's difficult to grasp which processes are heavy quickly.

Running pidstat manually is not appropriate in this situation, because

=over 4

=item the target processes are changed by starting each job.

=item the target processes may run child processes recursively.

=back

=head2 Requirements

pidstat
pstree
grep

=head2 Usage

Prepare pid files in a specified directory.

    $ mkdir /tmp/pid_dir
    $ echo 1234 > /tmp/pid_dir/target_script
    $ echo 1235 > /tmp/pid_dir/target_script2
    # In production, this file is made and removed by the batch script itself for instance.

Run the script every 1 mininute.

    # vi /etc/cron.d/get_pidstat
    * * * * * user carton exec -- perl /path/to/get_pidstat.pl --dry_run=0 --pid_dir=/tmp/pid_dir --res_dir=/tmp/bstat.log

    # or run manually
    $ cat run.sh
    carton exec -- perl /path/to/get_pidstat.pl \
    --dry_run=0 \
    --pid_dir=/tmp/pid_dir \
    --res_dir=/tmp/bstat.log &
    sleep 60
    $ while true; do sh run.sh; done

Done, you can monitor the result.

    $ tail -f /tmp/bstat.log
    # start(datetime),start(epoch),pidfilename,name,value
    2016-04-02T19:49:32,1459594172,target_script,cswch_per_sec,19.87
    2016-04-02T19:49:32,1459594172,target_script,stk_ref,25500
    2016-04-02T19:49:32,1459594172,target_script,memory_percent,34.63
    2016-04-02T19:49:32,1459594172,target_script,memory_rss,10881534000
    2016-04-02T19:49:32,1459594172,target_script,stk_size,128500
    2016-04-02T19:49:32,1459594172,target_script,nvcswch_per_sec,30.45
    2016-04-02T19:49:32,1459594172,target_script,cpu,21.2
    2016-04-02T19:49:32,1459594172,target_script,disk_write_per_sec,0
    2016-04-02T19:49:32,1459594172,target_script,disk_read_per_sec,0
    2016-04-02T19:49:32,1459594172,target_script2,memory_rss,65289204000
    2016-04-02T19:49:32,1459594172,target_script2,memory_percent,207.78
    2016-04-02T19:49:32,1459594172,target_script2,stk_ref,153000
    2016-04-02T19:49:32,1459594172,target_script2,cswch_per_sec,119.22
    2016-04-02T19:49:32,1459594172,target_script2,nvcswch_per_sec,182.7
    2016-04-02T19:49:32,1459594172,target_script2,cpu,127.2
    2016-04-02T19:49:32,1459594172,target_script2,disk_read_per_sec,0
    2016-04-02T19:49:32,1459594172,target_script2,disk_write_per_sec,0
    2016-04-02T19:49:32,1459594172,target_script2,stk_size,771000

=head3 Mackerel

Post the results to service metrics.

    carton exec -- perl /path/to/get_pidstat.pl \
    --dry_run=0 \
    --pid_dir=/tmp/pid_dir \
    --mackerel_api_key=yourkey \
    --mackerel_service_name=yourservice

=head1 LICENSE

Copyright (C) yoheimuta.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

yoheimuta E<lt>yoheimuta@gmail.comE<gt>

=cut

