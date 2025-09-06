# wired-cli-bot

Clone this repository:

https://git.docmeth02.host/wired/wired-cli

Have a look at Point 1. und 2. and execute them.

Than change the first line of wirebotctl with "MAINPATH" to your needs. In my case I cloned the wired-cli-bot repo to:

  /opt/wired-cli

After that set a symlink for examples/console_chat.py in the wired-cli-bot directory. See my example Picture.

<img width="1237" height="295" alt="Bildschirmfoto 2025-09-06 um 14 59 52" src="https://github.com/user-attachments/assets/2fc30317-7732-43f0-ad5e-7984b355ca10" />

You have to set the hostname, user, password etc. in the top of wirebotctl too. If you are done you can start the bot with:

  ./wirebotctl start
