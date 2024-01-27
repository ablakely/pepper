package Pepper;

use strict;
use warnings;
use Carp;
use Tcl;

use lib './modules';
use lib './modules/Pepper';

use Pepper::Bindings;
use Pepper::DCC;

sub new {
    my ($class, $bot, $dbi) = @_;

    my $dcc_port = 1024;
    my $cfg      = $bot->getcfg();
    
    if (exists($cfg->{Modules}->{Pepper}->{dcc}->{port})) {
        $dcc_port = $cfg->{Modules}->{Pepper}->{dcc}->{port};
    }

    my $self = {
        interp     => Tcl->new,
        bindings   => Pepper::Bindings->new(),
        dcc        => $bot ? Pepper::DCC->new($bot, $dcc_port, "./dcc-downloads/") : 0,
        initalized => 0,
        bot        => $bot ? $bot : 0,
        dbi        => $dbi ? $dbi : 0
    };

    $self->{interp}->Init();

    return bless($self, $class);
}

sub _check_match {
    my ($self, $mask1, $mask2, $checkchan) = @_;

    print "checking $mask1 against $mask2\n";

    if ($mask1 eq "*" or $mask2 eq "*") {
        return 1;
    }

    if ($mask1 =~ /$mask2/i or $mask2 =~ /$mask1/i) {
        return 1;
    }
    my $chan = "";

    # split the masks into their components
    
    # check for channel in mask1 seperated by a space
    if ($mask1 =~ / /) {
        ($chan, $mask1) = split(/ /, $mask1);
        print "$chan - $checkchan\n";
    }

    my ($tmp, $m1nick, $m1user, $m1host, $m2nick, $m2user, $m2host);
    ($m1nick, $tmp) = split(/!/, $mask1);
    ($m1user, $m1host) = split(/@/, $tmp);
    ($m2nick, $tmp) = split(/!/, $mask2);
    ($m2user, $m2host) = split(/@/, $tmp);

    # check for wildcard * in nick, user, and host
    if ($m1nick =~ /\*/) {
        $m1nick =~ s/\*/.*?/g;
    }

    if ($m1user =~ /\*/) {
        $m1user =~ s/\*/.*?/g;
    }

    if ($m1host =~ /\*/) {
        $m1host =~ s/\*/.*/g;
    }

    # check for wildcard * in nick, user, and host
    if ($m2nick =~ /\*/) {
        $m2nick =~ s/\*/.*?/g;
    }

    if ($m2user =~ /\*/) {
        $m2user =~ s/\*/.*?/g;
    }

    if ($m2host =~ /\*/) {
        $m2host =~ s/\*/.*/g;
    }

    print "comparing $m1nick!$m1user\@$m1host to $m2nick!$m2user\@$m2host\n";

    if ($m1nick =~ /$m2nick/i or $m2nick =~ /$m1nick/i) {
        if ($m1user =~ /$m2user/i or $m2user =~ /$m1user/i) {
            if ($m1host =~ /$m2host/i or $m2host =~ /$m1host/i) {

                if ($checkchan && $chan) {
                    print "comparing $chan to $checkchan\n";
                    if ($chan =~ /$checkchan/i) {
                        return 1;
                    }
                } else {
                    return 1;
                }
            }
        }
    }

    return 0;
}

sub _check_time {
    my ($self, $v1, $v2) = @_;
    
    print "comparing $v1 to $v2\n";
    # TODO: check for ? and short args

    # check for wildcard * in v1 and v2
    if ($v1 =~ /\*/) {
        $v1 =~ s/\*/.*?/g;
    }

    if ($v2 =~ /\*/) {
        $v2 =~ s/\*/.*?/g;
    }

    # splt time into its components
    # [min hour day month year]
    my @t1 = split(/ /, $v1);
    my @t2 = split(/ /, $v2);

    # compare each component
    for (my $i = 0; $i < 5; $i++) {
        if ($t1[$i] =~ /$t2[$i]/i or $t2[$i] =~ /$t1[$i]/i) {
            next;
        } else {
            return 0;
        }
    }

    return 1;
}


sub dcc {
    my $self = shift;

    return $self->{dcc};
}

sub init {
    my ($self) = @_;
    return if ($self->{initalized});

    $self->{initalized} = 1;
    $self->{bindings}->hook($self);
}

sub destroy {
    my ($self) = @_;

    $self->{initalized} = 0;
    $self->{dcc} = 0;
    $self->{bindings}->unload();

    delete $INC{'Pepper/DCC.pm'};
}

sub eval {
    my ($self, $code) = @_;

    my $interp = $self->{interp};
    my $ret = {
        err => 0,
        ok => 0
    };

    CORE::eval "\$interp->Eval(\$code);";
    if ($@) {
        $ret->{err} = $@;
    }

    $ret->{ok} = 1;
    return $ret;
}

sub setvar {
    my ($self, $var, $val) = @_;

    my $interp = $self->{interp};
    my $ret = {
        err => 0,
        ok => 0
    };

    CORE::eval "\$interp->SetVar(\$var, \$val);";
    if ($@) {
        $ret->{err} = $@;
    }

    $ret->{ok} = 1;
    return $ret;
}

sub load {
    my ($self, $file) = @_;

    my $interp = $self->{interp};
    my $ret = {
        err => 0,
        ok => 0
    };

    CORE::eval "\$interp->EvalFile(\$file);";
    if ($@) {
        $ret->{err} = $@;
    }


    $ret->{ok} = $ret->{err} ? 0 : 1;
    return $ret;
}

sub event {
    my ($self, $evtype, @args) = @_;

    my $interp = $self->{interp};
    my @events = $self->{bindings}->get_events($evtype);
    
    my $ret = {
        err => 0,
        ok => 0
    };

    if ($evtype eq "pub") {
        my ($nick, $host, $hand, $chan, $text) = @args;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($text =~ /^$mask/) {
                        $text =~ s/^$mask//;
                        $text =~ s/^\s//;
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$chan, \$text);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } elsif ($evtype eq "msg") {
        my ($nick, $host, $handle, $text) = @_;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($text =~ /^$mask/) {
                        $text =~ s/^$mask//;
                        $text =~ s/^\s//;
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$text);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } elsif ($evtype eq "join") {
        my ($nick, $host, $hand, $chan) = @args;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($self->_check_match($mask, $host, $chan)) {
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$chan);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } elsif ($evtype eq "part") {
        my ($nick, $host, $hand, $chan, $text) = @args;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($self->_check_match($mask, $host, $chan)) {
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$chan, \$text);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } elsif ($evtype eq "nick") {
        my ($nick, $host, $hand, $chan, $newnick) = @args;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($self->_check_match($mask, $host, $chan)) {
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$chan, \$newnick);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } elsif ($evtype eq "mode") {
        my ($nick, $host, $hand, $chan, $mode, $arg) = @args;

        $arg = "" unless $arg;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($self->_check_match($mask, $host, $chan)) {
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$chan, \$mode, \$arg);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } elsif ($evtype eq "ctcp") {
        my ($nick, $host, $hand, $dest, $ctcpcmd, $ctcptext) = @args;

        $ctcptext = "" unless $ctcptext;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($self->_check_match($mask, $ctcpcmd)) {
                        print "ctcp debug: [$ctcpcmd] [$ctcptext]\n";
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$dest, \$ctcpcmd, \$ctcptext);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } elsif ($evtype eq "sign") {
        my ($nick, $host, $hand, $chan, $reason) = @args;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    print "$type $flags $mask $procname\n";

                    if ($self->_check_match($mask, "$chan $host")) {
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$chan, \$reason);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } elsif ($evtype eq "pubm") {
        my ($nick, $host, $hand, $chan, $text) = @args;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($self->_check_match($mask, $text)) {
                        CORE::eval "\$interp->call(\$procname, \$nick, \$host, \$hand, \$chan, \$text);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } elsif ($evtype eq "time") {
        my ($min, $hour, $day, $month, $year) = @args;

        for (my $i = 0; $i < scalar(@events); $i++) {
            if ($events[$i]) {
                foreach my $aref (@{$events[$i]}) {
                    my ($type, $flags, $mask, $procname) = @{$aref};

                    if ($self->_check_time($mask, "@args")) {
                        CORE::eval "\$interp->call(\$procname, \$min, \$hour, \$day, \$month, \$year);";
                        if ($@) {
                            $ret->{err} = $@;
                            return $ret;
                        }
                    }
                }
            }
        }
    } else {
        $ret->{err} = "Unimplemented bind handler: $evtype";
        return $ret;
    }

    $ret->{ok} = 1;
    return $ret;
}

sub tick {
    my ($self) = @_;

    $self->{bindings}->tick();
}

1;
