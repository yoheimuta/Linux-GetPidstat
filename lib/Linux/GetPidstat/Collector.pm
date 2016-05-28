package Linux::GetPidstat::Collector;
use 5.008001;
use strict;
use warnings;

use Parallel::ForkManager;

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

sub get_pidstats_results {
    my ($self, $cmd_pid_mapping) = @_;

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

    return $ret_pidstats;
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

Linux::GetPidstat::Collector - Collect pidstats' results

=head1 SYNOPSIS

    use Linux::GetPidstat::Collector;

    my $ret_pidstats = Linux::GetPidstat::Collector->new(
        interval => '60',
        dry_run  => '0',
    )->get_pidstats_results($cmd_pid_mapping);

=cut
