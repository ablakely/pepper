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

    my $self = {
        hooked => 0,
        dbi    => 0
    };

    return bless($self, $class);
}

sub hook {
    my ($self, $interp, $inst, $bot, $dbi) = @_;
    $self->{dbi} = $dbi;

    # putkick <channel> <nick, nick, ...> [reason]
    # Description: sends kicks to the server and tries to put as many nicks into one kick command as possible.
    # Returns: nothing
    $interp->CreateCommand("putkick", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($chan, $nicks, $reason) = @args;


        if ($nicks =~ /\,/) {
            my @tmp = split(/\,/, $nicks);

            foreach my $nick (@tmp) {
                $bot->kick($chan, $nick, $reason ? $reason : "");
            }
        } else {
            $bot->kick($chan, $nicks, $reason ? $reason : "");
        }
    });

    # botisop [channel]
    # Returns: 1 if the bot has ops on the specified channel (or any channel if no channel is specified); 0 otherwise
    $interp->CreateCommand("botisop", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($chan) = @args;

        if ($chan) {
            if ($bot->isop($bot->nick(), $chan)) {
                return 1;
            } else {
                return 0;
            }
        } else {
            my @chans = $bot->channels();

            foreach my $tchan (@chans) {
                if ($bot->isop($bot->nick(), $tchan)) {
                    return 1;
                }
            }
        }

        return 0;
    });

    # botishalfop [channel]
    # Returns: 1 if the bot has halfops on the specified channel (or any channel if no channel is specified); 0 otherwise
    $interp->CreateCommand("botishalfop", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($chan) = @args;

        if ($chan) {
            if ($bot->ishop($bot->nick(), $chan)) {
                return 1;
            } else {
                return 0;
            }
        } else {
            my @chans = $bot->channels();

            foreach my $tchan (@chans) {
                if ($bot->ishop($bot->nick(), $tchan)) {
                    return 1;
                }
            }
        }

        return 0;
    });

    # botisvoice [channel]
    # Returns: 1 if the bot has voice on the specified channel (or any channel if no channel is specified); 0 otherwise
    $interp->CreateCommand("botisvoice", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($chan) = @args;

        if ($chan) {
            if ($bot->isvoice($bot->nick(), $chan)) {
                return 1;
            } else {
                return 0;
            }
        } else {
            my @chans = $bot->channels();

            foreach my $tchan (@chans) {
                if ($bot->isvoice($bot->nick(), $tchan)) {
                    return 1;
                }
            }
        }

        return 0;
    });

    # botonchan [channel]
    # Returns: 1 if the bot is on the specified channel (or any channel if no channel is specified); 0 otherwise
    $interp->CreateCommand("botonchan", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($chan) = @args;

        if ($chan) {
            if ($bot->isin($chan, $bot->nick())) {
                return 1;
            } else {
                return 0;
            }
        } else {
            my @chans = $bot->channels();

            if (scalar(@chans) > 0) {
                return 1;
            }
        }

        return 0;
    });

    # isop <nickname> [channel]
    # Returns: 1 if someone by the specified nickname in on the channel (or any channel if no channel name
    #          is specified) and has ops; 0 otherwise
    $interp->CreateCommand("isop", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($nick, $chan) = @args;

        if (substr($chan, 0, 1) eq "#") {
            if ($bot->isop($nick, $chan)) {
                return 1;
            } else {
                return 0;
            }
        } else {
            my @chans = $bot->channels();

            foreach my $tchan (@chans) {
                if ($bot->isop($nick, $tchan)) {
                    return 1;
                }
            }
        }

        return 0;
    });
    
    # ishalfop <nickname> [channel]
    # Returns: 1 if someone by the specified nickname in on the channel (or any channel if no channel name
    #          is specified) and has halfops; 0 otherwise
    $interp->CreateCommand("ishalfop", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($nick, $chan) = @args;

        if (substr($chan, 0, 1) eq "#") {
            if ($bot->ishop($nick, $chan)) {
                return 1;
            } else {
                return 0;
            }
        } else {
            my @chans = $bot->channels();

            foreach my $tchan (@chans) {
                if ($bot->ishop($nick, $tchan)) {
                    return 1;
                }
            }
        }

        return 0;
    });

    # isvoice <nickname> [channel]
    # Returns: 1 if someone by the specified nickname in on the channel (or any channel if no channel name
    #          is specified) and has voice; 0 otherwise
    $interp->CreateCommand("isvoice", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($nick, $chan) = @args;

        if (substr($chan, 0, 1) eq "#") {
            if ($bot->isvoice($nick, $chan)) {
                return 1;
            } else {
                return 0;
            }
        } else {
            my @chans = $bot->channels();

            foreach my $tchan (@chans) {
                if ($bot->isvoice($nick, $tchan)) {
                    return 1;
                }
            }
        }

        return 0;
    });

    # onchan <nickname> [channel]
    # Returns: 1 if someone by that nickname is on the specified channel (or any channel if none is
    #          is specified); 0 otherwise 
    $interp->CreateCommand("onchan", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($nick, $chan) = @args;

        if (substr($chan, 0, 1) eq "#") {
            if ($bot->isin($chan, $nick)) {
                return 1;
            } else {
                return 0;
            }
        } else {
            my @chans = $bot->channels();

            foreach my $tchan (@chans) {
                if ($bot->isin($chan, $nick)) {
                    return 1;
                }
            }
        }

        return 0;
    });

    # getchanhost <nickname> [channel]
    # Returns: user@host of the specified nickname (the nickname is not included in the returned host). If a
    #          channel is not specified, bot will check all of it's channels. If the nickname is not on the
    #          channel(s), "" is returned.
    #
    # Note: This implementation ignores channel argument and returns the first match or ""
    $interp->CreateCommand("getchanhost", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($nick, $chan) = @args;

        my $host = $bot->gethost($nick);
        return $host ? $host : "";
    });

    # getchanjoin <nickname> <channel>
    # Returns: timestamp (unixtime format) of when the specified nickname joined the channel if available,
    #          0 otherwise. Note that after a channel reset this information will be lost, if previously
    #          availabel.
    $interp->CreateCommand("getchanjoin", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($nick, $chan) = @args;

        return $bot->getjointime($nick, $chan);
    });

    # chanlist <channel> [flags][<&|>chanflags]
    # Description: flags are any global flags; the '&' or '|' denotes to look for channel specific flags,
    #              where '&' will return users having ALL chanflags and '|' returns users having ANY of the
    #              chanflags (See matchattr above for additional examples).
    #
    # Returns: Searching for flags optionally preceded with a ‘+’ will return a list of nicknames that have all the
    #          flags listed. Searching for flags preceded with a ‘-‘ will return a list of nicknames that do not 
    #          have any of the flags (differently said, ‘-‘ will hide users that have all flags listed). If no flags
    #          are given, all of the nicknames on the channel are returned.
    #
    # Please note that if you’re executing chanlist after a part or sign bind, the gone user will still be listed,
    # so you can check for wasop, isop, etc.     
    $interp->CreateCommand("chanlist", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($chan, $flags) = @args;

        return $bot->log("Error: chanlist not implemented.");
    });

    # getchanidle <nickname> <channel>
    # Returns: number of minutes that person has been idle; -1 if the specified user isn't on the channel
    $interp->CreateCommand("getchanidle", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($nick, $chan) = @args;

        return $bot->getidle($nick, $chan);
    });

    # getchanmode <channel>
    # Returns: string of the type "+ntik key" for the channel specified; "" otherwise
    $interp->CreateCommand("getchanmode", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($chan) = @args;

        my $modes = $bot->modes($chan);
        return $modes ? $modes : "";
    });

    # topic <channel>
    # Returns: string containing the current topic of the specified channel; "" if not set o
    #          the bot is not in the channel
    $interp->CreateCommand("topic", sub {
        my ($tmp, $intp, $tclcmd, @args) = @_;
        my ($chan) = @args;

        my $topic = $bot->topic($chan);
        return $topic ? $topic : "";
    });

    # TODO: wasop
    # TODO: washalfop
    # TODO: isidentifed
    # TODO: isaway
    # TODO: isircbot
    # TODO: monitor
    # TODO: getaccount
    # TODO: nick2hand
    # TODO: account2nicks
    # TODO: hand2nick
    # TODO: handonchan
    # TODO: ischanexempt
    # TODO: ischaninvite
    # TODO: chanbans
    # TODO: chanexempts
    # TODO: chaninvites
    # TODO: resetbans
    # TODO: resetexempts
    # TODO: resetinvites
    # TODO: resetchanidle
    # TODO: resetchanjoin
    # TODO: resetchan
    # TODO: refreshchan
    # TODO: onchansplit
    # TODO: pushmode
    # TODO: flushmode

    $self->{hooked} = 1;
    return $inst;
}

1;
