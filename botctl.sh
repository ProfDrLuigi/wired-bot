#!/bin/bash
#
#

############ Fit this lines to your needs ###########
MAINPATH="/opt/wired-bot"
CLONED_CLI_REPO="/home/pi/Dokumente/GitHub/wired-cli"
HOSTNAME="localhost"
PORT="4871"
LOGIN="guest"
PASSWORD=""
NICK="WireBot"
STATUS="Type #help in chat"
ICON="$MAINPATH/robo.png"
WATCH_DIR="/ABSOLUTE/SYSTEM/PATH"
#####################################################

cd "$MAINPATH"

# Begin script
PROG=$(basename $0)
CMD=$1

checkpid() {
	RUNNING=0

	if [ -f wired-bot.pid ]; then
		PID=`cat wired-bot.pid`

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
		exit 1
	fi
}

case $CMD in
	start)
		checkpid

		if [ $RUNNING -eq 1 ]; then
			echo "$PROG: $CMD: wired-bot (pid $PID) already running"
			exit 1
		fi

		if [ ! -d venv ]; then
			ln -s "$CLONED_CLI_REPO"/venv venv
		fi
		
		source venv/bin/activate
		if python wired_bot.py -D --socket "$MAINPATH/wired-bot.sock" --host "$HOSTNAME" --icon "$ICON" --port "$PORT" --user "$LOGIN" --password "$PASSWORD" --nick "$NICK" --status "$STATUS" --script "$MAINPATH"/wired-bot.sh --watch-dir "$WATCH_DIR"; then
			echo "wired-bot started"
		else
			echo "wired-bot could not be started"
		fi
		deactivate
		
		ps ax | grep -v grep | grep "wired_bot.py -D" | xargs| sed 's/\ .*//g' > wired-bot.pid
		check_gpt=$( cat "wired-bot.sh" | grep -w "gpt_autostart=*" | head -n 1 | sed 's/gpt_autostart=//g' )
		if [ "$check_gpt" = 1 ]; then
		  /bin/bash "wired-bot.sh" tgpt_start
		fi
		
		check_rssfeed=$( cat "wired-bot.sh" | grep -w "rssfeed_autostart=*" | head -n 1 | sed 's/rssfeed_autostart=//g' )
		if [ "$check_rssfeed" = 1 ]; then
		  /bin/bash "wired-bot.sh" rssfeed_start
		fi

		;;

	stop)
		checkrunning
		
		if [ -f wired-bot.pid ]; then
		  wb_pid=$( cat wired-bot.pid )
		  kill -kill "$wb_pid"
		  rm wired-bot.pid
		  echo "wired-bot stopped"
		fi
		
		if [ -f rss.pid ]; then
		  rss_pid=$( cat rss.pid )
    	  kill -kill "$rss_pid"
    	  rm rss.pid
		  echo "RSS feed stopped"
    	fi
    	
    	if [ -f wired-tgpt.pid ]; then
		  tgpt_pid=$( cat wired-tgpt.pid )
    	  screen -XS wired-tgpt quit
    	  rm wired-tgpt.pid
		  echo "wired-tgpt stopped"
    	fi

		;;

	status)
		checkpid

		if [ $RUNNING -eq 1 ]; then
			echo ""
			echo "$PROG: $CMD: wired-bot is running on pid $PID"
		fi

		join_check=$( cat "wired-bot.sh" | grep -v "sed" | grep "user_join=" | sed 's/.*=//g' )
		leave_check=$( cat "wired-bot.sh" | grep -v "sed" | grep "user_leave=" | sed 's/.*=//g' )
		wordfilter_check=$( cat "wired-bot.sh" | grep -v "sed" | grep "wordfilter=" | sed 's/.*=//g' )
		common_reply_check=$( cat "wired-bot.sh" | grep -v "sed" | grep "common_reply=" | sed 's/.*=//g' )
		rssfeed_check=$( cat "wired-bot.sh" | grep -v "sed" | grep "rssfeed=" | sed 's/.*=//g' )
		gpt_check=$( cat "wired-bot.sh" | grep -v "sed" | grep "gpt=" | sed 's/.*=//g' )
		admin_user_check=$( cat "wired-bot.sh" | grep -v "sed" | grep "admin_user=" | sed -e 's/.*=//g' -e 's/\"//g' )
		echo ""
		echo "Settings:"
		echo ""
		echo "User join    =" "$join_check"
		echo "User leave   =" "$leave_check"
		echo "Wordfilter   =" "$wordfilter_check"
		echo "Common reply =" "$common_reply_check"
		echo "RSS feed     =" "$rssfeed_check"		
		echo "GPT          =" "$gpt_check"		
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

	config)
		grep -v "^#" $CONFIGFILE | grep -v "^$" | sort
		;;
	
	join_on)
		/bin/bash "wired-bot.sh" user_join_on
		;;

	join_off)
		/bin/bash "wired-bot.sh" user_join_off
		;;

	leave_on)
		/bin/bash "wired-bot.sh" user_leave_on
		;;

	leave_off)
		/bin/bash "wired-bot.sh" user_leave_off
		;;

	wordfilter_on)
		/bin/bash "wired-bot.sh" wordfilter_on
		;;

	wordfilter_off)
		/bin/bash "wired-bot.sh" wordfilter_off
		;;

	common_reply_on)
		/bin/bash "wired-bot.sh" common_reply_on
		;;

	common_reply_off)
		/bin/bash "wired-bot.sh" common_reply_off
		;;

	rss_on)
		/bin/bash "wired-bot.sh" rssfeed_start
		;;

	rss_off)
		/bin/bash "wired-bot.sh" rssfeed_stop
		;;
	gpt_on)
		/bin/bash "wired-bot.sh" tgpt_start
		;;
	gpt_off)
		/bin/bash "wired-bot.sh" tgpt_stop
		;;
	*)
		cat <<EOF

Usage:  wired-botctl [COMMAND]

	COMMAND:
	start			Start wired-bot
	stop			Stop wired-bot
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
