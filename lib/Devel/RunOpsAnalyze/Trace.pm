package Devel::RunOpsAnalyze::Trace;
use strict;
use warnings;


my %FILE_CACHE;
sub new {
    my($class, $trace) = @_;

    # make file mapping and append sourcecode
    my $map = +{};
    while (my($seq, $stash) = each %{ $trace }) {
        my $file = $stash->{file};
        my $line = $stash->{line};
        if (!defined $file && $stash->{before_op_seq}) {
            my $before = $trace->{$stash->{before_op_seq}};
            $file = $before->{file};
            $line = $before->{line};
        }

        if ($stash->{attribute}) {
            $stash->{attribute} =~ s{\\}{\\\\};
            $stash->{attribute} =~ s{\n}{\\n};
            $stash->{attribute} =~ s{\r}{\\r};
            $stash->{attribute} =~ s{\t}{\\t};
        }

        # file mapping
        $map->{$file} ||= +{};
        $map->{$file}->{$line} ||= +{};
        $map->{$file}->{$line}->{$seq} = $stash;

        if ($file =~ /^\(/) {
            # not in a file
            $stash->{sourcecode} = '';
            next;
        }

        # append sourcecode
        my $file_data = $FILE_CACHE{$file} || do {
            open my $fh, '<', $file or die "$file: $!";
            my @lines = map { my $line = $_; $line =~ s/\n$//; $line } <$fh>;
            unshift @lines, undef;
            \@lines;
        };
        $stash->{sourcecode} = $file_data->[$stash->{line}];
    }

    bless { trace => $map }, $class;
}

sub use_term_ansicolor { shift->{use_term_ansicolor} }

sub color {
    my($self, $color, $msg) = @_;
    my $text = '';
    if ($self->use_term_ansicolor) {
        $text .= Term::ANSIColor::color($color);
    }
    $text .= $msg;
    if ($self->use_term_ansicolor) {
        $text .= Term::ANSIColor::color('reset');
    }
    $text;
}

sub each {
    my($self, $code) = @_;

    my $trace = $self->{trace};
    my $steps = 0;
    my $usec  = 0;
    for my $file (keys %{ $trace }) {
        my $files = $trace->{$file};
        for my $line (sort { $a <=> $b } keys %{ $files }) {
            my $lines = $files->{$line};
            for my $seq (sort { $a <=> $b } keys %{ $lines }) {
                my $stash = $lines->{$seq};

                $code->($file, $line, $seq, $stash);

                $steps += $stash->{steps};
                $usec  += $stash->{usec};
            }
        }
    }
    +{
        steps => $steps,
        usec  => $usec,
        avrg  => ($usec / $steps),
    };
}

sub as_string {
    my $self = shift;

    my $text;
    my($last_file, $last_line) = ('', '');
    my $total = $self->each(sub {
        my($file, $line, $seq, $stash) = @_;

        # file name
        unless ($last_file eq $file) {
            if ($self->use_term_ansicolor) {
                $text .= "\n";
                $text .= $self->color('bold green', $file);
                $text .= "\n";
            }
            $last_file = $file;
            $last_line = -1;
        }

        # line
        unless ($last_line eq $line) {
            unless ($self->use_term_ansicolor) {
                $text .= $file . ':';
            }
            $text .= $line . ':';
            if ($self->use_term_ansicolor) {
                $text .= $self->color('bold blue', $stash->{sourcecode});
            } else {
                $text .= $stash->{sourcecode};
            }
            $text .= "\n";

            $last_line = $line;
        }

        # seq
        if ($self->use_term_ansicolor) {
            $text .= "\t";
            my $class = $self->color('blue', $stash->{class});
            $class .= "($seq)";

            $text .= join( ', ', $class,
                $self->color('magenta', $stash->{name}),
                $self->color('cyan', $stash->{desc}));
        } else {
            $text .= sprintf "\t%s, %s, %s",
                ($stash->{class} . "($seq)"),
                $stash->{name}, $stash->{desc};
        }
        if ($stash->{attribute}) {
            my $value;
            if ($self->use_term_ansicolor) {
                $value = $self->color('bold magenta', $stash->{attribute});
            } else {
                $value = $stash->{attribute};
            }
            $text .= "\t[$value]";
        }
        $text .= "\n";

        $text .= sprintf "\t% 10s steps, % 10s usec, (avrg: %s usec)\n",
            $stash->{steps},
            $stash->{usec}, ($stash->{usec} / $stash->{steps});

    });

    $text .= "\nResult:\n";
    $text .= sprintf "     total steps : %s\n", $total->{steps};
    $text .= sprintf " total user time : %s usec\n", $total->{usec};
    $text .= sprintf "            avrg : %s\n", $total->{avrg};

    $text;
}

my $installed_term_ansicolor;
sub installed_term_ansicolor {
    unless (-t *STDOUT) { ## no critic
        # pipe
        return $installed_term_ansicolor = 0;
    }
    return $installed_term_ansicolor if defined $installed_term_ansicolor;
    eval "use Term::ANSIColor ();"; ## no critic
    return $installed_term_ansicolor = !!!$@;
}
sub as_term {
    my $self = shift;
    local $self->{use_term_ansicolor} = installed_term_ansicolor;
    $self->as_string;
}


sub as_html {
    my $self = shift;
}

1;
