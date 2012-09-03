# shadowTCL/IRC.pm - shadowTCL's irc module
#
# Anything inside the shadowTCL or it's subclasses is exported directly
# to TCL.  TCL may call any of the functions defined in this class.
# Please note that when TCL calls a sub the first three arguments it sends
# are undef, $int, and $name
#
# Written by Aaron Blakely
# http://ephasic.org/shadow/wiki/index.php/Pepper
#

package shadowTCL::IRC;
my $bot = Shadow::Core;

# putkick <channel> <nick,nick,...> [reason]
# Description: sends kick to the server and tries to put as many nicks into one kick command as possible.
# Returns: nothing
sub putkick {
	my (undef, $int, $name, $channel, $nicks, $reason) = @_;
	$reason = "" if !$reason;

	$bot->kick($channel, $nicks, $reason);
	return;
}

1;

