package Pepper::DCC;

# Pepper::DCC - Direct client-to-client protocol implementation
#
# Written by Aaron Blakely <aaron@ephasic.org>
# Copyright 2023 (C) Ephasic Software

use strict;
use warnings;
use Carp;
use IO::Socket::INET;
use Digest::SHA;
use LWP::Simple;

sub new {
    my ($class, $bot, $dcc_port, $dl_dir) = @_;
    my $self = {
        bot      => $bot,
        dl_dir   => $dl_dir,
        dcc_port => $dcc_port,
        offers   => {},
        files    => {}
    };

    # create dl_dir if it doesn't exists
    if (!-e $dl_dir) {
        system $^O =~ /msys|MSWin32/ ? "mkdir $dl_dir" : "mkdir -p $dl_dir";
    }

    return bless($self, $class);
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
    return undef;
}

sub offerfile {
    my ($self, $target, $file) = @_;
    my $bot = $self->{bot};
    return 0 unless (-e $file);

    # << PRIVMSG MSLTester :DCC SEND lock.jpg 199 0 71218
    my $fsize = (stat $file)[7];
    
    my $fname = (split(/\//, $file))[-1];
    $fname =~ s/ /\_/g;
    my $key = int(rand(3500));

    $self->{offers}->{"$target:$fname"} = {
        size => $fsize,
        file => $file,
        key  => $key
    };
    
    $bot->say($target, "\001DCC SEND $fname 199 0 $fsize $key\001");
    $bot->say($target, "SHA-256 checksum for $fname (remote): ".file_sha256($file)); 

    return 1;
}

sub sendfile {
    my ($self, $ip, $port, $file) = @_;
    if ($ip !~ /\:\./g) {
        $ip = nbo_to_ip($ip);
    }

    my $pid = fork();
    if ($pid == 0) {
        my $sock = IO::Socket::INET->new(
            PeerAddr => $ip,
            PeerPort => $port,
            Proto => 'tcp'
        ) or confess "Error opening DCC connection to $ip:$port for $file: $!";


        open(my $fh, "<", $file) or confess "Error opening file for DCC connection to $ip:$port: $!";
        my $buf;
        binmode($fh);

        while(read($fh, $buf, 4096)) {
            $sock->send($buf);
        }

        close($fh);
        $sock->close();
        exit;
    } elsif ($pid) {
        return 1;
    } else {
        return 0;
    }
}

sub recvfile {

}

sub handle_dcc_msg {
    my ($self, $tcl, $nick, $host, $cmd, $args) = @_;
    my $bot = $self->{bot};

    # >> :MSLTester!~test@eph-02t585.ephasic.org PRIVMSG ab3800 :DCC SEND lock.jpg 167772335 1024 71218 61
    if ($cmd =~ /SEND/i) {
        print "here\n";
        my @asp   = split(/\s/, $args); 
        $asp[4] = $asp[4] ? $asp[4] : '';

        my $fname = $asp[0];

        if ($args =~ /\"(.*?)\"/) {
            $fname = $1;
            $fname =~ s/ /\_/g;
        }

        if (exists($self->{offers}->{"$nick:$fname"}) &&
            $self->{offers}->{"$nick:$fname"}->{key} eq $asp[4]
        ) {
            my $file = $self->{offers}->{"$nick:$fname"}->{file};

            $bot->log("[Pepper::DCC] Sending file to $nick [$asp[1]:$asp[2]: $file");
            $self->sendfile($asp[1], $asp[2], $file);
        }
    }
}

1;
