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
        }
    };

    return bless($self, $class);
}

sub hook {
    my ($self, $interp, $inst, $bot) = @_;

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

    return $inst;
}

1;
