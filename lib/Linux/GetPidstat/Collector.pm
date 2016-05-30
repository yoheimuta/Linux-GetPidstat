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
    my ($self, $program_pid_mapping) = @_;

    my $ret_pidstats;

    my $pm = Parallel::ForkManager->new(scalar @$program_pid_mapping);
    $pm->run_on_finish(sub {
        if (my $ret = $_[5]) {
            my ($program_name, $ret_pidstat) = @$ret;
            push @{$ret_pidstats->{$program_name}}, $ret_pidstat;
        } else {
            carp "Failed to collect metrics";
        }
    });

    METHODS:
    for my $info (@$program_pid_mapping) {
        my $program_name = $info->{program_name};
        my $pid          = $info->{pid};

        if (my $child_pid = $pm->start) {
            printf "child_pid=%d, program_name=%s, target_pid=%d\n",
                $child_pid, $program_name, $pid;
            next METHODS;
        }

        my $ret_pidstat = $self->get_pidstat($pid);
        unless ($ret_pidstat && %$ret_pidstat) {
            croak "Failed getting pidstat: pid=$$, target_pid=$pid, program_name=$program_name";
        }

        $pm->finish(0, [$program_name, $ret_pidstat]);
    }
    $pm->wait_all_children;

    return summarize($ret_pidstats);
}

sub get_pidstat {
    my ($self, $pid) = @_;
    my $command = _command_get_pidstat($pid, $self->{interval});
    my $output  = `$command`;
    croak "Failed a command: $command, pid=$$" unless $output;

    my @lines = split '\n', $output;
    return parse_pidstat_output(\@lines);
}

# for mock in tests
sub _command_get_pidstat {
    my ($pid, $interval) = @_;
    return "pidstat -h -u -r -s -d -w -p $pid 1 $interval";
}

sub summarize($) {
    my $ret_pidstats = shift;

    my $summary = {};

    # in : backup_mysql => [ { cpu => 21.0... } ... ] ...
    # out: backup_mysql => { cpu => 42.0 } ... } ...
    while (my ($program_name, $rets) = each %$ret_pidstats) {
        for my $ret (@{$rets}) {
            while (my ($metric_name, $metric) = each %$ret) {
                $summary->{$program_name}->{$metric_name} += $metric;
            }
        }
    }
    return $summary;
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
    )->get_pidstats_results($program_pid_mapping);

=cut
