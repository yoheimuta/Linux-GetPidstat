package Linux::GetPidstat::Reader;
use 5.008001;
use strict;
use warnings;

use Carp;
use Capture::Tiny qw/capture/;
use Path::Tiny qw/path/;

sub new {
    my ( $class, %opt ) = @_;
    bless \%opt, $class;
}

sub get_program_pid_mapping {
    my $self = shift;

    my $pid_dir = path($self->{pid_dir});

    my @program_pid_mapping;
    for my $pid_file ($pid_dir->children) {
        chomp(my $pid = $pid_file->slurp);
        unless (_is_valid_pid($pid)) {
            next;
        }

        my @pids;
        push @pids, $pid;

        if ($self->{include_child}) {
            my $child_pids = $self->search_child_pids($pid);
            push @pids, @$child_pids;
        }

        for (@pids) {
            push @program_pid_mapping, {
                program_name => $pid_file->basename,
                pid          => $_+0,
            };
        }
    }

    return \@program_pid_mapping;
}

sub search_child_pids {
    my ($self, $pid) = @_;
    my $command = _command_search_child_pids($pid);
    my ($stdout, $stderr, $exit) = capture { system $command };

    if ($stderr or $exit != 0) {
        carp "Failed a command: $command, stdout=$stdout, stderr=$stderr, exit=$exit";
    }
    if (!$stdout) {
        return [];
    }

    chomp(my @child_pids = split '\n', $stdout);
    return [grep { $_ != $pid && _is_valid_pid($pid) } @child_pids];
}

# for mock in tests
sub _command_search_child_pids {
    my $pid = shift;
    return "pstree -pn $pid |grep -o '([[:digit:]]*)' |grep -o '[[:digit:]]*'";
}

sub _is_valid_pid {
    my $pid = shift;
    unless ($pid =~ /^[0-9]+$/) {
        carp "invalid pid: $pid";
        return 0;
    }
    return 1;
}

1;
__END__

=encoding utf-8

=head1 NAME

Linux::GetPidstat::Reader - Collect pids from a pid dir path

=head1 SYNOPSIS

    use Linux::GetPidstat::Reader;

    my $instance = Linux::GetPidstat::Reader->new(
        pid_dir       => './pid',
        include_child => 1,
    );
    my $pids = $instance->get_program_pid_mapping;

=cut
