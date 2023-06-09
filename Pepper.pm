package Pepper;

use strict;
use warnings;
use Carp;
use Tcl;

use lib './modules';
use lib './modules/Pepper';

use Pepper::Bindings;

sub new {
    my ($class, $bot, $dbi) = @_;

    my $self = {
        interp => Tcl->new,
        bindings => Pepper::Bindings->new(),
        initalized => 0,
        bot => $bot ? $bot : 0,
        dbi => $dbi ? $dbi : 0
    };

    return bless($self, $class);
}

sub init {
    my ($self) = @_;
    return if ($self->{initalized});

    $self->{initalized} = 1;
    $self->{bindings}->hook($self->{interp}, $self->{bot}, $self->{dbi});
}

sub destroy {
    my ($self) = @_;

    $self->{initalized} = 0;
    $self->{bindings}->unload();
}

sub eval {
    my ($self, $code) = @_;

    my $interp = $self->{interp};
    my $ret = {
        err => 0,
        ok => 0
    };

    CORE::eval "\$interp->Eval(\$code);";
    if ($@) {
        $ret->{err} = $@;
    }

    $ret->{ok} = 1;
    return $ret;
}

sub load {
    my ($self, $file) = @_;

    my $interp = $self->{interp};
    my $ret = {
        err => 0,
        ok => 0
    };

    CORE::eval "\$interp->EvalFile(\$file);";
    if ($@) {
        $ret->{err} = $@;
    }


    $ret->{ok} = $ret->{err} ? 0 : 1;
    return $ret;
}

sub event {
    my ($self, $evtype, @args) = @_;

    my $interp = $self->{interp};
    my @events = $self->{bindings}->get_events($evtype);
    
    my $ret = {
        err => 0,
        ok => 0
    };

    if ($evtype eq "pub") {
        my ($nick, $host, $hand, $chan, $text) = @args;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($text =~ /^$mask/) {
                        $text =~ s/^$mask//;
                        $text =~ s/^\s//;
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$chan, \$text);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } elsif ($evtype eq "msg") {
        my ($nick, $host, $handle, $text) = @_;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($text =~ /^$mask/) {
                        $text =~ s/^$mask//;
                        $text =~ s/^\s//;
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$text);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } else {
        $ret->{err} = "Unimplemented bind handler: $evtype";
        return $ret;
    }

    $ret->{ok} = 1;
    return $ret;
}

1;
