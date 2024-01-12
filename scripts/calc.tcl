# created by fedex

bind pub - !calc safe_calc
bind pub - .calc safe_calc
setudef flag calc

proc is_op {str} {
	return [expr [lsearch {{ } . + - * / ( ) %} $str] != -1]
}

proc safe_calc {nick uhost hand chan str} {
    set enabled [channel get $chan calc]
    putlog "CALC: $nick!$uhost $chan $str ($enabled)"

	if {![channel get $chan calc]} {
        putserv "PRIVMSG $chan :$nick: The calc command is disabled in this channel."
        return
    }

	foreach char [split $str {}] {
		if {![is_op $char] && ![string is integer $char]} {
			putserv "PRIVMSG $chan :$nick: Invalid expression for calc."
			return
		}
	}

	# make all values floating point
	set str [regsub -all -- {((?:\d+)?\.?\d+)} $str {[expr {\1*1.0}]}]
	set str [subst $str]

	if {[catch {expr $str} out]} {
		putserv "PRIVMSG $chan :$nick: Invalid equation."
		return
	} else {
		putserv "PRIVMSG $chan :$str = $out"
	}
}
