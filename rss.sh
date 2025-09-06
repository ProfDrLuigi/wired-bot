#!/bin/bash
#

wirebot=$( cat wirebot.sh )
macrumors=$( echo "$wirebot" | grep "macrumors=" | sed 's/macrumors=//g' )
tarnkappe=$( echo "$wirebot" | grep "tarnkappe=" | sed 's/tarnkappe=//g' ) 
interval=$( echo "$wirebot" | grep "interval=" | sed 's/interval=//g' )

function macrumors_rss {
  macrumors_feed=$( curl --silent "https://feeds.macrumors.com/MacRumors-All" | \
  grep -E '(title>|description>)' | \
  tail -n +4 | \
  sed -e 's/^[ \t]*//' | \
  sed -e 's/<title>//' -e 's/<\/title>//' -e 's/<description>/  /' -e 's/<\/description>//' | head -n 1 | sed -e 's/.*CDATA\[//g' -e 's/<br\/>//g' | tr -dc '[[:print:]]\n' )
  macrumors_say=$( echo -e "<n><b><u>+++ Macrumors Breaking News +++</u></b><br>""$macrumors_feed""</n>" )
}

function tarnkappe_rss {
  mapfile -t lines < <(python tarnkappe.py)
  title="${lines[0]}"
  url="${lines[1]}"
  descr="${lines[2]}"
  url_title="${lines[3]}"
  url_title=$( echo "$url_title" | sed -e 's/.*.html" rel="nofollow">//g' -e 's/<\/a>.*//g' )
  tarnkappe_say=$( echo -e "<n><b><u>+++ Tarnkappe Breaking News +++</b></u><br><b>""$title""</b><br>""$descr ""<a rel=nofollow href=""$url"">Zum Artikel</a>""</n>" | sed ':a;N;$!ba;s/\n//g' | sed -e 's/<p>//g' -e 's/<\/p>//g' )
}

if [ "$macrumors" = "1" ]; then
  macrumors_rss
fi
if [ "$tarnkappe" = "1" ]; then
  tarnkappe_rss
fi

while true
do
  if [ "$macrumors" = "1" ]; then
    macrumors_now=$( curl "https://feeds.macrumors.com/MacRumors-All" 2> /dev/null | grep pubDate | head -1 )
  fi
  if [ "$tarnkappe" = "1" ]; then
    tarnkappe_rss
    tarnkappe_now=$( echo "$title" )
  fi

  if [ -f rss.brain ]; then
    macrumors_check=$( cat rss.brain | grep -v grep | grep "$macrumors_now" )
    tarnkappe_check=$( cat rss.brain | grep -v grep | grep "$tarnkappe_now" )
  fi

  if  [ "$macrumors_check" = "" ]; then
    if [ "$macrumors" = "1" ]; then
      macrumors_rss
      echo "$macrumors_say" | socat - UNIX-CONNECT:/opt/wired-cli/wired.sock 
      echo "$macrumors_now" >> rss.brain
    fi
  fi

  if  [ "$tarnkappe_check" = "" ]; then
    if [ "$tarnkappe" = "1" ]; then
      tarnkappe_rss
      echo "$tarnkappe_say" | socat - UNIX-CONNECT:/opt/wired-cli/wirebot.sock 
      echo "$tarnkappe_now" >> rss.brain
    fi
  fi

  sleep "$interval"
done
