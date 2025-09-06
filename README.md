# wired-cli-bot

Clone my repository first and than this:

https://git.docmeth02.host/wired/wired-cli

Have a look at Point 1. und 2. and execute them.

Than change the first line of wirebotctl with "MAINPATH" to your needs. In my case I cloned the wired-cli-bot repo to:

    /opt/wired-cli

After that set a symlink for examples/console_chat.py in the wired-cli-bot directory. See my example Picture.

<img width="1237" height="295" alt="Bildschirmfoto 2025-09-06 um 14 59 52" src="https://github.com/user-attachments/assets/2fc30317-7732-43f0-ad5e-7984b355ca10" />

You have to set the hostname, user, password etc. in the top of wirebotctl too. If you are done you can start the bot with:

    ./wirebotctl start

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
 	
  	git clone https://github.com/ProfDrLuigi/tgpt
 	cd tgpt
  	bash build.sh  	
Copy your desired binary in the build folder to

	/opt/wired-cli/tgpt
If you want to start tgpt in background with wirebotctl you must set this:

	gpt_autostart=yes
in wirebot.sh

### --- General use --- ##
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

#### 2. Control wirebot:

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

