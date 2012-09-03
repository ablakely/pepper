# shadowTCL/Server.pm - shadowTCL's server module
#
# Anything inside the shadowTCL or it's subclasses is exported directly
# to TCL.  TCL may call any of the functions defined in this class.
# Please note that when TCL calls a sub the first three arguments it sends
# are undef, $int, and $name
#
# Written by Aaron Blakely
# http://ephasic.org/shadow/wiki/index.php/Pepper
#

package shadowTCL::Server;
my $bot = Shadow::Core;

# putserv <text> [options]
# Description: sends text to the server, like '.dump' (intended for direct server commands);
#              output is queued so that the bot won't flood itself off the server.
# Options:
#    -next: push message to the front of the queue
#    -normal: no effect
# Returns: nothing
sub putserv {
	my (undef, $int, $name, $text, $options) = @_;
	if ($options eq "-next") {
		$bot->raw(1, $text);
	} else {
		$bot->raw(3, $text);
	}

	return;
}

sub puthelp { putserv(@_) };    # shadow does not implement the queue this
sub putquick { putserv(@_) };   # is intended for, so just use the main queue.

# queuesize
# Returns: the number of messages in the queue.
sub queuesize {
	my (undef, $int, $name) = @_;
	return length scalar @Shadow::Core::queue;
}

# clearqueue
# Description: removes all messages from the queue.
# Returns: the number of deleted lines from the queue
sub clearqueue {
	my $queuesize = queuesize;
	for (my $i = 0; $i < $queuesize; $i++) {
		delete $Shadow::Core::queue[$i];
	}

	return $i;
}

1;
