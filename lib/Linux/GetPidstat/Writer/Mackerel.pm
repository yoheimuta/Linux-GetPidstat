package Linux::GetPidstat::Writer::Mackerel;
use 5.008001;
use strict;
use warnings;

use Time::Piece;
use WebService::Mackerel;

sub new {
    my ( $class, %opt ) = @_;

    my $mackerel = WebService::Mackerel->new(
        api_key      => $opt{mackerel_api_key},
        service_name => $opt{mackerel_service_name},
    );
    $opt{mackerel} = $mackerel;

    bless \%opt, $class;
}

sub output {
    my ($self, $cmd_name, $mname, $mvalue) = @_;
    my $graph_name = "custom.batch_$mname.$cmd_name";

    if ($self->{dry_run}) {
        printf "mackerel post: name=%s, time=%s, mvalue=%s\n",
            $graph_name, $self->{now}->epoch, $mvalue;
        return;
    }

    $self->{mackerel}->post_service_metrics([{
        "name"  => $graph_name,
        "time"  => $self->{now}->epoch,
        "value" => $mvalue,
    }]);
}

1;
__END__

=encoding utf-8

=head1 NAME

Linux::GetPidstat::Writer::Mackerel - Write pidstat's results to mackerel

=head1 SYNOPSIS

    use Linux::GetPidstat::Writer::Mackerel;

    my $instance = Linux::GetPidstat::Writer::Mackerel->new(
        mackerel_api_key      => 'api_key',
        mackerel_service_name => 'service_name',
        now                   => $t,
        dry_run               => $self->{dry_run},
    );
    $instance->output('backup_mysql', 'cpu', '21.20');

=cut

