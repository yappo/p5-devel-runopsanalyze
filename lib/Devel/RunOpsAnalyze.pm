package Devel::RunOpsAnalyze;
use strict;
use warnings;
use base 'Exporter';
our $VERSION = '0.01';
our @EXPORT = qw( analyze );

use XSLoader;
XSLoader::load 'Devel::RunOpsAnalyze', $VERSION;

use B qw(walkoptree svref_2object ppname);

use Devel::RunOpsAnalyze::Trace;

sub analyze (&) { ## no critic
    my $code = shift;

    # getting running status
    my $trace = {};
    start($trace);
    $code->();
    stop();

    # get op tree
    local *B::OP::for_opprof = sub {
        my $self = shift;
        my $seq  = $self->seq;
        my $stash = $trace->{$seq};
        return unless $stash;

        $stash->{on_inner} = 1;
        $stash->{class}    = ref($self);
        $stash->{name}     = $self->name;
        $stash->{desc}     = $self->desc;
    };

    walkoptree(svref_2object($code)->ROOT, 'for_opprof');

    # grep real running opes
    my $running_trace = {};
    my $last_step_seq;
    for my $seq (sort { $a <=> $b } keys %{ $trace }) {
        my $stash = $trace->{$seq};

        if ($stash->{before_op_seq} && $trace->{$stash->{before_op_seq}} && $trace->{$stash->{before_op_seq}}->{package} eq __PACKAGE__) {
            # delete first steps
            next;
        }

        if ($stash->{package} eq __PACKAGE__) {
            if ($stash->{before_op_seq} && $trace->{$stash->{before_op_seq}}->{package} ne __PACKAGE__) {
                # save last step seq
                $last_step_seq = $stash->{before_op_seq};
            }

            # delete bootstrap steps
            next;
        }

        if (!$stash->{on_inner}) {
            # running external sub
            $stash->{on_inner} = 0;
            $stash->{class}    = 'external';
            $stash->{name}     = ppname($stash->{type});
            $stash->{desc}     = '';
        }

        $running_trace->{$seq} = $trace->{$seq};
    }
    delete $running_trace->{$last_step_seq}; # delete last step

    Devel::RunOpsAnalyze::Trace->new($running_trace);
}

1;

__END__

=head1 name

Devel::RunOpsAnalyze - OP code analyzer

=head1 SYNOPSIS

  use Devel::RunOpsAnalyze;

  Devel::RunOpsAnalyze::show_profile(sub {
     my $i = 0;
     for (0..100) {
         $i += $_;
     }
  });

=head1 DESCRIPTION

Devel::RunOpsAnalyze is

=head1 AUTHOR

Kazuhiro Osawa E<lt>yappo <at> shibuya <döt> plE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

