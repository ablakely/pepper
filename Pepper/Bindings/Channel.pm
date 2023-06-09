package Pepper::Bindings::Channel;

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

    my $self = {
        hooked => 0,
        dbi    => 0
    };

    return bless($self, $class);
}

sub create_chan {
    my ($self, $chan) = @_;

    $chan = lc($chan);

    return 0 unless ($self->{hooked} && $self->{dbi});
    my $dbi = $self->{dbi};
    my $db  = ${$dbi->read()}->{Pepper}->{channels};

    unless (exists($db->{lc($chan)})) {
        $db->{lc($chan)} = {
            settings => {}
        };
        
        $dbi->write();
        $dbi->free();

        return 1;
    }

    $dbi->free();
    return 0;
}

sub hook {
    my ($self, $interp, $inst, $bot, $dbi) = @_;
    $self->{dbi} = $dbi;

    # check if channels hash table exists, if not create it
    my $db = ${$dbi->read()}->{Pepper};

    unless (exists($db->{channels})) {
        $db->{channels} = {};
        $dbi->write();
    }

    $dbi->free();


    # validchan <channel>
    # Description: checks if the bot has a channel record for the specified channel. Note that
    #              this does not necessarily mean that the bot is ON the channel.
    # Returns: 1 if the channel exists, 0 if not
    $interp->CreateCommand("validchan", sub {
        my ($ins, $intp, $tclcmd, @args) = @_;
        my ($chan) = @args;

        my $db = ${$dbi->read()}->{Pepper}->{channels};

        if (exists($db->{lc($chan)})) {
            return 1;
        }

        return 0;
    });

    # TODO: isdynamic
    # TODO: setudef
    # TODO: renudef
    # TODO: deludef
    # TODO: getudefs
    # TODO: chansettype

    $self->{hooked} = 1;
    return $inst;
}
1;

