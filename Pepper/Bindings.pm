package Pepper::Bindings;

# Pepper::Bindings - Shadow bindings for eggdrop tcl API
# See: https://docs.eggheads.org/mainDocs/tcl-commands.html for more information.
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Copyright 2023 (C) Ephasic Software

use strict;
use warnings;
use Carp;

use lib './Bindings';

sub new {
    my ($class) = @_;

    require Pepper::Bindings::Core;
    require Pepper::Bindings::Server;
    
    my $self = {
        events => {},

        _core_bindings => Pepper::Bindings::Core->new(),
        _server_bindings => Pepper::Bindings::Server->new()
    };

    return bless($self, $class);
}

sub hook {
    my ($self, $interp, $bot) = @_;

    $self = $self->{_core_bindings}->hook($interp, $self, $bot);
    $self = $self->{_server_bindings}->hook($interp, $self, $bot);

    return 1;
}

sub get_events {
    my ($self, $type) = @_;

    return exists($self->{events}->{$type}) ? $self->{events}->{$type} : 0;
}

sub unload {
    delete $INC{'Pepper/Bindings/Core.pm'};
    delete $INC{'Pepper/Bindings/Server.pm'};
}

1;
