# shadowTCL/Core.pm - shadowTCL's core module
#
# Anything inside the shadowTCL or it's subclasses is exported directly
# to TCL.  TCL may call any of the functions defined in this class.
# Please note that when TCL calls a sub the first three arguments it sends
# are undef, $int, and $name
#
# Written by Aaron Blakely
# http://ephasic.org/shadow/wiki/index.php/Pepper
#
# TODO:
# Redo all commands associated with logging when shadow's log system is
# complete.

package shadowTCL::Core;
my $bot = Shadow::Core;

# putlog <text>
# Description: sends text to the bot's logfile, marked as 'misc' (o)
# Retuns: nothing
sub putlog {
	my (undef, $int, $name, $text) = @_;

	my $time = localtime;
	print $time." [MISC] ".$text."\n";

	return;
}

# putcmdlog <text>
# Description: sends text to the bot's logfile, marked as 'command' (c)
# Returns: nothing
sub putcmdlog {
	my (undef, $int, $name, $text) = @_;

	my $time = localtime;
	print $time." [COMMAND] ".$text."\n";

	return;
}

# putxferlog <text>
# Description: sends text to the bot's logfile, marked as 'file-area' (x)
# Returns: nothing
sub putxferlog {
	my (undef, $int, $name, $text) = @_;

	my $time = localtime;
	print $time." [FILE-AREA] ".$text."\n";

	return;
}

# putloglev <level(s)> <channel> <text>
# Description: sends text to the bot's logfile, tagged with all the valid levels given.
#              Use "*" to indicate all log levels.
# Returns: nothing
sub putloglev {
	my (undef, $int, $name, $levels, $channel, $text) = @_;
	if ($levels eq "*") {
		putlog($text);
		putcmdlog($text);
		putxferlog($text);
	}

	return;
}

# dumpfile <nick> <filename>
# Description: dumps file from the etc/help/text directory to a user on IRC via msg (one line per msg).
#              The user has no flags, so the flag bindings won't work within the file.
# Returns: nothing
sub dumpfile {
	my (undef, $int, $name, $nick, $filename) = @_;
	if (-e $Shadow::Core::shadow_dir."/etc/help/text/".$filename) {
		open (FH, "<", $Shadow::Core::shadow_dir."/etc/help/text".$filename);
		while (<FH>) {
			$bot->say($nick, $_);
		}
		close FH;
	}

	return;
}

# TODO: Account stuff


1;
