package Pepper::DCC;

# Pepper::DCC - Direct client-to-client protocol implementation
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Copyright 2023 (C) Ephasic Software

use strict;
use warnings;
use Carp;
use IO::Select;
use IO::Socket::INET;
use Digest::SHA;
use LWP::Simple;

sub new {
    my ($class, $bot, $dcc_port, $dl_dir) = @_;
    my $self = {
        bot       => $bot,
        dl_dir    => $dl_dir,
        offers    => {},
        ports     => {},
        pmin      => 1024,
        pmax      => 65535,
        sel       => IO::Select->new()
    };

    # create dl_dir if it doesn't exists
    if (!-e $dl_dir) {
        system $^O =~ /msys|MSWin32/ ? "mkdir $dl_dir" : "mkdir -p $dl_dir";
    }

    return bless($self, $class);
}

sub dccport {
    my $self = shift;

    # return a randon number beteween $self->{pmin} and $self->{pmax}
    my $port = int(rand($self->{pmax} - $self->{pmin})) + $self->{pmin};

    while (exists($self->{ports}->{$port})) {
        $port = int(rand($self->{pmax} - $self->{pmin})) + $self->{pmin};
    }

    $self->{ports}->{$port} = 1;
    return $port;
}

sub nbo_to_ip {
    my ($nbo) = @_;
    return join('.', unpack('C4', pack('N', $nbo)));
}

sub ip_to_nbo {
    my ($ip) = @_;
    my @octets = split(/\./, $ip);
    my $nbo = ($octets[0] << 24) | ($octets[1] << 16) | ($octets[2] << 8) | $octets[3];
    return $nbo;
}

sub file_sha256 {
    my ($filename) = @_;
    open(my $fh, '<', $filename) or die "Can't open file $filename: $!";
    binmode($fh);
    my $sha256 = Digest::SHA->new(256);
    $sha256->addfile($fh);
    return $sha256->hexdigest;
}

sub get_public_ip {
    my $url = 'http://checkip.dyndns.org/';
    my $content = get($url);
    if ($content =~ /Current IP Address: ([\d\.]+)/) {
        return $1;
    }
    return 0;
}

sub findActiveInterface {
    if ($^O =~ /nux|nix$/) {
        my $routebin = "/usr/sbin/route";
        my @routing = `$routebin`;

        shift(@routing); # remove: Kenerel IP...
        shift(@routing); # remove table descriptions

        foreach my $r (@routing) {
            chomp $r;
            if ($r =~ /default(?:\s+)(.*?)(?:\s+)(.*?)(?:\s+)(.*?)(?:\s+)(.*?)(?:\s+)(.*?)(?:\s+)(.*?)(?:\s+)(.*)/) {
                return $7;
            }
        }

        return 0;
    }
}

sub getLocalAddr {
    my $activeInterface = findActiveInterface();

    if ($^O =~ /nix|nux/) {
        my @tmp = `ip addr show $activeInterface`;

        foreach my $line (@tmp) {
            if ($line =~ /inet\s(.*?)\//) {
                return $1;
            }
        }
    }

    return 0;
}

sub child_is_zombie {
    my $pid = shift;
    my $stat = `ps -p $pid -o stat=`; # Get the process status
    return $stat =~ /Z/; # Check if the status contains "Z" for zombie
}

sub offerfile {
    my ($self, $target, $file) = @_;
    my $bot = $self->{bot};
    return 0 unless (-e $file);

    my $port = $self->dccport();
    foreach my $k (keys(%{$self->{offers}})) {
        if ($k =~ /$target/) {
            delete($self->{ports}->{$port});
            $port = (split(/\:/, $k))[1];
        }
    }

    # << PRIVMSG MSLTester :DCC SEND lock.jpg 199 0 71218
    my $fsize = (stat $file)[7];
    
    my $fname = (split(/\//, $file))[-1];
    $fname =~ s/ /\_/g;

    my $ip = ip_to_nbo(getLocalAddr() || get_public_ip());

    my @out;
    push(@out, "\001DCC SEND $fname $ip $port $fsize\001");
    push(@out, "SHA-256 checksum for $fname (remote): ".file_sha256($file)); 
    $bot->fastsay($target, @out);

    if (!exists($self->{offers}->{"$target:$port"})) {
        $self->{offers}->{"$target:$port"} = {
            port => $port,
            size => $fsize,
            file => $file,
            target => $target,
            ip   => 0,
            sent => 0,
            pid  => 0,
            pipe => 0,
            finished => 0
        };
        $self->resumefile($target, 0, $port, $file, 0);
        return 0;
    }

    return 1;
}

sub recvfile {
    my ($self, $target, $ip, $port, $file, $pos) = @_;
    my $bot = $self->{bot};

    $pos = $pos ? $pos : 0;

    if ($ip !~ /\:\./g) {
        $ip = nbo_to_ip($ip);
    }

    my $pid = fork();
    if ($pid == 0) {
        print "[Pepper::DCC] [$$] Forked successfully, sending $file to $target [$ip]\n";
        my $sock;

        unless($sock = IO::Socket::INET->new(
            PeerAddr => $ip,
            PeerPort => $port,
            Proto => 'tcp'
        )) {
            $bot->err("[Pepper::DCC] [$$] Error opening DCC connection to $ip:$port for $file: $!");
            $bot->fexit();
        }

        my $sel = IO::Select->new();
        $sel->add($sock);
        
        my $fh;
        my $buf;

        unless(open($fh, "<", $file)) {
            $bot->err("[Pepper::DCC] [$$] Error opening file for DCC connection to $ip:$port: $!");
            $bot->fexit();
        }

        seek($fh, $pos, 0) if ($pos);
        binmode($fh);

        while(read($fh, $buf, 1024)) {
            unless ($sel->can_write(0.1)) {
                $bot->err("[Pepper::DCC] [$$] Error: DCC socket not ready for writing");
                $bot->fexit();
            }

            $sock->send($buf);
            sleep(0.1);
        }

        close($fh);
        $sock->close();

        print "[Pepper::DCC] [$$] File transfer for $ip : $file completed, exiting child process..\n";
        $bot->fexit();
        return;
    } elsif ($pid > 0) {
        $self->{offers}->{"$target:$port"}->{pid} = $pid;
        
        return 1;
    } else {
        return 0;
    }
}

sub resumefile {
    my ($self, $target, $ip, $port, $file, $pos) = @_;
    my $bot = $self->{bot};
    $pos = $pos ? $pos : 0;

    return 0 if (exists($self->{ports}->{port}));

    my ($parent_read, $child_write); 
    pipe($parent_read, $child_write) or $bot->err("Error creating pipe for child process: $!");

    $self->{offers}->{"$target:$port"}->{pipe} = $parent_read;
    $self->{sel}->add($parent_read);

    $child_write->autoflush(1);

    if ($ip !~ /\:\./g) {
        $ip = nbo_to_ip($ip);
    }

    my $pid = fork();
    if ($pid == 0) {
        close($parent_read);

        print $child_write "[Pepper::DCC] [$$] Forked successfully, sending $target [$ip]: $file\n";
        my $sock;

        # create a socket to listen on $port for the client
        unless ($sock = IO::Socket::INET->new(
            LocalPort => $port,
            Proto => 'tcp',
            Listen => 1,
            Reuse => 1
        )) {
            print $child_write "[Pepper::DCC] [$$] Error opening socket for DCC connection to $ip:$port for $file: $!, exiting...\n";
            $bot->fexit();
        }

        # use IO::Select to listen on the socket
        my $sel = IO::Select->new($sock);

        # loop forever until we recieve a connection on the socket
        while (1) {
            foreach my $client ($sel->can_read(0.1)) {
                if ($client == $sock) {
                    $client = $sock->accept();
                    my $client_ip = $client->peerhost();

                    print $child_write "LOG:[Pepper::DCC] [$$] Client connected for $client_ip:$file\n";

                    if ($ip ne "0.0.0.0" && $ip != 0 && $client_ip ne $ip) {
                        print $child_write "ERROR:[Pepper::DCC] [$$] Error: DCC connection from $client_ip does not match $ip\n";
                        $bot->fexit();
                    }

                    print $child_write "IP:$client_ip\n";
                    $ip = $client_ip;
                    
                    $sel->add($client);
                } elsif ($client->eof()) {
                    $sel->remove($client);
                    $client->close();

                    print $child_write "LOG:[Pepper::DCC] [$$] Client disconnected for $ip:$file, exiting child process..\n";
                    $bot->fexit();
                }
            }

            foreach my $client ($sel->can_write(0.1)) {
                # send the file
                my $fh;
                my $buf;

                unless(open($fh, "<", $file)) {
                    print $child_write "ERROR:[Pepper::DCC] [$$] Error opening file for DCC connection to $ip:$port: $!\n";
                    $bot->fexit();
                }

                binmode($fh);
                seek($fh, $pos, 0);

                while(read($fh, $buf, 1024)) {
                    unless ($sel->can_write(0.1)) {
                        print $child_write "ERROR:[Pepper::DCC] [$$] Error: DCC socket not ready for writing\n";
                        $bot->fexit();
                    }

                    $client->send($buf);
                    sleep(0.1);
                }

                close($fh);
                $client->close();

                print $child_write "LOG:[Pepper::DCC] [$$] File transfer for $ip:$file completed, exiting child process..\n";
                print $child_write "CLOSE\n";
                $bot->fexit();
            }
        }
        
        close($child_write);
        $bot->fexit();
        return;
    } elsif ($pid > 0) {
        $self->{offers}->{"$target:$port"}->{pid} = $pid;

        close($child_write);
        return 1;
    } else {
        return 0;
    }
}

sub sendfile {
    my $self = shift;

    return $self->resumefile(@_, 0);
}

sub handle_dcc_msg {
    my ($self, $tcl, $nick, $host, $chan, $args) = @_;
    my $bot = $self->{bot};

    # >> :MSLTester!~test@eph-02t585.ephasic.org PRIVMSG ab3800 :DCC SEND lock.jpg 167772335 1024 71218 61
    if ($args =~ /SEND/i) {
        my @asp   = split(/\s/, $args); 
        shift(@asp);
        shift(@asp);
        print "here - @asp\n";

        my $ip   = $asp[1];
        my $port = $asp[2];
        $asp[4] = $asp[4] ? $asp[4] : '';

        my $fname = $asp[0];

        if ($args =~ /\"(.*?)\"/) {
            $fname = $1;
            $fname =~ s/ /\_/g;
        }

        if (exists($self->{offers}->{"$nick:$port"})) {
            my $file = $self->{offers}->{"$nick:$port"}->{file};

            print "setting ip to $ip\n";
            $self->{offers}->{"$nick:$port"}->{ip} = $ip;
            
            $bot->log("[Pepper::DCC] Sending file to $nick [".nbo_to_ip($ip).":$port]]: $file");
            $self->sendfile($nick, $ip, $port, $file);
        }
    } elsif ($args =~ /RESUME/i) {
        my @asp   = split(/\s/, $args); 
        shift(@asp);
        shift(@asp);

        my $fname    = $asp[0];
        my $startpos = $asp[2];
        my $port     = $asp[1];


        if (exists($self->{offers}->{"$nick:$port"})) {
            my $file = $self->{offers}->{"$nick:$port"}->{file};
            my $ip   = $self->{offers}->{"$nick:$port"}->{ip};

            $bot->log("[Pepper::DCC] Resuming file transfer to $nick [".nbo_to_ip($ip).":$port]: $file");
            $self->sendfile($nick, $ip, $port, $file, $startpos);

            $bot->say($nick, "\001DCC ACCEPT $fname $port $startpos\001");
        }
    } elsif ($args =~ /CHAT/i) {
        my @asp   = split(/\s/, $args);
        shift(@asp);
        shift(@asp);

        my $chatname = $asp[0];
        my $ip       = $asp[1];
        my $port     = $asp[2];

        return $bot->notice($nick, "DCC CHAT is not supported yet.");
    }
}

sub tick {
    my ($self) = @_;

    foreach my $pipe ($self->{sel}->can_read(0.1)) {
        my $line = <$pipe>;
        
        if ($line) {
            chomp($line);
            
            if ($line =~ /^LOG:(.*)/) {
                $self->{bot}->log("$1");
            } elsif ($line =~ /^ERROR:(.*)/) {
                $self->{bot}->log("$1");
                $self->{sel}->remove($pipe);
                close($pipe);
            } elsif ($line =~ /^IP:(.*)/) {
                $self->{ip} = $1;
            } elsif ($line =~ /^CLOSE$/) {
                $self->{sel}->remove($pipe);
                close($pipe);

                foreach my $k (keys(%{$self->{offers}})) {
                    if ($self->{offers}->{$k}->{pipe} == $pipe) {
                        my $port = (split(/\:/, $k))[1];

                        delete($self->{ports}->{$port});
                        delete($self->{offers}->{$k});
                    }
                }
            }
        }
    }
}

1;
