package ShadowPepper;

# ShadowPepper - Shadow interface module for Pepper eggdrop TCL compatibility layer
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Copyright 2023 (C) Ephasic Software
#
# installdepends.pl macros:
#$INDEP[Tcl Digest::SHA LWP::Simple Net::Address::IP::Local] 
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

my $last_reap = 0;
my $setconnectevent = 0;
my $stime = time();

sub loader {
    require Pepper;

    # IRC commands
    $bot->add_handler('privcmd pepper', 'sp_irc_interface');
    $bot->add_handler('privcmd peval', 'sp_irc_eval');
    $bot->add_handler('chancmd peval', 'sp_irc_eval');

    # IRC event bindings
    $bot->add_handler('message channel', 'sp_pub');
    $bot->add_handler('message private', 'sp_priv');
    $bot->add_handler('ctcp dcc', 'sp_dcc');
    $bot->add_handler('event join', 'sp_join');
    $bot->add_handler('event part', 'sp_part');
    $bot->add_handler('event nick', 'sp_nick');
    $bot->add_handler('event nick_me', 'sp_nick_me');
    $bot->add_handler('event mode', 'sp_mode');
    $bot->add_handler('event ctcp', 'sp_ctcp');
    $bot->add_handler('event quit', 'sp_sign');

    unless ($bot->connected()) {
        $bot->add_handler('event connected', 'sp_connected');
        $setconnectevent = 1;
    } else {
        sp_connected();
    }

    # tick
    $bot->add_handler('event tick', 'sp_tick');

}

sub sp_init_tcl {
    $tcl = Pepper->new($bot, $dbi);
    $tcl->init();

    # set eggdrop global variables
    $tcl->setvar('botnick', $bot->nick());
    $tcl->setvar('botname', $bot->nick()."!".$bot->gethost($bot->nick()));

    # make this a config option?
    $tcl->setvar('numversion', 10120000);
    $tcl->setvar('version', "1.12.0-pepper");

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

sub sp_connected {
    my ($nick) = @_;

    sp_init_tcl();
}

sub sp_irc_interface {
    my ($nick, $host, $text) = @_;
    my @asp = split(/ /, $text);

    return $bot->notice($nick, "Unauthorized.") unless ($bot->isbotadmin($nick, $host));

    if ($asp[0] =~ /^load$/i) {
        if (-e "./modules/Pepper/scripts/".$asp[1]) {
            my $db = ${$dbi->read()};
            $db->{Pepper}->{scripts}->{$asp[1]} = {
                bindings => [],
                flags    => [],
                channels => []
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
    } elsif ($asp[0] =~ /^reload$/i) {
        if (sp_init_tcl()) {
            return $bot->notice($nick, "Reinitalized the Tcl interpreter.");
        } else {
            return $bot->notice($nick, "Error reinitalizing the Tcl interpreter, check logs.");
        }
    } elsif ($asp[0] =~ /^list$/i) {
        my $db = ${$dbi->read()};
        my @out;

        push(@out, "Pepper: Scripts");
        push(@out, "-------------------------------------");

        foreach my $k (keys(%{$db->{Pepper}->{scripts}})) {
            push(@out, " $k");
        }
        
        $dbi->free();
        $bot->fastnotice($nick, @out);
    } elsif ($asp[0] =~ /^chanset (\#.*?) (\+|\-)(.*?)$/) {
        my $db = ${$dbi->read()}->{Pepper};
        
        if ($2 eq '+') {
            if (exists($db->{flags}->{$3})) {
                push(@{$db->{flags}->{$3}}, $1);

                $bot->notice($nick, "Added $3 flag to $1.");
            } else {
                # $db->{flags}->{$3} = [$1];
                $bot->notice($nick, "Error: Invalid flag.");
            }

        } elsif ($2 eq '-') {
            if (exists($db->{flags}->{$3})) {
                my @tmp = @{$db->{flags}->{$3}};
                my @out;

                foreach my $chan (@tmp) {
                    push(@out, $chan) unless ($chan eq $1);
                }

                $db->{flags}->{$3} = \@out;
                $bot->notice($nick, "Removed $3 flag from $1.");
            } else {
                $bot->notice($nick, "Error: Invalid flag.");
            }
        } else {
            $bot->notice($nick, "Error: Invalid operation.");
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
    } elsif ($text =~ /^chanset (\#.*?) (\+|\-)(.*?)$/) {
        my $db = ${$dbi->read()}->{Pepper};
        
        if ($2 eq '+') {
            if (exists($db->{flags}->{$3})) {
                push(@{$db->{flags}->{$3}}, $1);

                $bot->notice($nick, "Added $3 flag to $1.");
            } else {
                # $db->{flags}->{$3} = [$1];
                $bot->notice($nick, "Error: Invalid flag.");
            }

        } elsif ($2 eq '-') {
            if (exists($db->{flags}->{$3})) {
                my @tmp = @{$db->{flags}->{$3}};
                my @out;

                foreach my $chan (@tmp) {
                    push(@out, $chan) unless ($chan eq $1);
                }

                $db->{flags}->{$3} = \@out;
                $bot->notice($nick, "Removed $3 flag from $1.");
            } else {
                $bot->notice($nick, "Error: Invalid flag.");
            }
        } else {
            $bot->notice($nick, "Error: Invalid operation.");
        }

        $dbi->write();
        $dbi->free();
    } else {
        return $bot->notice($nick, "\x02Usage:\x02 pepper <load|unload|list|chanset> [<script>|<channel> <+/-><flag>]");
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
    $tcl->event('pubm', $nick, $host, $handle, $chan, $text);
}

sub sp_priv {
    my ($nick, $host, $text) = @_;
    my $handle = 0;

    #    if ($text =~ /\001DCC\s(.*?)\s(.*?)\001/) {
    #    $tcl->{dcc}->handle_dcc_msg($tcl, $nick, $host, $1, $2);
    #} else {
        $tcl->event('msg', $nick, $host, $handle, $text);
    #}
}

sub sp_dcc {
    my ($nick, $host, $chan, $args) = @_;
    if (!$args) {
        $args = $chan;
        $chan = 0;
    }

    print "sb_dcc: $args\n";
    $tcl->{dcc}->handle_dcc_msg($tcl, $nick, $host, $chan, $args); 
}

sub sp_join {
    my ($nick, $host, $chan) = @_;
    my $handle = 0;

    $tcl->event('join', $nick, $host, $handle, $chan);
}

sub sp_part {
    my ($nick, $host, $chan, $text) = @_;
    my $handle = 0;

    $tcl->event('part', $nick, $host, $handle, $chan, $text);
}

sub sp_nick {
    my ($nick, $host, $newnick, @channels) = @_;
    my $handle = 0;

    foreach my $chan (@channels) {
        $tcl->event('nick', $nick, $host, $handle, $chan, $newnick);
    }
}

sub sp_nick_me {
    my ($nick, $host, $newnick) = @_;
    
    $tcl->setvar('botnick', $newnick);
}

sub sp_mode {
    my ($nick, $host, $chan, $action, @mode) = @_;
    my $handle = 0;

    my $len = length($mode[0]);
    my @msp = split(//, $mode[0]);

    for (my $i = 1; $i < $len; $i++) {
        $tcl->event('mode', $nick, $host, $handle, $chan, $action.$msp[$i], $mode[$i] ? $mode[$i] : '');
    }
}

sub sp_ctcp {
    my ($nick, $host, $dest, $cmd, $params) = @_;
    my $handle = 0;
    
    $tcl->event('ctcp', $nick, $host, $handle, $dest, $cmd, $params);
}

sub sp_sign {
    my ($nick, $host, $reason, @channels) = @_;
    my $handle = 0;

    foreach my $chan (@channels) {
        $tcl->event('sign', $nick, $host, $handle, $chan, $reason ? $reason : '');
    }
}

sub sp_tick {
    my ($tc) = @_;
    my $time = time();

    $tcl->dcc()->tick();
    $tcl->tick();

    if (($time - $stime) >= 60) {
        my @lt = localtime($time);
        $tcl->event('time', $lt[1], $lt[2], $lt[3], $lt[4], $lt[5] + 1900);
        $stime = $time;
    }
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
    $bot->del_handler('ctcp dcc', 'sp_dcc');
    $bot->del_handler('event join', 'sp_join');
    $bot->del_handler('event part', 'sp_part');
    $bot->del_handler('event nick', 'sp_nick');
    $bot->del_handler('event nick_me', 'sp_nick_me');
    $bot->del_handler('event mode', 'sp_mode');
    $bot->del_handler('event ctcp', 'sp_ctcp');
    $bot->del_handler('event quit', 'sp_sign');

    if ($setconnectevent) {
        $bot->del_handler('event connected', 'sp_connected');
    }

    # tick
    $bot->del_handler('event tick', 'sp_tick');

    delete $INC{'Pepper.pm'};
    delete $INC{'Pepper/Bindings.pm'};
}

1;
