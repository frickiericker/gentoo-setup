service shell
{
        socket_type     = stream
        protocol        = tcp
        wait            = no
        user            = root
        group           = tty
        server          = /usr/sbin/in.rshd
        log_on_success  = PID HOST USERID EXIT DURATION
        log_on_failure  = USERID ATTEMPT
        disable         = no
        only_from       = 192.168.100.0/24 192.168.108.0/24
}
