PokéBot
=======
An automated computer program that speedruns Pokémon.

Pokémon Red Any%: [1:51:11](https://www.youtube.com/watch?v=M4pOlQ-mIoc) (23 June 2014)

Watch Live
==========
### [http://www.twitch.tv/thepokebot](http://www.twitch.tv/thepokebot)
PokéBot's official streaming channel on Twitch. Consider following there to find out when we're streaming, or follow the [Twitter feed](https://twitter.com/thepokebot) for announcements when we get personal best pace runs going.

Try it out
==========
Running the PokéBot on your own machine is easy. You will need a Windows environment (it runs great in VM's on Mac too). First, clone this repository (or download and unzip it) to your computer. Download the [BizHawk 1.6.1](http://sourceforge.net/projects/bizhawk/files/BizHawk/BizHawk-1.6.1.zip/download) emulator, and procure a ROM file of Pokémon Red (you should personally own the game).


##About BizHawk##
BizHawk 1.6.1 (Windows only) is the only version known to work.  Later versions, like 1.7.2a do not seem to work, due to differences with reading bytes from memory.

Run the [prereq installer](http://sourceforge.net/projects/bizhawk/files/Prerequisites/bizhawk_prereqs_v1.1.zip/download), which should update a C++ distributable needed by BizHawk

You can unextract BizHawk-1.6.1.zip anywhere.

##Setting up and verifying the ROM##
The ROM file should `Pokemon Red.gb`.  The file name doesn't matter, but upload it to http://www.fileformat.info/tool/hash.htm to verify it's the US version.  The linked website will spit out lots of hashes, make sure the two below match:
```
MD5: 3d45c1ee9abd5738df46d2bdda8b57dc
SHA-1: ea9bcae617fdf159b045185467ae58b2e4a48b9a
```

Open the ROM file with BizHawk (Drag the .gb file onto EmuHawk), and Pokémon Red should start up.
The colors may look weird.  To fix this, go to GB>Palette Editor, and then find the POKEMON RED.pal file which should be under Gameboy>Palettes in the directory where BizHawk was unextracted.


##Running the bot##
If you want to test the full run, change [this line](https://github.com/kylecoburn/PokeBot/blob/52232581f227b829ea283d795ddaf60a52ce24fe/main.lua#L4) to be false.
Then, under the 'Tools' menu, select 'Lua Console'.
Click the open folder button, and navigate to the PokéBot folder you downloaded. Select 'main.lua' and press open. The bot should start running!

Seeds
=====
PokéBot comes with a built-in run recording feature that takes advantage of random number seeding to reproduce runs in their entirety. Any time the bot resets or beats the game, it will log a number to the Lua console that is the seed for the run. If you set `CUSTOM_SEED` in `main.lua` to that number, the bot will reproduce your run, allowing you to [share your times with others](Seeds.md). Note that making any other modifications will prevent this from working. So if you want to make changes to the bot and share your time, be sure to fork the repo and push your changes.

Credits
=======
### Developers
Kyle Coburn: Original concept, Red routing

Michael Jondahl: Combat algorithm, Java bridge for connecting the bot to Twitch chat, Livesplit, Twitter, etc

### Special thanks
To Livesplit for providing custom component for integrating in-game time splits.

To the Pokémon speedrunning community members who inspired the idea, and shared ways to improve the bot.
