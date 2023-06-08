bind pub - !uptime uptime_command

proc uptime_command {nick uhost handle chan arg} {
    set uptime [exec uptime]
    putquick "PRIVMSG $chan :Uptime: $uptime"
}
