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
my $tcl  = Pepper->new($bot);

sub loader {
    require Pepper;
    $tcl = Pepper->new($bot);
    $tcl->init();

    # IRC commands
    $bot->add_handler('privcmd pepper', 'sp_irc_interface');
    $bot->add_handler('privcmd peval', 'sp_irc_eval');
    $bot->add_handler('chancmd peval', 'sp_irc_eval');

    # IRC event bindings
    $bot->add_handler('message channel', 'sp_pub');

    my $db = ${$dbi->read()};
    unless (exists($db->{Pepper})) {
        $db->{Pepper} = {
            scripts => {}
        };

        $dbi->write();
    }

    $dbi->free();
}

sub sp_irc_interface {
    my ($nick, $host, $text) = @_;
    my @asp = split(/ /, $text);

    return $bot->notice($nick, "Unauthorized.") unless ($bot->isbotadmin($nick, $host));

    if ($asp[0] =~ /load/i) {
        if (-e "./modules/Pepper/scripts/".$asp[1]) {
            my $res = $tcl->load("./modules/Pepper/scripts/".$asp[1]);

            if ($res->{ok}) {
                return $bot->notice($nick, "Loaded ".$asp[1]." successfully.");
            } else {
                return $bot->notice($nick, "Error loading ".$asp[1].": ".$res->{err});
            }
        } else {
            return $bot->notice($nick, "Error loading ".$asp[1].": No such file.");
        }
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

sub sp_pub {
    $tcl->event('pub', @_);
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

    delete $INC{'Pepper.pm'};
    delete $INC{'Pepper/Bindings.pm'};
}

1;
