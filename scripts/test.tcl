bind pub - !hello testhello

proc testhello {nick uhost hand chan args} {
  putquick "PRIVMSG $chan :Hello, $nick from TCL: $args"
}
