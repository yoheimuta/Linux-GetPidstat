package Linux::GetPidstat;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use Carp;
use Linux::GetPidstat::Reader;
use Linux::GetPidstat::Collector;
use Linux::GetPidstat::Writer;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub run {
    my ($self, %args) = @_;

    my $pid_dir_path = $args{pid_dir};
    unless (length $pid_dir_path) {
        Carp::croak("pid_dir required");
    }

    my $program_pid_mapping = Linux::GetPidstat::Reader->new(
        pid_dir       => $pid_dir_path,
        include_child => $args{include_child},
        dry_run       => $args{dry_run},
    )->get_program_pid_mapping;

    unless (@$program_pid_mapping) {
        croak "Not found pids in pid_dir: $pid_dir_path";
    }

    my $ret_pidstats = Linux::GetPidstat::Collector->new(
        interval => $args{interval},
        dry_run  => $args{dry_run},
    )->get_pidstats_results($program_pid_mapping);

    unless (%$ret_pidstats) {
        croak "Failed to collect metrics";
    }

    Linux::GetPidstat::Writer->new(
        res_file              => $args{res_file},
        mackerel_api_key      => $args{mackerel_api_key},
        mackerel_service_name => $args{mackerel_service_name},
        dry_run               => $args{dry_run},
    )->output($ret_pidstats);
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

