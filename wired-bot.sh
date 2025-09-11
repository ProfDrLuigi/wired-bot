#!/bin/bash
##

####################################################
#### Switch desired function on or off (0 or 1).####
####################################################
user_join=1
user_leave=0
wordfilter=1
common_reply=1
####################################################

####################################################
#################### GPT Stuff #####################
####################################################
gpt_autostart=yes
gpt=0
gemini_key="YOUR_FREE_GEMINI_API_KEY"
####################################################

####################################################
################# Image Uplaod #####################
####################################################
imgbb_key="YOUR_FREE_IMGBB_KEY"
####################################################

####################################################
################# RSS Feed On/Off ##################
####################################################
rssfeed_autostart=yes
rssfeed=0
interval=5m
####################################################
macrumors=1
tarnkappe=1
####################################################

####################################################
### Let these users (login-name) control the bot ###
####################################################
admin_user="admin,luigi"
####################################################

SELF=$(SELF=$(dirname "$0") && bash -c "cd \"$SELF\" && pwd")
cd "$SELF"

function print_msg {
  echo "$say" | socat - UNIX-CONNECT:wired-bot.sock
  echo "/idle" | socat - UNIX-CONNECT:wired-bot.sock
}

function rnd_answer {
  size=${#answ[@]}
  index=$(($RANDOM % $size))
  say=$( echo ${answ[$index]} )
  print_msg
}

function join_left {

#### User join server (user_join) ####
if [ "${user_join:-0}" -eq 1 ]; then
  if [ "$command" = "joined" ]; then
    sleep 2
    answ[0]="Hi $nick 😁"
    answ[1]="Yo $nick ... whazzup?"
    rnd_answer
    exit
  fi
fi

#### User leave server (user_leave) ####
if [ "${user_leave:-0}" -eq 1 ]; then
  if [ "$command" = "left" ]; then
  	sleep 1
    answ[0]="Bye $nick ☹️"
    answ[1]="Bye $nick ☹️"
    rnd_answer
    exit
  fi
fi

}

prefix_check=$(echo "$1" | awk '{print $1}')

if [[ "$prefix_check" == "joined" ]]; then
  command="joined"
  nick=$(echo "$1" | awk -F' \\|\\|\\| ' '{print $2}')
  join_left
elif [[ "$prefix_check" == "left" ]]; then
  command="left"
  nick=$(echo "$1" | awk -F' \\|\\|\\| ' '{print $2}')
  join_left
else
  nick=$(echo "$1" | awk -F' \\|\\|\\| ' '{print $1}')
  login=$(echo "$1" | awk -F' \\|\\|\\| ' '{print $2}')
  command=$(echo "$1" | awk -F' \\|\\|\\| ' '{print $3}')
fi

function rssfeed_def {
  ./rss.sh
}

function rssfeed_start {
  if [ ! -f rss.pid ]; then
  	rssfeed_enabled=$( cat "wired-bot.sh" | grep -v "sed" | grep "rssfeed=" | sed 's/.*=//g' )
  	if [ "$rssfeed_enabled" = 1 ]; then
      nohup ./rss.sh >/dev/null 2>&1 &
      echo $! > rss.pid
      echo "RSS feed started"
    fi
  else
    echo "RSS feed is already running!"
    exit
  fi
}

function rssfeed_stop {
  if ! [ -f rss.pid ]; then
    echo "RSS feed is not running!"
  else
    rss_pid=$( cat rss.pid )
    kill -kill "$rss_pid"
    echo "RSS feed stopped"
    rm rss.pid
  fi
}

function tgpt_start {
  if [ ! -f wired-tgpt.pid ]; then
    tgpt_enabled=$( cat "wired-bot.sh" | grep -v "sed" | grep "gpt=" | sed 's/.*=//g' )
    if [ "$tgpt_enabled" = 1 ]; then
      screen -dmS wired-tgpt ./wired-tgpt -i -q --provider gemini --key "$gemini_key" -log /tmp/wired-tgpt.log
      ps ax | grep -v grep | grep "tgpt -i -q --provider" | xargs| sed 's/\ .*//g' > wired-tgpt.pid
      echo "wired-tgpt started"
    fi
  else
    echo "wired-tgpt is already running!"
  fi
}

function tgpt_stop {
  if [ -f wired-tgpt.pid ]; then
    screen -S wired-tgpt -p 0 -X kill
    rm wired-tgpt.pid
  	echo "wired-tgpt stopped"
  else
    echo "wired-tgpt is not running!"
  fi
}

function user_join_on {
  sed -i '0,/.*user_join=.*/ s/.*user_join=.*/user_join=1/g' wired-bot.sh
}

function user_join_off {
  sed -i '0,/.*user_join=.*/ s/.*user_join=.*/user_join=0/g' wired-bot.sh
}

function user_leave_on {
  sed -i '0,/.*user_leave=.*/ s/.*user_leave=.*/user_leave=1/g' wired-bot.sh
}

function user_leave_off {
  sed -i '0,/.*user_leave=.*/ s/.*user_leave=.*/user_leave=0/g' wired-bot.sh
}

function wordfilter_on {
  sed -i '0,/.*wordfilter=.*/ s/.*wordfilter=.*/wordfilter=1/g' wired-bot.sh
}

function wordfilter_off {
  sed -i '0,/.*wordfilter=.*/ s/.*wordfilter=.*/wordfilter=0/g' wired-bot.sh
}

function common_reply_on {
  sed -i '0,/.*common_reply=.*/ s/.*common_reply=.*/common_reply=1/g' wired-bot.sh
}

function common_reply_off {
  sed -i '0,/.*common_reply=.*/ s/.*common_reply=.*/common_reply=0/g' wired-bot.sh
}

function rssfeed_on {
  sed -i '0,/.*rssfeed=.*/ s/.*rssfeed=.*/rssfeed=1/g' wired-bot.sh
}

function rssfeed_off {
  sed -i '0,/.*rssfeed=.*/ s/.*rssfeed=.*/rssfeed=0/g' wired-bot.sh
}

function tgpt {

if [[ "$command" = "#"* ]]; then
	if [[ "$command" = "#help" ]]; then
	  say="<div><b><u>Available Commands</b></u></br></br> \
	  <u>Talk with Bot</u><span style=\"font-family:Courier\"><br># \"YOUR TEXT\"</span></br><br> \
	  <u>Generate an image</u><span style=\"font-family:Courier\"><br>#p \"PICTURE DESCRIPTION\"</span></br><br> \
	  <u>Reset conversation</u><span style=\"font-family:Courier\"><br>#reset conversation</span></br><br> \
	  <u>Chuck Norris fact</u><span style=\"font-family:Courier\"><br>!roundhouseme</span></br><br> \
	  <u>Memes</u><span style=\"font-family:Courier\"><br>:hi: | :wow:</span></div>"
	  print_msg
	  exit
	
	elif [[ "$command" = "#p"* ]]; then
	  conversation=$(echo "$command" | sed -e 's/b:\ //g' -e 's/B:\ //g' -e 's/.*#p//g' )	  
	  if ! ./tgpt --provider pollinations --model flux --img --out picture.jpg --height 320 --width 320 "$conversation"; then
    	say="Error creating Image. Trying another Provider (arta)... ⏱️"
    	print_msg
    	echo "y" | ./tgpt --provider arta --img "$conversation"
    	mv 0199* picture.jpg
    	imgbb_url=$( curl -s -X POST -F "key=$imgbb_key" -F "image=@picture.jpg" https://api.imgbb.com/1/upload | grep -oP '"url":"\K[^"]+' | tail -n2 | head -n1 | sed 's/\\//g' )
    	say=$( echo "<img src=\"$imgbb_url\"></img>" )
	    rm picture.jpg > /dev/null
	    print_msg
    	exit
	  fi

	  imgbb_url=$( curl -s -X POST -F "key=$imgbb_key" -F "image=@picture.jpg" https://api.imgbb.com/1/upload | grep -oP '"url":"\K[^"]+' | head -n1 | sed 's/\\//g' )

	  say=$( echo "<img src=\"$imgbb_url\"></img>" )
	  rm picture.jpg > /dev/null
	  print_msg
	  exit
	
	elif [[ "$command" = "#"* ]]; then
	  # Nun exklusiver Zugriff garantiert
	  conversation=$(echo "$command" | sed 's/.*#//g')
		
	  screen -S wired-tgpt -p 0 -X stuff "$conversation"
	  sleep 0.5
	  screen -S wired-tgpt -p 0 -X stuff $'\n'
	  exit
	fi
fi 	

}

function phrases {

#### wordfilter (wordfilter)####
if [[ "$command" == *"Hey, why did you"* ]]; then
  exit
fi

if [ $wordfilter = 1 ]; then
  if [ "$command" = "shit" ] || [[ "$command" = *"fuck"* ]] || [ "$command" = "asshole" ] || [ "$command" = "ass" ] || [ "$command" = "dick" ]; then
    answ[0]="$nick, don't be rude please... 👎"
    answ[1]="Very impolite! 😠"
    answ[2]="Hey, why did you say \"$command\" ? 😧 😔"
    rnd_answer
    exit
  fi
fi

#### Common (common_reply) ####
if [ $common_reply = 1 ]; then
  if [[ "$command" = "wired" ]]; then
    answ[0]="Uh? What's "Wired" $nick? ‍😖"
    answ[1]="Ooooh, Wired! The magazine ? 😟"
    rnd_answer
  fi
  if [[ "$command" = "shut up bot" ]] ; then
    answ[0]="Moooooo 😟"
    answ[1]="Oh no 😟"
    answ[2]="Nooooo 😥"
    rnd_answer
    exit
  fi
  if [[ "$command" = "bot" ]]; then
    answ[0]="Do you talked to me $nick?"
    answ[1]="Bot? What's a bot?"
    answ[2]="Bots are silly programs. 🙈"
    answ[3]="…"
    answ[4]="hides!"
    answ[5]="runs!"
    rnd_answer
  fi
  if [ "$command" = "hello" ] || [ "$command" = "hey" ] || [ "$command" = "hi" ]; then
    answ[0]="Hey $nick. 😁"
    answ[1]="Hello $nick. 👋"
    answ[2]="Hi $nick. 😃"
    answ[3]="Yo $nick. 😊"
    answ[4]="Yo man ... whazzup? ✌️"
    rnd_answer
  fi
fi

}

function norris_facts {
  if [ "$command" = "!roundhouseme" ]; then
 	say=$( curl -s https://api.chucknorris.io/jokes/random | sed 's/^[[:space:]]*"[^"]*":[[:space:]]*//' | sed -e 's/.*":"//g' -e 's/"}//g' -e 's/\\//g' )
 	print_msg
 	exit
  fi
}

function memes {

  if [ "$command" = ":hi:" ]; then
 	say=$( echo "<img src=\"https://media.tenor.com/2jxPfgoknigAAAAM/hi-ladies-smile.gif\"></img>" )
 	print_msg
 	exit
  fi
  
  if [ "$command" = ":wow:" ]; then
 	say=$( echo "<img src=\"https://media1.tenor.com/m/dROzBp2e6cgAAAAC/wow-david-hasselhoff.gif\"></img>" )
 	print_msg
 	exit
  fi

}

function admin {
################ Admin Section ################

# Check if user has admin rights
if [[ "$command" = \!* ]]; then  
  if [[ "$admin_user" != *"$login"* ]]; then
    say="🚫 You are not allowed to do this $nick 🚫"
    print_msg
    exit
  fi
fi

if [ "$command" = "!" ]; then
  say="⛔ This command is not valid ⛔"
  print_msg
fi
if [ "$command" = "!sleep" ]; then
  answ[0]="💤"
  answ[1]=":sleeping: … Time for a nap."
  rnd_answer
fi
if [ "$command" = "!start" ]; then
  answ[0]="Yes, my lord."
  answ[1]="I need more blood.👺"
  answ[2]="Ready to serve.👽"
  rnd_answer
fi
if [ "$command" = "!stop" ]; then
  answ[0]="Ping me when you need me. 🙂"
  answ[1]="I jump ❗"
  rnd_answer
  touch wired-bot.stop
fi
if [ "$command" = "!gpt start" ]; then
  if screen -ls | grep "wired-tgpt"; then
    say="tgpt already running"
    print_msg
    exit 0
  fi
  answ[0]="Ping me when you need me. 🙂"
  answ[1]="I jump ❗"
  rnd_answer
  tgpt_start
fi 
if [ "$command" = "!gpt stop" ]; then
  answ[0]="Ping me when you need me. 🙂"
  answ[1]="I jump ❗"
  rnd_answer
  tgpt_stop
fi 
if [ "$command" = "!gpt restart" ]; then
  answ[0]="Yes sir. 🙂"
  answ[1]="I will do that ❗"
  rnd_answer
  tgpt_stop
  tgpt_start
fi

if [ "$command" = "!userjoin on" ]; then
  user_join_on
  say="Yes sir. 🙂"
  print_msg
fi
if [ "$command" = "!userjoin off" ]; then
  user_join_off
say="Yes sir. 🙂"
  print_msg
fi  
if [ "$command" = "!userleave on" ]; then
  user_leave_on
  say="Yes sir. 🙂"
  print_msg
fi
if [ "$command" = "!userleave off" ]; then
  user_leave_off
  say="Yes sir. 🙂"
  print_msg
fi 

}

tgpt

phrases

memes

admin

$1
