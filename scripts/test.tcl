bind pub - !hello testhello
bind join - *!*@* greetuser
bind part - *!*@* goodbyeuser
bind nick - *!*@* nickchange

proc testhello {nick uhost hand chan args} {
  putquick "PRIVMSG $chan :Hello, $nick from TCL: $args"
}

proc greetuser {nick uhost hand chan} {
  putlog "greeter called"
  putquick "PRIVMSG $chan :Welcome to $chan, $nick"
}

proc goodbyeuser {nick uhost hand chan msg} {
  putlog "goodbye called"
  putquick "PRIVMSG $chan :Goodbye, $nick"
}

proc nickchange {nick uhost hand chan newnick} {
  putlog "nickchange called: $nick -> $newnick in $chan"
}


bind mode - * modechange
proc modechange {nick uhost hand chan mode args} {
  putlog "modechange called: $nick set mode $mode $args in $chan"
}

bind ctcp - * ctcpcb
proc ctcpcb {nick uhost hand dest keyword msg} {
    putlog "ctcp called: $nick sent $keyword $msg to $dest"
}
