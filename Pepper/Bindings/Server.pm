package Pepper::Bindings::Server;

# Pepper::Bindings - Shadow bindings for eggdrop tcl API
# See: https://docs.eggheads.org/mainDocs/tcl-commands.html for more information.
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Copyright 2023 (C) Ephasic Software

use strict;
use warnings;
use Carp;

sub new {
    my ($class, $ins) = @_;

    my $self = {
        ins => $ins
    };

    return bless($self, $class);
}

sub hook {
    my ($self, $interp, $ins) = @_;

    $interp->CreateCommand("putquick", sub {
        my ($ins, $intp, $tclcmd, @args) = @_;
        my ($str, $flags) = @args;

        my $self = $ins->{self};
        my $bot  = $ins->{bot};

        chomp $str;
        $bot->fastout($str."\r\n");

    }, $ins);
}

1;
