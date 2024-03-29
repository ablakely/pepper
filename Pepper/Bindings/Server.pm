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

    my $self = {
        hooked => 0,
        dbi    => 0
    };

    return bless($self, $class);
}



sub hook {
    my ($self, $interp, $inst, $bot, $dbi) = @_;
    $self->{dbi} = $dbi;

    # check if settings hash table exists, if not create it
    my $db = ${$dbi->read()}->{Pepper};

    unless (exists($db->{channels})) {
        $db->{servers} = {};
        $dbi->write();
    }

    $dbi->free();

    # putserv <text> [options]
    # Description: sends text to the server, like '.dump' (intended for direct server commands); output
    #              is queued so that the bot won't flood itself off the server.
    # Options: -next   - push messages to the front of the queue
    #          -normal - no effect
    # Returns: nothing
    $interp->CreateCommand("putserv", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($str, $flags) = @args;

        $bot->fastout($str."\r\n");
    });

    # puthelp <text> [options]
    # Description: sends text to the server, like 'putserv', but it uses a different queue intended for
    #              sending messages to channels or people.
    # Options: -next   - push messages to the front of the queue
    #          -normal - no effect
    # Returns: nothing
    $interp->CreateCommand("puthelp", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($str, $flags) = @args;

        chomp $str;
        $bot->raw($str."\r\n", 2);
    });

    # putquick <text> [options]
    # Description: sends text to the server, like 'putserv', but it uses a different (and faster) queue.
    # Options: -next   - push messages to the front of the queue
    #          -normal - no effect
    # Returns: nothing
    $interp->CreateCommand("putquick", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($str, $flags) = @args;

        chomp $str;
        $bot->raw($str."\r\n", 3);
    });

    # putnow <text> [-oneline]
    # Description: sends text to the server immediately, bypassing all queues. Use with caution,
    #              as the bot may easily flood itself off the server.
    # Options: -oneline - send text up to the first \r or \n, discarding the rest
    # Returns: nothing
    $interp->CreateCommand("putnow", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($str, $flags) = @args;

        chomp $str;
        $bot->fastout($str."\r\n");
    });

    # isbotnick <nick>
    # Returns: 1 if the nick matches the botnick; 0 otherwise
    $interp->CreateCommand("isbotnick", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($nick) = @args;

        if ($nick eq $bot->nick()) {
            return 1;
        }

        return 0;
    });

    # isupport <mode> [key]
    # Mode: get
    #   Returns: string containing the setting's value or 0 if not set; if a key
    #            is not specified returns a dict of settings for the server or 0
    # Mode: isset
    #   Returns: 1 if the specified key is set; 0 otherwise
    $interp->CreateCommand("isupport", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($mode, $key) = @args;
        my $db = ${$dbi->read()}->{Pepper}->{servers};
        my $srv = $bot->getserver();

        if ($mode =~ /^get$/i) {
            if ($key) {
                if (exists($db->{$srv}->{settings}->{$key})) {
                    $dbi->free();
                    return $db->{$srv}->{settings}->{$key};
                }
            } else {
                if (exists($db->{$srv}->{settings})) {
                    $dbi->free();
                    return $db->{$srv}->{settings};
                } 
            }
        } elsif ($mode =~ /^isset$/i && $key) {
            if (exists($db->{$srv}->{settings}->{$key})) {
                $dbi->free();
                return 1;
            }
        }

        $dbi->free();
        return 0;
    });

    $self->{hooked} = 1;
    return $inst;
}

1;
