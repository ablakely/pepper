package Pepper::Bindings::Core;

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
        stackable => {
            msgm => 1, pubm => 1, notc => 1, 'join' => 1, part => 1, sign => 1, topc => 1, kick => 1, nick => 1,
            mode => 1, ctcp => 1, ctcr => 1, raw => 1, chon => 1, chof => 1, sent => 1, rcvd => 1, chat => 1,
            link => 1, disc => 1, splt => 1, rejn => 1, filt => 1, need => 1, flud => 1, note => 1, act => 1,
            wall => 1, bcst => 1, chjn => 1, chpt => 1, time => 1, away => 1, load => 1, unld => 1, nkch => 1,
            evnt => 1, lost => 1, tout => 1, out => 1, cron => 1, log => 1, tls => 1, die => 1, ircaway => 1,
            invt => 1, rawt => 1, account => 1, isupport => 1, monitor => 1, msg  => 0, dcc => 0, fil => 0, pub => 0
        },
        hooked => 0,
        dbi => 0,
        utimers => {},
        timers => {}
    };

    return bless($self, $class);
}

sub hook {
    my ($self, $interp, $inst, $bot, $dbi) = @_;
    $self->{dbi} = $dbi;

    foreach my $k (keys %{$self->{stackable}}) {
        $inst->{events}->{$k} = [];
    }

    $interp->CreateCommand("bind", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($type, $flags, $mask, $procname) = @args;

        if (!$procname) {
            my @tmp = $inst->{events}->{$type};

            for (my $i = 0; $i < scalar(@tmp); $i++) {
                $tmp[$i][4] = $tmp[$i][3];
                $tmp[$i][3] = 0; # hits = 0
            }

            return @tmp;
        } else {
            if (exists($inst->{events}->{$type})) {
                if (!exists($self->{stackable}->{$type})) {
                    for (my $i = 0; $i < scalar(@{$inst->{events}->{$type}}); $i++) {
                        my @tmp = @{$inst->{events}->{$type}[$i]};

                        if ($tmp[2] eq $mask) {
                            $bot->log("[Pepper::Tcl] Error: Cannot bind $procname to $type event: $mask already exists and is not stackable.", "Modules");
                            return 0;
                        }
                    }
                } 
            } else {
                $inst->{events}->{$type} = [];
            }

            push(@{$inst->{events}->{$type}}, \@args);

            $bot->log("[Pepper::Tcl] Binding $type event $mask to $procname", "Modules");
            return $procname;
        }
    });

    $interp->CreateCommand("unbind", sub {
        
    });

    $interp->CreateCommand("putlog", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($text) = @args;

        $bot->log($text);
    });


    # putloglev <flag(s)> <channel> <text>
    # Description: logs <text> to the logfile and partyline at the log level of the specified flag.
    #              Use "*" in lieu of a flag to indicate all log levels.
    #
    #              NOTE: The eggdrop docs do not specify the use of channel, so it is ignored.
    # Returns: nothing
    $interp->CreateCommand("putloglev", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($flags, $channel, $text) = @args;

        $bot->log("[Pepper::Tcl] putloglev: $flags $channel $text", "Modules");

        if ($flags eq "d") {
            $bot->log("[Pepper::Tcl] putloglev: Debug: $text", "Modules");
        } else {
            $bot->log("[Pepper::Tcl] Uninmplemented putloglev flag $flags: $text", "Modules");
        }

        $bot->log($text, $channel, $flags);
    });



    # rand <limit>
    # Returns: a random integer between 0 and limit-1. 
    #          Limit must be greater than 0 and equal to or less than RAND_MAX, which is generally 2147483647. 
    #          The underlying pseudo-random number generator is not cryptographically secure.
    $interp->CreateCommand("rand", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($limit) = @args;

        return int(rand($limit));
    });

    # utimer <seconds> <tcl-command> [count [timerName]]
    # Description: executes the given Tcl command after a certain number of seconds have passed. If count is specified,
    #              the command will be executed count times with the given interval in between. If you specify a count of 0,
    #              the utimer will repeat until it's removed with killutimer or until the bot is restarted. If timerName
    #              is specified, it will become the unique identifier for the timer. If timerName is not specified, 
    #              Eggdrop will assign a timerName in the format of "timer<integer>".
    # Returns: a timerName
    $interp->CreateCommand("utimer", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($seconds, $cb, $count, $timerName) = @args;

        if (!$timerName) {
            $timerName = "timer" . scalar(keys %{$self->{utimers}});
        }

        push(@{$self->{utimers}->{$timerName}}, [$seconds, $cb, $count, $timerName]);

        $bot->log("[Pepper::Tcl] utimer: $seconds $tclcmd $count $timerName", "Modules");

        return $timerName;
    });

    # timer <minutes> <tcl-command> [count [timerName]]
    # Description: executes the given Tcl command after a certain number of minutes have passed, at the top of the minute
    #              (ie, if a timer is started at 10:03:34 with 1 minute specified, it will execute at 10:04:00. If a timer is started 
    #              at 10:06:34 with 2 minutes specified, it will execute at 10:08:00). If count is specified, the command will be
    #              executed count times with the given interval in between. If you specify a count of 0, the timer will repeat until 
    #              it's removed with killtimer or until the bot is restarted. If timerName is specified, it will become the unique 
    #              identifier for the timer. If no timerName is specified, Eggdrop will assign a timerName in the 
    #              format of "timer<integer>".
    # Returns: a timerName
    $interp->CreateCommand("timer", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($minutes, $cb, $count, $timerName) = @args;

        if (!$timerName) {
            $timerName = "timer" . scalar(keys %{$self->{timers}});
        }

        push(@{$self->{timers}->{$timerName}}, [$minutes, $cb, $count, $timerName]);

        $bot->log("[Pepper::Tcl] timer: $minutes $tclcmd $count $timerName", "Modules");

        return $timerName;
    });

    # timers
    # Description: lists all active minutely timers.
    # Returns: a list of active minutely timers, with each timer sub-list containing the number of minutes left
    #          until activation, the command that will be executed, the timerName, and the remaining number of repeats.
    $interp->CreateCommand("timers", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;

        my @timers = ();

        foreach my $timer (keys %{$self->{timers}}) {
            my $t = $self->{timers}->{$timer};

            push(@timers, [$t->[0], $t->[1], $t->[3], $t->[2]]);
        }

        return @timers;
    });

    # timers
    # Description: lists all active minutely timers.
    # Returns: a list of active minutely timers, with each timer sub-list containing the number of minutes left
    #          until activation, the command that will be executed, the timerName, and the remaining number of repeats.
    $interp->CreateCommand("utimers", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;

        my @timers = ();

        foreach my $timer (keys %{$self->{utimers}}) {
            my $t = $self->{utimers}->{$timer};

            push(@timers, [$t->[0], $t->[1], $t->[3], $t->[2]]);
        }

        return @timers;
    });

    # matchaddr <hostmask> <address>
    # Description: checks if the address matches the hostmask given. The address should be in the form nick!user@host.
    # Returns: 1 if the address matches the hostmask, 0 otherwise.
    $interp->CreateCommand("matchaddr", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($hostmask, $address) = @args;

        # remove { and } from the hostmask and address
        $hostmask =~ s/^\{//;
        $hostmask =~ s/\}$//;
        $address =~ s/^\{//;
        $address =~ s/\}$//;

        return $inst->{_pepper}->_check_match($hostmask, $address);
    });

    # validuser <handle>
    # Returns: 1 if a user by that name exists; 0 otherwise
    $interp->CreateCommand("validuser", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($handle) = @args;

        # TODO:
        # return $inst->{_pepper}->_check_validuser($handle);

        return 0;
    });


    $self->{hooked} = 1;
    return $inst;
}

1;
