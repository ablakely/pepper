package Pepper::Bindings;

# Pepper::Bindings - Shadow bindings for eggdrop tcl API
# See: https://docs.eggheads.org/mainDocs/tcl-commands.html for more information.
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Copyright 2023 (C) Ephasic Software

use strict;
use warnings;
use Carp;

sub new {
    my ($class) = @_;

    my $self = {};

    return bless($self, $class);
}

sub hook {
    my ($self, $interp, $bot) = @_;

    $interp->CreateCommand("bind", sub {
        my ($bot, $intp, @args) = @_;

        foreach my $a (@args) {
            $bot->log("bind arg: $a\n");
        }
    }, $bot);
}

1;
