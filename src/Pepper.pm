package Pepper;

my $bot = Shadow::Core;

# Pepper is a module for shadow which allows shadow to load
# Eggdrop TCL scripts and bind them to shadow events.
#

use strict;
use warnings;
use TCL;
use shadowTCL;

my @loaded_scripts;
my $tclinterp = TCL->new;
$tclinterp->export_to_tcl(
	namespace	=> '',
	subs_from	=> 'shadowTCL',
	vars_from	=> 'shadowTCL'
);

sub load_tcl_script {
	my ($script) = @_;
	$tclinterp->EvalFile($script);
	push(@loaded_scripts, $script);
}

sub unload_tcl_script {
	my ($script) = @_;

	# The only way I can think of doing this is to recreate the TCL interpteter instance.
	$tclinterp = Tcl->new;
	$tclinterp->export_to_tcl(
  	      namespace       => '',
  	      subs_from       => 'shadowTCL',
  	      vars_from       => 'shadowTCL'
	);

	my @tmp;
	foreach my $tclscript (@loaded_scripts) {
		if ($tclscript ne $script) {
			$tclinterp->EvalFile($script);
			push(@tmp, $tclscript);
		}
	}

	@loaded_scripts = @tmp;
}

1;
