package Linux::GetPidstat::Input;
use 5.008001;
use strict;
use warnings;

sub new {
    my ( $class, %opt ) = @_;
    bless \%opt, $class;
}

sub get_pids {
    my $self = shift;

    opendir my $pid_dir, $self->{pid_dir}
        or die "failed to opendir:$!, name=" . $self->{pid_dir};

    my @pid_files;
    foreach(readdir $pid_dir){
        next if /^\.{1,2}$/;

        my $path = $self->{pid_dir} . "/$_";
        my $ok = open my $pid_file, '<', $path;
        unless ($ok) {
            print "failed to open: err=$!, path=$path\n";
            next;
        }
        chomp(my $pid = <$pid_file>);
        close $pid_file;

        unless ($pid =~ /^[0-9]+$/) {
            print "invalid pid: value=$pid\n";
            next;
        }
        push @pid_files, { $_ => $pid+0 };
    }
    closedir($pid_dir);

    die "not found pids in pid_dir: " . $self->{pid_dir} unless @pid_files;

    $self->include_child_pids(\@pid_files) if $self->{include_child};
    return \@pid_files;
}

sub include_child_pids {
    my ($self, $pid_files) = @_;

    my @append_files;
    for my $info (@$pid_files) {
        while (my ($cmd_name, $pid) = each %$info) {
            my $child_pids = $self->_search_child_pids($pid);
            for my $child_pid (@$child_pids) {
                unless ($child_pid =~ /^[0-9]+$/) {
                    print "invalid child_pid: value=$child_pid\n";
                    next;
                }
                push @append_files, { $cmd_name => $child_pid+0 };
            }
        }
    }

    push @$pid_files, @append_files;
}

sub _search_child_pids {
    my ($self, $pid) = @_;
    my $command = do {
        if ($self->{dry_run}) {
            "cat ./source/pstree_$pid.txt";
        } else {
            "pstree -pn $pid |grep -o '([[:digit:]]*)' |grep -o '[[:digit:]]*'";
        }
    };
    my $output = `$command`;
    return [] unless $output;

    chomp(my @child_pids = split '\n', $output);
    return [grep { $_ != $pid } @child_pids];
}

1;
__END__

=encoding utf-8

=head1 NAME

Linux::GetPidstat::Input - Collect pids from a pid dir path

=head1 SYNOPSIS

    use Linux::GetPidstat::Input;

    my $instance = Linux::GetPidstat::Input->new(
        pid_dir       => './pid',
        include_child => 1,
        dry_run       => 1,
    );
    my $pids = $instance->get_pids;

=cut
