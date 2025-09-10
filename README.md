# wired-bot

This is a Wired 2.0 Python Bot based on docmeth02's wired-cli project.

To install the Bot follow these steps:

	git clone https://github.com/ProfDrLuigi/wired-bot
 	git clone https://git.docmeth02.host/wired/wired-cli

	cd wired-cli
 	
  	python3 -m venv venv
  	source venv/bin/activate  # on macOS/Linux
	# .\venv\Scripts\activate  # on Windows PowerShell
	python -m pip install --upgrade pip
 	pip3 install https://git.docmeth02.host/wired/wired-python/-/archive/master/wired-python-master.zip
  	pip install -e .
	
If you want the Watch-Dir function of the Bot you must install this Dependency too:
	
 	pip3 install watchdog

If you are done change into the wired-bot dir and fit wired-bot.sh and wired-botctl.sh to your needs.

At the end you can start the bot with:

    ./wired-botctl start

<details>
<summary>
<h2>
GPT
</h2>
</summary>
	
### If you want to use GPT feature (including image generation) you need this (GPT feature is based on 'tgpt'): ###

	Install latest "Golang" (go) for your system
 	https://go.dev/dl
Compile my modified version of the original tgpt version (https://github.com/aandrew-me/tgpt)
 	
  	git clone https://github.com/ProfDrLuigi/wired-tgpt
 	cd wired-tgpt
  	bash build.sh  	
Rename your desired binary in the build folder to 

	wired-tgpt

and copy it to your wired-bot folder.

If you want to start tgpt in background you must set this in wired-bot.sh

	gpt_autostart=yes

in wired-bot.sh

</details>

<details>
<summary>
<h2>
RSS Feed (MacRumors / Tarnkappe)
</h2>
</summary>

### If you want to use RSS Feed:

If you need this feature you can enable it by typing

	./wired-bot.sh rss_on

</details>

<details>
<summary>
<h2>
Filewatcher
</h2>
</summary>

To change the Path of the folder which should be watched change the corresponding option in wired-botctl.sh

</details>

<details>
<summary>
<h2>
General use
</h2>
</summary>

To use it in chat simply start every chat line with # e.g.

	# How are you today?
	
and wait for the reply. You can speak in every language with him.

If you want to create an Image do this e.g.

	#p Show me a picture of a cat.

If you want to extent the wirebot with functions you can edit wirebot.sh in your .wirebot Directory.

To see all possible options of the bot type

	#help

in main chat window.

</details>


#### Control wirebot:

	Usage:  wirebotctl [COMMAND]

	COMMAND:
	start			Start wirebot
	stop			Stop wirebot
	restart			Restart wirebot
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
	
	rssfeed_on		Activate RSS Newsfeed
	rssfeed_off		Deactivate RSS Newsfeed

 	gpt_on			Activate tgpt
	gpt_off			Deactivate tgpt

By Prof. Dr. Luigi

