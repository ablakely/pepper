package Pepper;

use strict;
use warnings;
use Carp;
use Tcl;

use lib './modules';
use lib './modules/Pepper';

use Pepper::Bindings;

sub new {
    my ($class, $bot) = @_;

    my $self = {
        interp => Tcl->new,
        bindings => Pepper::Bindings->new(),
        initalized => 0,
        bot => $bot ? $bot : 0
    };

    return bless($self, $class);
}

sub init {
    my ($self) = @_;
    return if ($self->{initalized});

    $self->{initalized} = 1;
    $self->{bindings}->hook($self->{interp}, $self->{bot});
}

sub eval {
    my ($self, $code) = @_;
    $self->init();

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

1;
