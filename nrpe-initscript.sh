#!/bin/bash
#@(#)Build EIS Configuration Management

prefix=/opt/op5

nrpe_initscript () {
  typeset DISTVER=$1
  if [ "${DISTVER#debian}" != "$DISTVER" ] ; then
cat << EODEBIAN
#!/bin/bash
#
# nrpe  Start / stop nagios remote plugin execution
#
# chkconfig: 2345 95 05
# description: Start / stop nrpe (daemon mode)
# probe: true
# nrpe - Start / Stop script for nrpe
#
# Author: Andreas Ericsson
#
# Copyright (C) 2003 OP5 AB
# All rights reserved.
#
# Changelog:
# 2003-11-27 - Creation date
# 2007-09-23 - Removed the call for /etc/rc.d/init.d/functions
### BEGIN INIT INFO
# Provides:        nrpe
# Required-Start:  \$network \$syslog
# Required-Stop:   \$network \$syslog
# Default-Start:   2 3 4 5
# Default-Stop:    1
# Short-Description: Start Nrpe daemon
### END INIT INFO

BINDIR=$prefix/nrpe/bin
CONFIG=$prefix/etc/nrpe.cfg
PROGRAM=nrpe

function check_status () {
        pids=\`pidof \$PROGRAM\`
        if [ \$? -ne 0 ]; then
                return 1
        fi
        return 0
}

if [ ! -s \$CONFIG ]; then
        echo "\$0: can't read config file \$config"
        exit 1
fi

if [ ! -x \$BINDIR/\$PROGRAM ]; then
        echo "\$0: \$PROGRAM is not executable"
        exit 1
fi

case "\$1" in
        status)
                check_status
                if [ \$? -eq 1 ]; then
                        echo -e "\$PROGRAM is NOT running."
                        exit 0
                fi
                pids=\`pidof \$PROGRAM\`
                echo -e "\$PROGRAM is up and running with pid: \$pids"
        ;;
        stop)
                check_status
                if [ \$? -eq 1 ]; then
                        echo -e "\$PROGRAM doesn't seem to be running."
                        exit 0
                fi
                kill -TERM \`pidof \$PROGRAM\`
                exit 0
        ;;
        start)
                check_status
                if [ \$? -eq 0 ]; then
                        pids=\`pidof \$PROGRAM\`
                        echo -e "\$PROGRAM is already running with pid: \$pids"
                        exit 0
                fi
                echo -e -n "Starting \$PROGRAM in daemon mode ... "
                \$BINDIR/\$PROGRAM -c \$CONFIG -d
                check_status
                if [ \$? -eq 1 ]; then
                        echo "failed!"
                else
                        echo "done"
                fi
                exit 0
        ;;
        restart)
                \$0 stop
                \$0 start
        ;;
        force-reload)
                \$0 stop
                \$0 start
        ;;
        *)
                echo -e "Usage: nrpe {start|stop|status|restart|reload|force-reload}"
                exit 0
        ;;
esac
EODEBIAN
  elif [ "${DISTVER#suse}" != "$DISTVER" ] ; then
cat << EOSUSE
#!/bin/bash
#
# Copyright (c) 2010 SUSE Linux Products GmbH
# Authors: Lars Vogdt (2010)
#
# /etc/init.d/nrpe
#   and its symbolic link
# /usr/sbin/rcnrpe
#
### BEGIN INIT INFO
# Provides:          nagios-nrpe
# Required-Start:    \$remote_fs \$syslog \$network vasypd
# Should-Start:      cron
# Required-Stop:     \$remote_fs \$syslog vasypd
# Should-Stop:       cron
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: NRPE Nagios Remote Plugin Executor
# Description:       Start NRPE to allow remote execution of
#	Nagios plugins.
### END INIT INFO

NRPE_BIN="$prefix/nrpe/bin/nrpe"
test -x \$NRPE_BIN || { echo "\$NRPE_BIN not installed";
    if [ "\$1" = "stop" ]; then exit 0;
	else exit 5; fi; }

# Check for existence of needed config file and read it
NRPE_CONFIG="$prefix/etc/nrpe.cfg"
test -r \$NRPE_CONFIG || { echo "\$NRPE_CONFIG not existing";
    if [ "\$1" = "stop" ]; then exit 0;
	else exit 6; fi; }

DEFAULT_PIDFILE="/var/run/op5/nrpe.pid"

function get_value() {
    if [ -n "\$2" ]; then
        set -- \`grep ^\$1 \$2 | sed 's@=@ @' | tr -d '[:cntrl:]'\`
    else
        set -- \`grep ^\$1 \$NRPE_CONFIG | sed 's@=@ @' | tr -d '[:cntrl:]'\`
    fi
    shift # remove first ARG => search-string
    echo \$*
}

# Shell functions sourced from /etc/rc.status:
. /etc/rc.status

# Reset status of this service
rc_reset

case "\$1" in
    start)
    echo -n "Starting Nagios NRPE "
    pid_file="\$(get_value pid_file)"
    nrpe_group="\$(get_value nrpe_group)"
    nrpe_user="\$(get_value nrpe_user)"
    : \${pid_file=:=\$DEFAULT_PIDFILE}
    : \${nrpe_group:=nagios}
    : \${nrpe_user:=nagios}
    if [ -z "\$pid_file" ]; then
        PIDDIR=\$(dirname \$pid_file)
    else
        PIDDIR=\$(dirname \$DEFAULT_PIDFILE)
    fi
    case "\$PIDDIR" in 
        /var/run)
            if [ x"\$nrpe_user" != x"root" ]; then
                DATESTRING=\`date +"%Y%m%d"\`
                mv -f "\$NRPE_CONFIG"  "\$NRPE_CONFIG-\$DATESTRING"
                sed -e "s|^pid_file.*|pid_file=\$DEFAULT_PIDFILE|g" "\$NRPE_CONFIG-\$DATESTRING" > "\$NRPE_CONFIG" 
                /bin/logger -t rcnrpe "Configured \$pid_file in \$NRPE_CONFIG moved to \$DEFAULT_PIDFILE. Backup is \$NRPE_CONFIG-\$DATESTRING"
                test -f "\$pid_file" && rm "\$pid_file"
                install -d -m755 -o\$nrpe_user -g\$nrpe_group \$(dirname "\$DEFAULT_PIDFILE")
            else
                test -d "\$PIDDIR" || mkdir -p "\$PIDDIR"
            fi
        ;;
        *)
            test -d \$(dirname "\$DEFAULT_PIDFILE") || install -d -m755 -o\$nrpe_user -g\$nrpe_group \$(dirname "\$DEFAULT_PIDFILE")
        ;;
    esac
	/sbin/startproc -n -10 \$NRPE_BIN -c \$NRPE_CONFIG -d
	
	# Remember status and be verbose
	rc_status -v
	;;
    stop)
	# Stop daemons.
	echo -n "Shutting down Nagios NRPE "
	/sbin/killproc -TERM \$NRPE_BIN

	# Remember status and be verbose
	rc_status -v
	;;
    try-restart|condrestart)
        if test "\$1" = "condrestart"; then
	        echo "\${attn} Use try-restart \${done}(LSB)\${attn} rather than condrestart \${warn}(RH)\${norm}"
	fi
	\$0 status
	if test \$? = 0; then
	        \$0 restart
	else
		rc_reset	# Not running is not a failure.
	fi

	# Remember status and be quiet
	rc_status
        ;;
    restart)
	## Stop the service and regardless of whether it was
	## running or not, start it again.
	\$0 stop
	\$0 start

	# Remember status and be quiet
	rc_status
	;;
    reload|force-reload)
	echo -n "Reload service Nagios NRPE "
	/sbin/killproc -HUP \$NRPE_BIN

	# Remember status and be verbose
	rc_status -v
        ;;
    status)
  	echo -n "Checking for service Nagios NRPE "
	## Check status with checkproc(8), if process is running
	## checkproc will return with exit status 0.

	# Status has a slightly different for the status command:
	# 0 - service running
	# 1 - service dead, but /var/run/  pid  file exists
	# 2 - service dead, but /var/lock/ lock file exists
	# 3 - service not running
	/sbin/checkproc \$NRPE_BIN

	# Remember status and be verbose
	rc_status -v
	;;
    *)
	echo "Usage: \$0 {start|stop|status|try-restart|restart|force-reload|reload}"
	exit 1
esac
rc_exit
EOSUSE
  elif [ "${DISTVER#rhel}" != "$DISTVER" ] ; then
cat << EORHEL
#!/bin/sh
#
#  Created 2000-01-03 by jaclu@grm.se
#
# nrpe          This shell script takes care of starting and stopping
#               nrpe.
#
# chkconfig: 2345 80 30
# description: nrpe is a daemon for a remote nagios server, \\
#              running nagios plugins on this host.
# processname: nrpe
# config: $prefix/etc/nrpe.conf


# Source function library
if [ -f /etc/rc.d/init.d/functions ]; then
. /etc/rc.d/init.d/functions
elif [ -f /etc/init.d/functions ]; then
. /etc/init.d/functions
elif [ -f /etc/rc.d/functions ]; then
. /etc/rc.d/functions
fi

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ \${NETWORKING} = "no" ] && exit 0

NrpeBin=$prefix/nrpe/bin/nrpe
NrpeCfg=$prefix/etc/nrpe.cfg
LockFile=/var/lock/subsys/nrpe

# See how we were called.
case "\$1" in
  start)
	# Start daemons.
	echo -n "Starting nrpe: "
	daemon \$NrpeBin -c \$NrpeCfg -d
	echo
	touch \$LockFile
	;;
  stop)
	# Stop daemons.
	echo -n "Shutting down nrpe: "
	killproc nrpe
	echo
	rm -f \$LockFile
	;;
  restart)
	\$0 stop
	\$0 start
	;;
  status)
	status nrpe
	;;
  *)
	echo "Usage: nrpe {start|stop|restart|status}"
	exit 1
esac

exit 0
EORHEL
  elif [ "${DISTVER#solaris}" != "$DISTVER" ] ; then
cat << EOSOLARIS
#!/bin/sh
#
# NRPE (Nagios) client start script
#

USER=`/usr/bin/grep "^nrpe_user" $prefix/etc/nrpe.cfg | /usr/bin/cut -f2 -d=`

USAGE="usage: \$0 [start|stop|restart]"
if [ \$# -ne 1 ]; then
  echo \$USAGE
  exit 1
fi

CHECK_PROC_CMD="/usr/bin/pgrep -x -u \$USER nrpe"

if [ -x /usr/bin/zonename ]
then
        ZONENAME=\`/usr/bin/zonename\`
        if [ "\$ZONENAME" = "global" ]
        then
                CHECK_PROC_CMD="/usr/bin/pgrep -z global -x -u \$USER nrpe"
        fi
fi

case \$1 in
  start)
    CHECK_PROC=\`\$CHECK_PROC_CMD\`
    if [ "\$?" != 0 ]
    then
          echo "starting nrpe ..."
          /usr/bin/nice -n -10 $prefix/nrpe/bin/nrpe -c $prefix/etc/nrpe.cfg -d
    else
	  echo "Nrpe already running"
    fi
    ;;
  stop)
    CHECK_PROC=\`\$CHECK_PROC_CMD\`
    if [ ! -z "\$CHECK_PROC" ]
    then
         echo "stopping nrpe ..."
         kill \`cat /var/run/op5/nrpe.pid\`
    fi
    ;;
  restart)
    CHECK_PROC=\`\$CHECK_PROC_CMD\`
    if [ ! -z "\$CHECK_PROC" ]
    then
        echo "stopping nrpe ..."
        kill \`cat /var/run/op5/nrpe.pid\`
        sleep 1
        echo "starting nrpe ..."
        /usr/bin/nice -n -10 $prefix/nrpe/bin/nrpe -c $prefix/etc/nrpe.cfg -d
    else
        echo "Nrpe not running. Starting nrpe ..."
        /usr/bin/nice -n -10 $prefix/nrpe/bin/nrpe -c $prefix/etc/nrpe.cfg -d

    fi
    ;;
  *)
    echo \$USAGE
    ;;
esac
EOSOLARIS
  fi
}
