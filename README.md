# Pepper

Pepper is an [eggdrop](https://eggheads.org) compatible TCL runtime for [Shadow](https://github.com/ablakely/shadow) IRC bot.

# Install

Place this project in your modules directory for shadow and copy or create a link from

    modules/Pepper/ShadowPepper.pm to modules/ShadowPepper.pm

Then edit your config file or message shadow on IRC:

    /msg Shadow loadmod ShadowPepper

# Usage

### Loading a Tcl script

Place the script in `modules/Pepper/scripts` and message Shadow

    /msg Shadow pepper load <script.tcl>



