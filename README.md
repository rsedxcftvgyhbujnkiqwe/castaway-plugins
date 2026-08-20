## Introduction
Repository for plugins used on [castaway.tf](https://castaway.tf/)

Check out the [Wiki](https://github.com/rsedxcftvgyhbujnkiqwe/castaway-plugins/wiki) for information regarding some of the plugins in this repo

Not all plugins in this repository are authored by castaway developers, though some are added due to the presence of server-specific edits to the plugins. Relevant credits for individual plugins can be found in the .sp files for each plugin

This is not a comprehensive list of all plugins used on the server, however it does include all the most relevant ones to the player experience such as the map voting, team scrambling, and weapon revert plugins.

## Weapon Reverts
The Weapon Reverts plugin is the main feature of this repository.

Documentation for the plugin and how to use/compile it can be found [here](https://github.com/rsedxcftvgyhbujnkiqwe/castaway-plugins/wiki/Weapon-Reverts-(reverts.sp)) 

A list of all reverts, as well as revert variants, and their respective cvar values can be found [here](https://github.com/rsedxcftvgyhbujnkiqwe/castaway-plugins/wiki/Weapon-Revert-List)

## Additional Credits
These are plugins which were not created by contributors to this repo, but were modified in some way relevant to be noted here

* reverts.sp - This plugin is a heavily modified version of bakugo's [weapon revert plugin](https://github.com/bakugo/sourcemod-plugins), featuring lots of new reverts and different core plugin functionality. In order to add onto it we have occasionally taken some code from NotnHeavy's gun mettle revert plugin. It has since been deleted from github, however a copy of the code can be found unmodified in the scripting/legacy directory, and the gamedata in gamedata/legacy.
* votescramble - This is a heavily modded version of nanochip's [votescramble plugin](https://gitlab.com/nanochip/votescramble). Their version simply calls the game's autoscrambler, while our version reimplements the scramble logic from the ground up.
* nativevotes-* - This is sapphonie's [nativevotes-updates](https://github.com/sapphonie/sourcemod-nativevotes-updated), with some small modifications and bug fixes. Most notably, the nativevotes-mapchooser has a persistent mapcycle that remains between restarts.
* old-flame-mechanics.sp - This is a heavily modified version of a now since deleted plugin by NotnHeavy which reverts flame mechanics to pre-JI
* supersprayhandler.sp - This is a modded version of [Super Spray Handler](https://github.com/JoinedSenses/SM-SuperSprayHandler) which removes all sprayban logic
* teamcatch.sp - [This plugin](https://forums.alliedmods.net/showthread.php?p=2767957), fixes an issue which causes players to get stuck in spectator
* disablesoul.sp - [This plugin](https://forums.alliedmods.net/showthread.php?t=281392) disables visual halloween soul transfer effects during the halloween event
