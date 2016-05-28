package Linux::GetPidstat::Collector;
use 5.008001;
use strict;
use warnings;

use Carp;
use Parallel::ForkManager;
use Linux::GetPidstat::Collector::Parser;

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
            carp "failed to collect metrics";
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
            croak "failed getting pidstat: pid=$$, target_pid=$pid, cmd_name=$cmd_name";
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
    croak "failed command: $command, pid=$$" unless $output;

    my @lines = split '\n', $output;
    return parse_pidstat_output(\@lines);
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
