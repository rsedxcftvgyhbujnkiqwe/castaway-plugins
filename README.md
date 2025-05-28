## Introduction
Repository for plugins used on [castaway.tf](https://castaway.tf/)

Check out the [weapon reverts changelog here](https://github.com/rsedxcftvgyhbujnkiqwe/castaway-plugins/blob/master/RevertsChangelog.md).

The only entirely custom plugins here are ones credited only to random (chat-adverts, etc.). Everything else is a plugin made by someone else. The credits for said plugins can be found unmodified at the top of each plugin's .sp file.

This is not a comprehensive list of all plugins used on the server, however it does include all the most relevant ones to the player experience such as the map voting, team scrambling, and weapon revert plugins. 

## Compiling

To compile the plugins, download a recent Sourcemod stable version and merge the scripting directory into the scripting directory of this repo, then use `./compile.sh <plugin_name>` to compile each plugin. 

In addition to the dependencies below, the reverts plugin has special compile instructions. Read the Memory Patches section for more information.

The reverts plugin has the following dependencies:
- 32 bit server/sourcemod - 64 bit sourcemod is not yet fully working for all plugins
- [TF2Items](https://github.com/nosoop/SMExt-TF2Items)
- [TF2Attributes](https://github.com/FlaminSarge/tf2attributes)
- [TF2Utils](https://github.com/nosoop/SM-TFUtils)
- [TF2 Condition Hooks](https://github.com/Scags/TF2-Condition-Hooks) ([modified source file](https://github.com/rsedxcftvgyhbujnkiqwe/castaway-plugins/blob/master/scripting/tf2condhooks.sp), [gamedata](https://github.com/rsedxcftvgyhbujnkiqwe/castaway-plugins/blob/master/gamedata/tf2.condmgr.txt))
- [Source Scramble](https://github.com/nosoop/SMExt-SourceScramble) - Only required if using the memory patches (see Usage for more info)

No other plugins have any external dependencies, and the include files for the above dependencies are within this repo.

## Usage

The reverts plugin, after installing all the required dependencies, should work out of the box. 

### Memory Patches

There are a few revert patches within the revert plugin by default that utilize sourcescramble. If the reverts plugin does not work correctly with the reverts that use memory patching for any reason, it is advised to not compile the plugin with them enabled. These reverts may break on game updates.

To disable reverts that come from memory patches, comment the following line near the top of the reverts.sp file before you compile:
```
#define VERDIUS_PATCHES
```
Alternatively, you can pass in `NO_MEMPATCHES=` as a parameter to spcomp.

Additionally, before you compile the reverts.sp file, check what operating system your server is using.

If your server is on Windows, you need to uncomment the WIN32 line near the top of the reverts.sp file:
```
//#define WIN32
```
Alternatively you can pass in `WIN32=` as a parameter to spcomp.exe.

If your server is on Linux, you do not need to do anything, it should work as-is.

The following weapons use memory patches for their reverts:
- All Heavy Miniguns (Minigun, Tomislav, Brass Beast, Natascha, Huo-Long Heater, etc.)
- Cozy Camper
- Dragon's Fury
- Disciplinary Action
- Quick-Fix
- Wrangler
- Rescue Ranger

### Toggling Reverts

If you want to disable a specific weapon revert, you can create a config file called `reverts.cfg` in your `tf/cfg/sourcemod` folder. To disable a specific revert, you set the following:

```
sm_reverts__item_<name> 1/0
```
The below would disable the equalizer and sandman reverts
```
sm_reverts__item_equalizer 0
sm_reverts__item_sandman 0
```

To get the name to use, open up the reverts.sp file and find the `ItemDefine` block near the top inside of OnPluginStart, and use the second value in the params.

By default, all reverts are on. 

## Additional Credits
Some or all of these plugins have been modified in some way, sometimes in major ways. I do not claim credit for these plugins and all credit goes to their original creators.

* reverts.sp - This plugin is a heavily modified version of bakugo's [weapon revert plugin](https://github.com/bakugo/sourcemod-plugins), featuring lots of new reverts and different core plugin functionality. In order to add onto it I have occasionally taken some code from NotnHeavy's gun mettle revert plugin. It has since been deleted from github, however a copy of the code can be found unmodified in the scripting/legacy directory, and the gamedata in gamedata/legacy. Members of the castaway.tf community have also made various contributions to the plugin in it's current state.
* votescramble - This is a heavily modded version of the votescramble from the [uncletopia plugin repo](https://github.com/leighmacdonald/uncletopia). Their version simply calls the game's autoscrambler, while my version reimplements the scramble logic from the ground up.
* nativevotes-* - This is sapphonie's [nativevotes-updates](https://github.com/sapphonie/sourcemod-nativevotes-updated), with some small modifications and bug fixes. Most notably, the nativevotes-mapchooser has a persistent mapcycle that remains between restarts.
