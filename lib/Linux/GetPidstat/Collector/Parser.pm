package Linux::GetPidstat::Collector::Parser;
use 5.008001;
use strict;
use warnings;

use Exporter qw(import);
use Carp;

our @EXPORT = qw(parse_pidstat_output);

sub parse ($) {
    my $lines = shift;

    my $ret;

    my $mapping = _get_metric_param_mapping();
    while (my ($mname, $param) = each %$mapping) {
        my @metrics;
        for (@$lines) {
            my @num = split " ";
            # carp "$_," for @num;
            my $m = $num[$param->{column_num}];
            next unless $m && $m =~ /^[0-9.]+$/;
            if (my $cf = $param->{convert_func}) {
                push @metrics, $cf->($m);
            } else {
                push @metrics, $m;
            }
        }
        unless (@metrics) {
            carp (sprintf "empty metrics: mname=%s, lines=%s\n",
                $mname, join ',', @$lines);
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

sub _get_metric_param_mapping() {
    my $convert_from_kilobytes = sub { my $raw = shift; return $raw * 1000 };

    return {
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
}

*parse_pidstat_output = \&parse;

1;
__END__

=encoding utf-8

=head1 NAME

Linux::GetPidstat::Collector::Parser - Parse pidstats' output

=head1 SYNOPSIS

    use Linux::GetPidstat::Collector::Parser;

    my $ret = parse_pidstat_output($output);

=cut

