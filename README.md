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

### Unloading a Tcl script

    /msg Shadow pepper unload <script.tcl>

This will remove the given script and reinit the Tcl interpreter

### Listing loaded scripts

    /msg Shadow pepper list

### chanset

    /msg Shadow pepper chanset #channel +/-flag

---

This module is currently in development and a lot of the eggdrop API hasn't been implemented yet, 
but basic functionality does work at this point.

---

Written by Aaron Blakely \<aaron\@ephasic.org\>
