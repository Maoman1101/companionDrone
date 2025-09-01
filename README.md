The most up-to-date description can always be found here: https://mods.factorio.com/mod/companion-drones-mjlfix

#Companion Drones in 2.0 and Space Age for YOU.

*Overview:* 
This mod gives you a "Companion Drone" (and eventually multiple) to assist the player through all stages of Factorio gameplay. No mere roboport, this drone is a persistent, modular flying vehicle with advanced AI logic. It follows the player and assists in anything construction robots can do, manages its own inventory and refueling, and can (optionally) engage in combat.

Features:

- *Context-aware Automation:* This drone monitors the player's surroundings and behavior, dynamically assigning itself construction, repair, deconstruction, or combat jobs within range. It will automatically fetch materials and repair packs from the player (or their vehicle) as needed, then beam back leftover items when finished.

- *Inventory and Fuel Management:* The drone manages its own inventory and refuels itself automatically from available sources. NOTE: You *cannot* use the companion as a portable chest, as it will occasionally try to shove its items back into your inventory. Its internal inventory is intended for the materials it carries for construction jobs.

- *Resilient to Edge Cases:* The companion is designed to gracefully handle force/surface changes, disconnects, and other Factorio oddities. It can teleport to the player if stranded, and will never become permanently lost. If you can't find your drone... a biter probably ate it.

- *Customizable Behavior:* 
  * Players can toggle construction or combat on or off either with the on-screen shortcut buttons, or with keyboard shortcuts (unbound by default). 
  * Turn the companion's chatter on or off, or change how frequently it speaks while idle. 
  * Improve mod performance by increasing the update interval
  * Whether the drone uses the best or the worst fuel first
  * And finally, you can toggle between Modes...

#Introducing Challenge Mode:

With version 3.0.0 comes a brand new re-imagining of the original mod with real progression from early, through mid, and into end game. This takes the easy-to-craft and replaceable drone you had before and turns it into one extremely valuable companion you protect with your life. You get one drone to start with, and that's ALL you get *until you can make processing units to craft more drones*, so take good care of your one drone to start!

Damaged in the crash that stranded you on this god-forsaken planet, the drone is weak and inefficient to start out with, and its laser bank was destroyed, so it can't defend itself at first. However, when you research certain key technologies, *you will partially "repair" the bot*, improving its functions. 

Its max speed, build range, damage output, range it seeks jobs, and even how many companions you can have summoned at once, they all start out at low values and *slowly improve as you progress through the game.*

By the time you reach space science, your bot will actually be ***significantly stronger*** than it is with challenge mode disabled--an encouragement to try it out! (New save strongly recommended, both for technical and gameplay reasons). Also recommended to have companion dialogue turned ON so you can tell when stats get upgraded.

#Introducing Forgiving Mode too:

In version 3.1.0 we introduced "Forgiving Mode" in addition to Challenge mode, which gives you significantly easier recipes, intended for large complex modpacks such as Angels or Bob's.

You select each mode in the startup settings. There are four options:

*0* Gives you *Normal* mode, with a basic companion and normal recipes
*1* Gives you *Challenge* mode, with a companion that improves over time and normal recipes
*2* Gives you *Forgiving* mode, with a basic companion and more lenient recipes
*3* Gives you *Combined* mode, with a companion that improves over time and more lenient recipes - basically 1 and 2 combined.

This information can be found in the setting description in-game as well

#Known Issues:
- *MULTIPLAYER WARNING:* So long as only one player uses any bots, multiplayer is fine, but as soon as two or more have it, then you start getting weird behaviors shared between companions of different players. (This is on the to-do list to fix, but will require a pretty hefty refactor as I shift some globals into player-indexed variables.)
- *Quality Control:* Quality of a companion will be reset back to normal if you try to place it and you already have the max number of companions placed, along with some other subtle issues to do with quality. Recommended to stick with normal quality companions for now.
- ~~*Frozen Bot:* Very rarely, the bot will "lock up" and it'll refuse to fight or do any work, even if you pick it up and replace it, reload, anything. In that case, open your console and type `/reset_companions` (don't worry, it won't disable achievements--*though it WILL clear the companion's inventory*).~~ probably *FIXED* 
- ~~*Twitchy Movement:* Especially with better stats, the companion may jump around somewhat wildly at times. This is a side effect of making it do large construction jobs much more efficiently, which I could not figure out how to avoid despite copious testing.~~ probably *FIXED*
- ~~*Bungee Cord Construction:* Sometimes when the companion is searching for jobs that are just out of range, it will bounce a huge distance well past the job and then back to the player, maybe even a couple of times. This is usually harmless and resolves quickly, but if it loops repeatedly, try moving your player character, or pick up and replace the companion. `/reset_companions` will work, but it will probably be carrying items in its inventory for its job, and they will be deleted, so that's a last resort.~~ should be *FIXED*
- ~~*Custom vehicle repairs:* When driving a custom vehicle, attempting to pull a repair pack from the player inside the vehicle *causes a crash.* Temporary solution: toggle off construction mode while driving a custom vehicle and don't turn it back on until you exit the vehicle.~~ *FIXED*
- ~~*Invisible Deconstruction:* You may notice that when the companion is deconstructing and has a high level roboport with many robots, that some of the robots will be "invisible" and will not have the red laser beam connecting it. This is purely cosmetic, but it still bothers me, so I'll probably fix it eventually.~~ *FIXED*
- ~~*OP Construction Bots:* The companion creates (and destroys) its own super-powerful construction bots, which are normally impossible to acquire. However, under very specific circumstances, you can sometimes wind up with a small number of its OP construction bots in your greater roboport system, where they will happily continue being OP now in your favor (until you try to pick them up). I suppose it's up to you whether you want to exploit this to cheat.~~ *FIXED*

#Notes for other modders:
- *Remote Hooks:* Currently there is only one remote interface added by the original mod author for the Jetpack mod (which probably doesn't even work anymore). If you need one, feel free to suggest it in the discussions tab, and I'll be more than happy to take a look.
- *Custom Dialogue:* The dialogue system is almost completely modular and will happily accept new lines of dialogue or language packs. The only caveat is that the very first line, the 0th line, must contain the number of lines of that locale section as an integer and nothing else. If you want one particular line of dialogue to appear more frequently than others, simply add it more than once.
- *Compatibility:* I am a big fan of cross compatibility so if you find a conflict with your mod which cannot feasibly be fixed from your end, *please report it* and I will see about fixing it on my end instead.
- *Community:* I am also in support of a healthy and interconnected modding community, so if you build any sort of integration with this mod and yours, let me know and I'll give your mod a shoutout here in the description.
- *Contributions:* Pull requests are welcome, but will be carefully analyzed before anything is approved. To expedite the process, please include thorough documentation and explain your reasoning for the update in your PR.

#Credits
- Original mod and much of the core logic by *Klonan*
- Attempted revival by *kubiixx*
- Revived by *MrJakobLaich*
- Maintained by *Maoman* (Discord is the fastest way to reach me but I try to check this portal at least daily)
