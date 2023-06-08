package Pepper::Bindings::IRC;


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
    my ($self, $interp, $inst, $bot) = @_;

    my $ins = {
        bot => $bot,
        self => $inst
    };

    $interp->CreateCommand("putkick", sub {
        my ($ins, $intp, $tclcmd, @args) = @_;
        my ($chan, $nicks, $reason) = @args;

        my $bot = $ins->{bot};

        if ($nicks =~ /\,/) {
            my @tmp = split(/\,/, $nicks);

            foreach my $nick (@tmp) {
                $bot->kick($chan, $nick, $reason ? $reason : "");
            }
        } else {
            $bot->kick($chan, $nicks, $reason ? $reason : "");
        }
    }, $ins);
}

1;
