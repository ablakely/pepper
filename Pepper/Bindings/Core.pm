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
    my ($class, $ins) = @_;

    my $self = {
        ins => $ins
    };

    return bless($self, $class);
}

sub hook {
    my ($self, $interp, $ins) = @_;

    $interp->CreateCommand("bind", sub {
        my ($ins, $intp, $tclcmd, @args) = @_;
        my ($type, $flags, $mask, $procname) = @args;

        my $self = $ins->{ins}->{self};
        my $bot  = $ins->{ins}->{bot};

        if (!$procname) {
            my @tmp = $self->{events}->{$type};

            for (my $i = 0; $i < scalar(@tmp); $i++) {
                $tmp[$i][4] = $tmp[$i][3];
                $tmp[$i][3] = 0; # hits = 0
            }

            return @tmp;
        } else {
            if (!grep(/^$procname$/, @{$self->{events}->{$type}})) {
                push(@{$self->{events}->{$type}}, @args);

                $bot->log("[Pepper::Tcl] Binding $type event $mask to $procname", "Modules");
                return $procname;
            } else {
                $bot->log("[Pepper::Tcl] Error: Cannot bind $type event $mask: $procname proc already exists", "Modules");
                return 0;
            }
        }
    }, $ins);
}

1;
