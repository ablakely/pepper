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

    $interp->CreateCommand("putserv", sub {
        my ($ins, $intp, $tclcmd, @args) = @_;
        my ($str, $flags) = @args;

        my $bot = $ins->{bot};

        $bot->raw($str."\r\n", 1);
    }, $ins);

    $interp->CreateCommand("puthelp", sub {
        my ($ins, $intp, $tclcmd, @args) = @_;
        my ($str, $flags) = @args;

        my $bot = $ins->{bot};

        chomp $str;
        $bot->raw($str."\r\n", 2);
    }, $ins);

    $interp->CreateCommand("putquick", sub {
        my ($ins, $intp, $tclcmd, @args) = @_;
        my ($str, $flags) = @args;

        my $bot  = $ins->{bot};

        chomp $str;
        $bot->raw($str."\r\n", 3);
    }, $ins);

    $interp->CreateCommand("putnow", sub {
        my ($ins, $intp, $tclcmd, @args) = @_;
        my ($str, $flags) = @args;

        my $bot  = $ins->{bot};

        chomp $str;
        $bot->fastout($str."\r\n", 3);
    }, $ins);

    return $inst;
}

1;
