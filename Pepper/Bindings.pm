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

    require Pepper::Bindings::IRC;
    require Pepper::Bindings::Core;
    require Pepper::Bindings::Server;
    require Pepper::Bindings::Channel;
    
    my $self = {
        events => {},

        _irc_bindings   => Pepper::Bindings::IRC->new(),
        _core_bindings  => Pepper::Bindings::Core->new(),
        _serv_bindings  => Pepper::Bindings::Server->new(),
        _chan_bindings  => Pepper::Bindings::Channel->new()
    };

    return bless($self, $class);
}

sub hook {
    my ($self, $interp, $bot, $dbi) = @_;

    $self =  $self->{_irc_bindings}->hook($interp, $self, $bot, $dbi);
    $self = $self->{_core_bindings}->hook($interp, $self, $bot, $dbi);
    $self = $self->{_serv_bindings}->hook($interp, $self, $bot, $dbi);
    $self = $self->{_chan_bindings}->hook($interp, $self, $bot, $dbi);

    return 1;
}

sub get_events {
    my ($self, $type) = @_;

    return exists($self->{events}->{$type}) ? $self->{events}->{$type} : 0;
}

sub unload {
    delete $INC{'Pepper/Bindings/IRC.pm'};
    delete $INC{'Pepper/Bindings/Core.pm'};
    delete $INC{'Pepper/Bindings/Server.pm'};
    delete $INC{'Pepper/Bindings/Channel.pm'};
}

1;
