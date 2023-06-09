package ShadowPepper;

# ShadowPepper - Shadow interface module for Pepper eggdrop TCL compatibility layer
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Copyright 2023 (C) Ephasic Software
#
# installdepends.pl macros:
#$INDEP[Tcl] 
#$INSCRIPT[bash]
#  if [ ! -d "./modules/Pepper" ]; then
#    git clone https://github.com/ablakely/Pepper ./modules/Pepper
#    ln -s ./modules/Pepper/ShadowPepper.pm ./modules/ShadowPepper.pm
#  fi
#$INSCRIPT

use strict;
use warnings;

use lib './modules/Pepper';

use Shadow::Core;
use Shadow::Help;
use Shadow::DB;

use Pepper;


my $bot  = Shadow::Core->new();
my $help = Shadow::Help->new();
my $dbi  = Shadow::DB->new();
our $tcl  = Pepper->new($bot);

sub loader {
    require Pepper;
    sp_init_tcl();

    # IRC commands
    $bot->add_handler('privcmd pepper', 'sp_irc_interface');
    $bot->add_handler('privcmd peval', 'sp_irc_eval');
    $bot->add_handler('chancmd peval', 'sp_irc_eval');

    # IRC event bindings
    $bot->add_handler('message channel', 'sp_pub');
    $bot->add_handler('message private', 'sp_priv');

}

sub sp_init_tcl {
    $tcl = Pepper->new($bot, $dbi);
    $tcl->init();

    my $db = ${$dbi->read()};
    unless (exists($db->{Pepper})) {
        $db->{Pepper} = {
            scripts  => {},
            channels => {},
            servers  => {}
        };

        $dbi->write();
    } else {
        my $res;

        foreach my $script (keys(%{$db->{Pepper}->{scripts}})) {
            $res = $tcl->load("./modules/Pepper/scripts/".$script);

            if ($res->{ok}) {
                $bot->log("[Pepper] Loaded Tcl script: $script", "System");
            } else {
                $bot->log("[Pepper] Error loading Tcl script [$script]: ".$res->{err}, "System");

                return 0;
            }
        }
    }

    $dbi->free();
    return 1;
}

sub sp_irc_interface {
    my ($nick, $host, $text) = @_;
    my @asp = split(/ /, $text);

    return $bot->notice($nick, "Unauthorized.") unless ($bot->isbotadmin($nick, $host));

    if ($asp[0] =~ /^load$/i) {
        if (-e "./modules/Pepper/scripts/".$asp[1]) {
            my $db = ${$dbi->read()};
            $db->{Pepper}->{scripts}->{$asp[1]} = {
                bidings => []
            };
            $dbi->write();
            $dbi->free();

            my $res = $tcl->load("./modules/Pepper/scripts/".$asp[1]);

            if ($res->{ok}) {
                return $bot->notice($nick, "Loaded ".$asp[1]." successfully.");
            } else {
                return $bot->notice($nick, "Error loading ".$asp[1].": ".$res->{err});
            }
        } else {
            return $bot->notice($nick, "Error loading ".$asp[1].": No such file.");
        }
    } elsif ($asp[0] =~ /^unload$/i) {
        my $db = ${$dbi->read()};

        if (exists($db->{Pepper}->{scripts}->{$asp[1]})) {
            delete $db->{Pepper}->{scripts}->{$asp[1]};

            $dbi->write();
            $dbi->free();

            if (sp_init_tcl()) {
                return $bot->notice($nick, "Removed $asp[1] and reinitalized the Tcl interpreter.");
            } else {
                return $bot->notice($nick, "Error reinitalizing the Tcl interpreter, check logs.");
            }
        }
    } elsif ($asp[0] =~ /^list$/) {
        my $db = ${$dbi->read()};
        my @out;

        push(@out, "Pepper: Scripts");
        push(@out, "-------------------------------------");

        foreach my $k (keys(%{$db->{Pepper}->{scripts}})) {
            push(@out, " $k");
        }
        
        $dbi->free();
        $bot->fastnotice($nick, @out);
    } else {
        return $bot->notice($nick, "\x02Usage:\x02 pepper <load|unload|list> [<script>]");
    }
}

sub sp_irc_eval {
    my ($nick, $host, $chan, $text) = @_;

    return 0 unless ($bot->isbotadmin($nick, $host));

    if (!$text) {
        $text = $chan;
        $chan = 0;
    }

    my $res = $tcl->eval($text);
    if ($res->{err}) {
        $bot->notice($nick, "Tcl Error: ".$res->{err});
    }
}

# IRC event handlers
sub sp_pub {
    my ($nick, $host, $chan, $text) = @_;
    my $handle = 0;

    $tcl->event('pub', $nick, $host, $handle, $chan, $text);
}

sub sp_priv {
    my ($nick, $host, $text) = @_;
    my $handle = 0;

    $tcl->event('msg', $nick, $host, $handle, $text);
}



sub unloader {
    $tcl->destroy();
    $dbi->free();

    # IRC commands
    $bot->del_handler('privcmd pepper', 'sp_irc_interface');
    $bot->del_handler('privcmd peval', 'sp_irc_eval');
    $bot->del_handler('chancmd peval', 'sp_irc_eval');

    # IRC events
    $bot->del_handler('message channel', 'sp_pub');
    $bot->del_handler('message private', 'sp_priv');

    delete $INC{'Pepper.pm'};
    delete $INC{'Pepper/Bindings.pm'};
}

1;
