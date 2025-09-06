#!/bin/bash
##

####################################################
#### Switch desired function on or off (0 or 1).####
####################################################
user_join=0
user_leave=0
wordfilter=1
common_reply=1
####################################################

####################################################
######### Watch a directory for new files ##########
####################################################
watcher=1
watchdir="/ABSOLUTE/SYSTEM/PATH/TO/FOLDER"
####################################################

####################################################
#################### GPT Stuff #####################
####################################################
gpt_autostart=yes
gemini_key="FREE_GEMINI_API_KEY"
####################################################

####################################################
################# Image Uplaod #####################
####################################################
imgbb_key="FREE_IMGBB_API_KEY"
####################################################

####################################################
################# RSS Feed On/Off ##################
####################################################
rssfeed=1
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

nick=$(echo "$1" | awk -F' \\|\\|\\| ' '{print $1}')
login=$(echo "$1" | awk -F' \\|\\|\\| ' '{print $2}')
command=$(echo "$1" | awk -F' \\|\\|\\| ' '{print $3}')

function print_msg {
  echo "$say" | socat - UNIX-CONNECT:wirebot.sock 
}

function decline_chat {
  screen -S wirebot -p wirebot -X stuff "/close"^M
}

function rnd_answer {
  size=${#answ[@]}
  index=$(($RANDOM % $size))
  say=$( echo ${answ[$index]} )
  print_msg
}

function kill_screen {
  if [ -f watcher.pid ]; then
    rm watcher.pid
  fi
  if [ -f wirebot.stop ]; then
    rm wirebot.stop
  fi
  if [ -f wirebot.pid ]; then
    rm wirebot.pid
  fi
  if [ -f rss.pid ]; then
    rm rss.pid
  fi
  screen -ls | grep "wirebot" | cut -d. -f1 | awk '{print $1}' | xargs -I {} screen -S {} -X quit
  pkill -f wirebot
}

function watcher_def {
  inotifywait -m -e create,moved_to "$watchdir" | while read DIRECTORY EVENT FILE; do
    say=$( echo "$FILE" |sed -e 's/.*CREATE\ //g' -e 's/.*MOVED_TO\ //g' -e 's/.*ISDIR\ //g' )
    #say=$( echo ":floppy_disk: New Stuff has arrived: $say" )
    mkdir "$watchdir/$say/.goto"
    say=$( echo "<div>💾 New Stuff has arrived: <a href=\"wiredp7:///00 Upload Folders/Mac/$say/.goto/\">$say</a></div>" )
    print_msg
  done
}

function watcher_start {
  check=$( ps ax | grep -v grep | grep "inotifywait" | grep "$watchdir" )
  if [ "$check" = "" ]; then
    if ! [ -d "$watchdir" ]; then
      echo -e "The watch path \"$watchdir\" is not valid/available.\nPlease change it in wirebot.sh first and try again (./wirebotctl watch)."
      exit
    fi
    if screen -S wirebot -x -X screen -t watcher bash -c "bash "$SELF"/wirebot.sh watcher_def; exec bash"; then
      sleep 1
      ps ax | grep -v grep | grep "inotifywait*.* $watchdir" | xargs| sed 's/\ .*//g' > watcher.pid
      echo "Watcher started"
    else
      echo "Error on starting watcher. Make sure to run wirebot first! (./wirebotctl start)"
    fi
  fi
}

function watcher_stop {
  if ! [ -f watcher.pid ]; then
    echo "Watcher is not running!"
  else
    screen -S wirebot -p "watcher" -X kill
    rm watcher.pid
    echo "Watcher stopped"
  fi
}

function watcher_init {
  if [ "$watcher" = 1 ]; then
    if [ -d "$watchdir" ]; then
      watcher_start
    else
      echo -e "The watch path \"$watch=dir\" is not valid/available.\nPlease change it in wirebot.sh first and try again (./wirebotctl watch)."
    fi
  fi
}

function rssfeed_def {
  ./rss.sh
}

function rssfeed_start {
  check=$( ps ax | grep -v grep | grep "./rss.sh" )
  if [ "$check" = "" ]; then
    screen -S wirebot -x -X screen -t rss bash -c "bash "$SELF"/wirebot.sh rssfeed_def; exec bash" &
    sleep 2
    ps ax | grep -v grep | grep -v sleep | grep "rssfeed_def; exec bash" | xargs| sed 's/\ .*//g' > rss.pid
    echo "RSS feed started"
  else
    echo "RSS feed is already running!"
    exit
  fi
}

function rssfeed_stop {
  if ! [ -f rss.pid ]; then
    echo "RSS feed is not running!"
  else
    screen -S wirebot -p "rss" -X kill
    rm rss.pid
    echo "RSS feed stopped"
  fi
}

function rssfeed_init {
  if [ "$rssfeed" = 1 ]; then
    rssfeed_start
  fi
}

function tgpt_start {
  screen -dmS tgpt /opt/wired-cli/tgpt -i -q --provider gemini --key "$gemini_key" -log /tmp/tgpt.log
  ps ax | grep -v grep | grep "tgpt -i -q --provider" | xargs| sed 's/\ .*//g' > tgpt.pid
  echo "tgpt started"
}

function tgpt_stop {
  screen -S tgpt -p 0 -X kill
  rm gpt.busy
  echo "tgpt stopped"
}

function user_join_on {
  sed -i '0,/.*user_join=.*/ s/.*user_join=.*/user_join=1/g' wirebot.sh
}

function user_join_off {
  sed -i '0,/.*user_join=.*/ s/.*user_join=.*/user_join=0/g' wirebot.sh
}

function user_leave_on {
  sed -i '0,/.*user_leave=.*/ s/.*user_leave=.*/user_leave=1/g' wirebot.sh
}

function user_leave_off {
  sed -i '0,/.*user_leave=.*/ s/.*user_leave=.*/user_leave=0/g' wirebot.sh
}

function wordfilter_on {
  sed -i '0,/.*wordfilter=.*/ s/.*wordfilter=.*/wordfilter=1/g' wirebot.sh
}

function wordfilter_off {
  sed -i '0,/.*wordfilter=.*/ s/.*wordfilter=.*/wordfilter=0/g' wirebot.sh
}

function common_reply_on {
  sed -i '0,/.*common_reply=.*/ s/.*common_reply=.*/common_reply=1/g' wirebot.sh
}

function common_reply_off {
  sed -i '0,/.*common_reply=.*/ s/.*common_reply=.*/common_reply=0/g' wirebot.sh
}

function rssfeed_on {
  sed -i '0,/.*rssfeed=.*/ s/.*rssfeed=.*/rssfeed=1/g' wirebot.sh
}

function rssfeed_off {
  sed -i '0,/.*rssfeed=.*/ s/.*rssfeed=.*/rssfeed=0/g' wirebot.sh
}

function imgbb_upload {
	
	IMAGE_B64=$(base64 -w 0 "picture.jpg")
	
	RESPONSE=$(curl -s -X POST \
	  -F "key=$imgbb_key" \
	  -F "image=$IMAGE_B64" \
	  https://api.imgbb.com/1/upload)
	
	URL=$(echo "$RESPONSE" | grep -oP '"url":"\K[^"]+')
	
	if [[ -n "$URL" ]]; then
		imgbb_url=$( echo "$URL" | head -n 1 | sed 's/\\//g' )
	fi

}

function tgpt {

if [[ "$command" = "#"* ]]; then
	if [[ "$command" = "#help" ]]; then
	  say="<n><b><u>Available Commands</b></u></br></br> \
	  <u>Talk with Bot</u><span style=\"font-family:Courier\"><br># \"YOUR TEXT\"</span></br><br> \
	  <u>Generate an image</u><span style=\"font-family:Courier\"><br>#p \"PICTURE DESCRIPTION\"</span></br><br> \
	  <u>Reset conversation</u><span style=\"font-family:Courier\"><br>#reset conversation</span></br><br> \
	  <u>Memes</u><span style=\"font-family:Courier\"><br>:hi: | :wow:</span></n>"
	  print_msg
	  echo "$command" > /tmp/yo
	  exit
	
	elif [[ "$command" = "#p"* ]]; then
	  conversation=$(echo "$command" | sed -e 's/b:\ //g' -e 's/B:\ //g' -e 's/.*#p//g' )	  
	  if ! ./tgpt --provider pollinations --model flux --img --out picture.jpg --height 320 --width 320 "$conversation"; then
    	say="Error creating Image. Trying another Provider (arta)... ⏱️"
    	print_msg
    	arta_url=$(echo "n" | ./tgpt --provider arta --img "$conversation" | grep -Eo 'https?://[^ ]+')
    	say=$( echo "Image is too big. Here the direct link: " "$arta_url" )
    	print_msg
    	rm 01991*.jpg
    	exit
	  fi

	  imgbb_upload

	  say=$( echo "<img src=\"$imgbb_url\"></img>" )
	  rm picture.jpg > /dev/null
	  print_msg
	  exit
	
	elif [[ "$command" = "#"* ]]; then
	  # Nun exklusiver Zugriff garantiert
	  conversation=$(echo "$command" | sed 's/.*#//g')
		
	  screen -S tgpt -p 0 -X stuff "$conversation"
	  sleep 0.5
	  screen -S tgpt -p 0 -X stuff $'\n'
	  exit
	fi
fi 	

}

function phrases {

#### User join server (user_join) ####
if [ $user_join = 1 ]; then
  if [[ "$command" == *" has joined" ]]; then
    nick=$( cat wirebot.cmd | sed -e 's/.*\]\ //g' -e 's/\ has\ joined//g' -e 's/;0m//g' | xargs )
    say=$( /opt/wired-cli/tgpt -q --provider gemini --key "$gemini_key" "Begrüße den User $nick auf Englisch. Denke dir was aus und frage nicht nach. Einen Einzeiler. Aber abwechslungsreich und vermeide zu oft Greetings am Anfang. Der Name des zu Grüßenden soll auch nicht immer am Anfang des Satzes stehen. Es soll immer nur eine Begrüßung erfolgen, nie mehrere!")
    #say="Hi $nick 😁"
    print_msg
  fi
fi

#### User leave server (user_leave) ####
if [ $user_leave = 1 ]; then
  if [[ "$command" == *" has left" ]]; then
    nick=$( cat wirebot.cmd | sed -e 's/.*\]\ //g' -e 's/\ has\ left//g' -e 's/;0m//g' | xargs )
    say="Bye $nick 😔"
    print_msg
  fi
fi

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
  if [[ "$admin_user" == *"$login"* ]]; then
    allowed=1
  else
    allowed=0
    say="🚫 You are not allowed to do this $nick 🚫"
    print_msg
    exit
  fi
fi

if [ "$allowed" = 1 ]; then
  if [ "$command" = "!" ]; then
    say="⛔ This command is not valid. ⛔"
    print_msg
  fi
  if [ "$command" = "!sleep" ]; then
    answ[0]="💤"
    answ[1]=":sleeping: … Time for a nap."
    rnd_answer
    say="/afk"
    print_msg
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
    say="/afk"
    print_msg
    touch wirebot.stop
  fi
  if [ "$command" = "!gpt start" ]; then
    if screen -ls | grep "tgpt"; then
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
    rm gpt.busy
    tgpt_stop
    tgpt_start
  fi 
  if [ "$command" = "!userjoin on" ]; then
    user_join_on
  fi
  if [ "$command" = "!userjoin off" ]; then
    user_join_off
  fi  
  if [ "$command" = "!userleave on" ]; then
    user_leave_on
  fi
  if [ "$command" = "!userleave off" ]; then
    user_leave_off
  fi 
  fi
    if [ "$command" = "!kill_screen" ]; then
    say="Cya."
    kill_screen
  fi

  if [ -f wirebot.stop ]; then
    if [ "$command" = "!start" ]; then
          rm wirebot.stop
    elif [ "$command" = "!stop" ]; then
      say="/afk"
      print_msg
      exit
    else
      exit
    fi
  elif [ ! -f wirebot.stop ]; then
    if [ "$command" = "!start" ]; then
          exit
    fi
  fi

  if [[ "$command" == *"Using timestamp"* ]]; then
    if [ -f wirebot.stop ]; then
      rm wirebot.stop
  fi
 
fi

}

tgpt

phrases

memes

admin

$1
