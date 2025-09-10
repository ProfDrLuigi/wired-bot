#!/bin/bash
#
#

############ Fit this lines to your needs ###########
MAINPATH="/opt/wired-bot"
CLONED_REPO="/home/pi/Dokumente/GitHub/wired-cli"
HOSTNAME="localhost"
PORT="4871"
SOCKET="$MAINPATH/wired-bot.sock"
SCRIPT="$MAINPATH/wired-bot.sh"
LOGIN="guest"
PASSWORD=""
NICK="WireBot"
STATUS="Type #help in chat"
ICON="$MAINPATH/robo.png"
WATCH_DIR=""  # Must be an absolute Hostsystem Path
#####################################################

PIDFILE="$MAINPATH/wired-bot.pid"
BASHFILE="$MAINPATH/wired-bot.sh"

WIREDBOT=$( SELF=$(dirname "$0") && bash -c "cd \"$SELF\" && pwd" )

cd "$MAINPATH"

# Begin script
PROG=$(basename $0)
CMD=$1

checkpid() {
	RUNNING=0

	if [ -f $PIDFILE ]; then
		PID=`cat $PIDFILE`

		if [ "x$PID" != "x" ]; then
			if kill -0 $PID 2>/dev/null ; then
				RUNNING=1
			fi
		fi
	fi
}

checkrunning() {
	checkpid

	if [ $RUNNING -eq 0 ]; then
		echo "$PROG: $CMD: wired-bot is not running"
		#exit 1
	fi
}

case $CMD in
	start)
		checkpid

		if [ $RUNNING -eq 1 ]; then
			echo "$PROG: $CMD: wired-bot (pid $PID) already running"
			exit 1
		fi

		if screen -Sdm wired-bot ; then
			if [ ! -d venv ]; then
				ln -s "$CLONED_REPO"/venv venv
			fi
			source venv/bin/activate
			if python wired_bot.py -D --host "$HOSTNAME" --icon "$ICON" --port "$PORT" --user "$LOGIN" --password "$PASSWORD" --nick "$NICK" --status "$STATUS" --socket "$SOCKET" --script "$SCRIPT" --watch-dir "$WATCH_DIR"; then
				echo "Wirebot started"
			fi
			deactivate
			ps ax | grep -v grep | grep -v sleep | grep "wired_bot.py -D" | xargs| sed 's/\ .*//g' > wired-bot.pid
			screen -S wired-bot -p 0 -X title "wired-bot"
			#/bin/bash "$MAINPATH/wired-bot.sh" watcher_init
			/bin/bash "$MAINPATH/wired-bot.sh" rssfeed_init
			check_gpt=$( cat wired-bot.sh | grep -w "gpt_autostart=*" | head -n 1 | sed 's/gpt_autostart=//g' )
			if [ "$check_gpt" = "yes" ]; then
			  /bin/bash "$MAINPATH/wired-bot.sh" tgpt_start
			fi
		else
			echo "$PROG: $CMD: wired-bot could not be started"
		fi
		;;

	stop)
		checkrunning
		if screen -XS wired-bot quit; then
			if [ -f "$MAINPATH/rss.pid" ];then
			  rm "$MAINPATH/rss.pid"
			fi
			if [ -f "$MAINPATH/wired-bot.pid" ];then
			  wb_pid=$( cat wired-bot.pid )
			  rm "$MAINPATH/wired-bot.pid"
			  kill -kill "$wb_pid"
			fi
			echo "$PROG: $CMD: wired-bot stopped"
		else
			echo "$PROG: $CMD: wired-bot could not be stopped"
		fi
		
		if screen -XS tgpt quit; then
			if [ -f "$MAINPATH/tgpt.pid" ];then
				rm "$MAINPATH/tgpt.pid"
			fi	
			echo "$PROG: $CMD: tgpt stopped"
		else
			echo "$PROG: $CMD: tgpt could not be stopped"
		fi
		
		if [ -f "$MAINPATH/wired-bot.pid" ];then
			kill -KILL $(cat wired-bot.pid)
		    rm "$MAINPATH/wired-bot.pid"
		fi
		
		
		;;
	status)
		checkpid

		if [ $RUNNING -eq 1 ]; then
			echo ""
			echo "$PROG: $CMD: wired-bot is running on pid $PID"
		fi

		join_check=$( cat "$BASHFILE" | grep -v "sed" | grep "user_join=" | sed 's/.*=//g' )
		leave_check=$( cat "$BASHFILE" | grep -v "sed" | grep "user_leave=" | sed 's/.*=//g' )
		wordfilter_check=$( cat "$BASHFILE" | grep -v "sed" | grep "wordfilter=" | sed 's/.*=//g' )
		common_reply_check=$( cat "$BASHFILE" | grep -v "sed" | grep "common_reply=" | sed 's/.*=//g' )
		admin_user_check=$( cat "$BASHFILE" | grep -v "sed" | grep "admin_user=" | sed -e 's/.*=//g' -e 's/\"//g' )
		echo ""
		echo "Settings:"
		echo ""
		echo "User join    =" "$join_check"
		echo "User leave   =" "$leave_check"
		echo "Wordfilter   =" "$wordfilter_check"
		echo "Common reply =" "$common_reply_check"
		echo "Admin user   =" "$admin_user_check"
		echo ""
		;;

	screen)
		checkrunning

		if screen -rS wired-bot -p 0; then
			echo "$PROG: $CMD: Entering screen session"
		else
			echo -e "\n$PROG: $CMD: wired-bot is not running"
			#exit 1
		fi
		;;

	restart)
		checkpid

		if [ $RUNNING -eq 1 ]; then
			if screen -ls | grep "wired-bot" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit; then
				if [ -f "$MAINPATH/wired-bot.pid" ];then
				  rm "$MAINPATH/wired-bot.pid"
				fi
				echo "$PROG: $CMD: wired-bot stopped"
			else
				echo "$PROG: $CMD: wired-bot could not be stopped"
				exit 1
			fi
		fi

		checkpid

		if [ $RUNNING -eq 1 ]; then
			echo "$PROG: $CMD: wired-bot (pid $PID) already running"
			exit 1
		fi

		if screen -Sdm wired-bot $WIREDBOT/wired-bot ; then
			/bin/bash "$MAINPATH/wired-bot.sh" rssfeed_init
			/bin/bash "$MAINPATH/wired-bot.sh" tgpt_stop
			check_gpt=$( cat wired-bot.sh | grep -w "gpt_autostart=*" | head -n 1 | sed 's/gpt_autostart=//g' )
			if [ "$check_gpt" = yes ]; then
			  /bin/bash "$MAINPATH/wired-bot.sh" tgpt_start
			fi
		else
			echo "$PROG: $CMD: wired-bot could not be started"
		fi
		;;

	config)
		grep -v "^#" $CONFIGFILE | grep -v "^$" | sort
		;;
	
	join_on)
		/bin/bash "$BASHFILE" user_join_on
		;;

	join_off)
		/bin/bash "$BASHFILE" user_join_off
		;;

	leave_on)
		/bin/bash "$BASHFILE" user_leave_on
		;;

	leave_off)
		/bin/bash "$BASHFILE" user_leave_off
		;;

	wordfilter_on)
		/bin/bash "$BASHFILE" wordfilter_on
		;;

	wordfilter_off)
		/bin/bash "$BASHFILE" wordfilter_off
		;;

	common_reply_on)
		/bin/bash "$BASHFILE" common_reply_on
		;;

	common_reply_off)
		/bin/bash "$BASHFILE" common_reply_off
		;;

	rss_on)
		/bin/bash "$BASHFILE" rssfeed_start
		;;

	rss_off)
		/bin/bash "$BASHFILE" rssfeed_stop
		;;
	gpt_on)
		/bin/bash "$BASHFILE" tgpt_start
		;;
	gpt_off)
		/bin/bash "$BASHFILE" tgpt_stop
		;;
	*)
		cat <<EOF

Usage:  wired-botctl [COMMAND]

	COMMAND:
	start			Start wired-bot
	stop			Stop wired-bot
	restart			Restart wired-bot
	screen			Join screen session (To exit session press ctrl+a and than d)
	watch/nowatch		Switch filewatching on/off
	status			Show the status
	config			Show the configuration
	
	join_on			Activate greeting if user joined server
	join_off		Deactivate greeting if user joined server
	
	leave_on		Activate greeting if user leaved server
	leave_off		Deactivate greeting if user leaved server

	wordfilter_on		Activate wordfilter
	wordfilter_off		Deactivate wordfilfter
	
	common_reply_on		Activate talkativeness
	common_reply_off	Deactivate talkativeness	
	
	rss_on			Activate RSS Newsfeed
	rss_off			Deactivate RSS Newsfeed
	
	gpt_on			Activate tgpt
	gpt_off			Deactivate tgpt

By Prof. Dr. Luigi 
Original by Rafaël Warnault <dev@read-write.fr>

EOF
		;;
esac
