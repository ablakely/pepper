
#bind pub - !hello testhello
proc testhello {nick uhost hand chan args} {
  putquick "PRIVMSG $chan :Hello, $nick from TCL: $args"
}

#bind join - *!*@* greetuser
proc greetuser {nick uhost hand chan} {
  putlog "greeter called"
  putquick "PRIVMSG $chan :Welcome to $chan, $nick"
}

#bind part - *!*@* goodbyeuser
proc goodbyeuser {nick uhost hand chan msg} {
  putlog "goodbye called"
  putquick "PRIVMSG $chan :Goodbye, $nick"
}

#bind nick - *!*@* nickchange
proc nickchange {nick uhost hand chan newnick} {
  putlog "nickchange called: $nick -> $newnick in $chan"
}

#bind mode - * modechange
proc modechange {nick uhost hand chan mode args} {
  putlog "modechange called: $nick set mode $mode $args in $chan"
}

#bind ctcp - * ctcpcb
proc ctcpcb {nick uhost hand dest keyword msg} {
    putlog "ctcp called: $nick sent $keyword $msg to $dest"
}


#bind sign - * signoff
proc signoff {nick uhost hand chan reason} {
  putlog "signoff called: $nick!$uhost signed off: $reason"
}


#bind pubm - * pubmsg
proc pubmsg {nick uhost hand chan text} {
  putlog "pubmsg called: $nick!$uhost said $text in $chan"
}


#bind time - "* * * * *" timecheck
proc timecheck {min hour day month year} {
    putlog "timecheck called: $hour:$min $day/$month/$year"
}

bind pub - !test test_matchaddr
proc test_matchaddr {nick uhost hand chan args} {
  # split args into mask and address
  set args [split $args]
  set mask [lindex $args 0]
  set address [lindex $args 1]

  putquick "PRIVMSG $chan :Matchaddr: [matchaddr $mask $address]"
}
