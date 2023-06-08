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

    my $self = {};

    return bless($self, $class);
}

sub hook {
    my ($self, $interp, $inst, $bot) = @_;

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
                for (my $i = 0; $i < scalar(@{$inst->{events}->{$type}}); $i++) {
                    my @tmp = @{$inst->{events}->{$type}[$i]};

                    if ($tmp[2] eq $mask && $tmp[3] eq $procname) {
                        $bot->log("[Pepper::Tcl] Error: Cannot bind $type event $mask: $procname proc already exists", "Modules");
                        return 0;
                    }
                }
            } else {
                $inst->{events}->{$type} = ();
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
