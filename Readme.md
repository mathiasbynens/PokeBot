# PokéBot

An automated computer program that speedruns Pokémon generation 1 games.

Pokémon Red (Any% Glitchless) personal best runs:

* [1:50:14](https://www.youtube.com/watch?v=lVE_ksd4WJw) (13 April 2015)
* [1:51:11](https://www.youtube.com/watch?v=M4pOlQ-mIoc) (23 June 2014)
* [1:56:45](https://youtu.be/yh3hI2xNvh4) (7 May 2014)

## Watch live

### [twitch.tv/thepokebot](http://www.twitch.tv/thepokebot)

PokéBot’s official streaming channel on Twitch. Consider following there to find out when we’re streaming, or follow the [Twitter feed](https://twitter.com/thepokebot) for announcements when we get personal best pace runs going.

### Run the bot locally

Running the PokéBot on your own machine is easy. You will need a Windows environment (it runs great in VMs on Mac/Linux too).

1. First, clone this repository (or download and unzip it) to your computer.

2. Download the [BizHawk 1.6.1](http://sourceforge.net/projects/bizhawk/files/BizHawk/BizHawk-1.6.1.zip/download) emulator and extract the ZIP file anywhere you like to “install” it.

3. Run [the BizHawk prerequisites installer](http://sourceforge.net/projects/bizhawk/files/Prerequisites/bizhawk_prereqs_v1.1.zip/download), which should update a C++ distributable needed by BizHawk.

4. Procure a ROM file of Pokémon Red (you should personally own the game).

5. Open BizHawk.exe, then drag your ROM file onto the window, and Pokémon Red should start up.

6. By default, the bot completes every run it can, without resetting if it gets too far behind its best run time. Set [`RESET_FOR_TIME` in `main.lua`](https://github.com/kylecoburn/PokeBot/blob/v1.4.4/main.lua#L3) to `true` instead of `false` to reset more aggressively, i.e. if you’re trying to get a new record.

7. Under the _Tools_ menu, select _Lua Console_. Press the “open folder” button, and navigate to the PokéBot folder you downloaded. Select `main.lua` and press “open”. The bot should start running!

## Seeds

PokéBot comes with a built-in run recording feature that takes advantage of random number seeding to reproduce runs in their entirety. Any time the bot resets or beats the game, it will log a number to the Lua console that is the seed for the run. If you set `CUSTOM_SEED` in `main.lua` to that number, the bot will reproduce your run, allowing you to [share your times with others](Seeds.md). Note that making any other modifications will prevent this from working. So if you want to make changes to the bot and share your time, be sure to fork the repo and push your changes.

## Other Categories

The bot is designed to run "any% glitchless" (beat the game as fast as possible, without major glitches) categories - the most popular in the speedrunning community. However, the bot can easily be adapted for other purposes including use in testing frame data for human players, or to run different categories of the game.

[Red Any% No Save Corruption](https://github.com/bouletmarc/PokeBot) by [Marc-Andre Boulet](https://github.com/bouletmarc)

If you're interested in adapting the bot to other categories or games, we'd love to see it, and are happy to help answer questions.

## Credits

### Developers

Kyle Coburn: Original concept, Red/Yellow routing

Michael Jondahl: Combat algorithm, Java bridge for connecting the bot to Twitch chat, LiveSplit, Twitter, etc.

### Special thanks

To our Twitch chat moderators who help answer questions, and make the stream a great place to hang out.

To LiveSplit for providing custom component for integrating in-game time splits.

To the [contributor community](https://github.com/kylecoburn/PokeBot/graphs/contributors) here, who have helped track seeds and improve the bot.

To the Pokémon speedrunning community members who inspired the idea, and shared their knowledge on ways to improve the bot.

_Enjoy!_
