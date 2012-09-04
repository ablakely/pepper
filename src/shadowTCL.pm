# shadowTCL.pm - Bundles all the shadowTCL modules into one 'use'
#
# Anything inside the shadowTCL class is exported to TCL.  From which
# TCL can access and use.
#
# Written by Aaron Blakely

package shadowTCL;
my $bot = Shadow::Core;
use shadowTCL::Core;
use shadowTCL::IRC;
use shadowTCL::Server;

# Here's where we can define custom API extensions for Shadow
sub shadowver {
	return $Shadow::Core::options->{config}->{version};
}

1;
