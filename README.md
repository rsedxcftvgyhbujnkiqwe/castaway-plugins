## Introduction
Repository for plugins used on [castaway.tf](https://castaway.tf/)

Check out the [Wiki](https://github.com/rsedxcftvgyhbujnkiqwe/castaway-plugins/wiki) for information regarding some of the plugins in this repo

The only entirely custom plugins here are ones credited only to random (chat-adverts, etc.). Everything else is a plugin made by someone else. The credits for said plugins can be found unmodified at the top of each plugin's .sp file.

This is not a comprehensive list of all plugins used on the server, however it does include all the most relevant ones to the player experience such as the map voting, team scrambling, and weapon revert plugins.

## Weapon Reverts
The Weapon Reverts plugin is the main feature of this repository.

Documentation for the plugin and how to use/compile it can be found [here](https://github.com/rsedxcftvgyhbujnkiqwe/castaway-plugins/wiki/Weapon-Reverts-(reverts.sp)) 

A list of all reverts, as well as revert variants, and their respective cvar values can be found [here](https://github.com/rsedxcftvgyhbujnkiqwe/castaway-plugins/wiki/Weapon-Revert-List)

The castaway.tf reverts changelog can be found [here](https://github.com/rsedxcftvgyhbujnkiqwe/castaway-plugins/wiki/Weapon-Reverts-Changelog)

## Additional Credits
Some or all of these plugins have been modified in some way, sometimes in major ways. I do not claim credit for these plugins and all credit goes to their original creators.

* reverts.sp - This plugin is a heavily modified version of bakugo's [weapon revert plugin](https://github.com/bakugo/sourcemod-plugins), featuring lots of new reverts and different core plugin functionality. In order to add onto it I have occasionally taken some code from NotnHeavy's gun mettle revert plugin. It has since been deleted from github, however a copy of the code can be found unmodified in the scripting/legacy directory, and the gamedata in gamedata/legacy. Members of the castaway.tf community have also made various contributions to the plugin in it's current state.
* votescramble - This is a heavily modded version of the votescramble from the [uncletopia plugin repo](https://github.com/leighmacdonald/uncletopia/blob/master/roles/sourcemod/files/addons/sourcemod/scripting/votescramble.sp), which is in turn a modded version of nanochip's [votescramble plugin](https://gitlab.com/nanochip/votescramble). Their version simply calls the game's autoscrambler, while our version reimplements the scramble logic from the ground up.
* nativevotes-* - This is sapphonie's [nativevotes-updates](https://github.com/sapphonie/sourcemod-nativevotes-updated), with some small modifications and bug fixes. Most notably, the nativevotes-mapchooser has a persistent mapcycle that remains between restarts.
