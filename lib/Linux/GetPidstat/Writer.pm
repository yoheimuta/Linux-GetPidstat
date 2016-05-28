package Linux::GetPidstat::Writer;
use 5.008001;
use strict;
use warnings;

use Time::Piece;
use WebService::Mackerel;

my $t = localtime;
sub new {
    my ( $class, %opt ) = @_;
    bless \%opt, $class;
}

sub output {
    my ($self, $ret_pidstats) = @_;

    my $new_file;
    if (my $r = $self->{res_file}) {
        open($new_file, '>>', $r) or die "failed to open:$!, name=$r";
    }

    my $summary;
    while (my ($cmd_name, $rets) = each %$ret_pidstats) {
        for my $ret (@{$rets}) {
            while (my ($mname, $mvalue) = each %$ret) {
                $summary->{$cmd_name}->{$mname} += $mvalue;
            }
        }
    }

    while (my ($cmd_name, $s) = each %$summary) {
        while (my ($mname, $mvalue) = each %$s) {
            # datetime は目視確認用に追加
            my $msg = join (",", $t->datetime, $t->epoch, $cmd_name, $mname, $mvalue);
            if ($new_file) {
                print $new_file "$msg\n";
            } elsif ($self->{dry_run}) {
                print "$msg\n";
            }

            if ($self->{mackerel_api_key} && $self->{mackerel_service_name}) {
                if ($self->{dry_run}) {
                    print "mackerel post: cmd_name=$cmd_name, mname=$mname, mvalue=$mvalue\n";
                } else {
                    $self->_send_mackerel($cmd_name, $mname, $mvalue);
                }
            }
        }
    }
    close($new_file) if $new_file;
}

sub _send_mackerel {
    my ($self, $cmd_name, $mname, $mvalue) = @_;
    my $graph_name = "custom.batch_$mname.$cmd_name";

    my $mackerel = WebService::Mackerel->new(
        api_key      => $self->{mackerel_api_key},
        service_name => $self->{mackerel_service_name},
    );
    return $mackerel->post_service_metrics([{
        "name"  => $graph_name,
        "time"  => $t->epoch,
        "value" => $mvalue,
    }]);
}

1;
__END__

=encoding utf-8

=head1 NAME

Linux::GetPidstat::Writer - Write pidstat's results to destinations

=head1 SYNOPSIS

    use Linux::GetPidstat::Writer;

    my $instance = Linux::GetPidstat::Writer->new(
        res_file              => './res',
        mackerel_api_key      => '',
        mackerel_service_name => '',
        dry_run               => '0',
    );
    $instance->output($results);

=cut
