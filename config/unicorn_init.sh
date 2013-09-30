#! /bin/sh

# File: /etc/init.d/unicorn

### BEGIN INIT INFO
# Provides:          unicorn
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts the unicorn web server
# Description:       starts unicorn
### END INIT INFO

DAEMON=/usr/bin/unicorn
DAEMON_OPTS="-c /app/kochiku/kochiku/currentconfig/unicorn.rb -D"
NAME=unicorn
DESC="Unicorn app for testapp"
PID=/app/kochiku/kochiku/shared/pid/unicorn.pid

case "$1" in
  start)
    echo -n "Starting $DESC: "
    $DAEMON $DAEMON_OPTS
    echo "$NAME."
    ;;
  stop)
    echo -n "Stopping $DESC: "
        kill -QUIT `cat $PID`
    echo "$NAME."
    ;;
  restart)
    echo -n "Restarting $DESC: "
        kill -QUIT `cat $PID`
    sleep 1
    $DAEMON $DAEMON_OPTS
    echo "$NAME."
    ;;
  reload)
        echo -n "Reloading $DESC configuration: "
        kill -HUP `cat $PID`
        echo "$NAME."
        ;;
  *)
    echo "Usage: $NAME {start|stop|restart|reload}" >&2
    exit 1
    ;;
esac

exit 0