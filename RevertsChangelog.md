# Castaway.tf Weapon Reverts Changelog

[Go back to Castaway.tf Home](https://castaway.tf)

### May 9, 2025
- **Fixed the Big Earner's 3-second speedboost being extended by the reverted Dead Ringer on feign death.**
- **Fixed the duration reduction of Spies under Dead Ringer when being damaged by weapons such as the Ullapool Caber and the Enforcer.**
- **Made the damage resistance attribute of the reverted Brass Beast (and the Natascha) to be more historically accurate.**
  - The damage resistance percentage now depends on what type of damage is dealt onto the Heavy. For normal damage, 20% damage resistance is applied. For mini-crit damage received, 14.7% damage resistance is applied. For critical hit damage received, 6.7% damage resistance is applied.
- **Damage resistance sounds now play when the Heavy is hit while spinning up the reverted Brass Beast and the reverted Natascha.**
- **Reverted Natascha to pre-Meet your Match. The 20% damage resistance when spun up now applies regardless of current HP.**
  - *The Natascha*
    - On Hit: 100% chance to slow target
    - 20% damage resistance when spun up
    - -25% damage penalty
    - 30% slower spin up time

### May 1, 2025
- **Updated reverts.txt offsets in the gamedata folder, fixing the Soldier's rocket kills showing up as headshots, the reverted Short Circuit's alt-fire using the modern energy ball, and the Thermal Thruster playing a parachute sound on use.**
  - For context, TF2 had a recent patch which affected the weapon reverts plug-in.
- **Updated the reverted Crit-a-Cola's damage vulnerability attribute to be more historically accurate.**
  - The 10% damage vulnerability should only apply to normal damage. Mini-crit and critical hit damage does not get modified by the 10% damage vulnerability attribute. This means Scouts don't die faster to mini-crits and critical hits now.
- **Fixed the reverted Black Box's heal-on-hit attribute to work again.**

### April 28, 2025
- **Added Windows port for the weapon reverts plugin. The plugin should now work out of the box for Windows servers.**
- **Reverted the Quick-Fix to have 25% increased Uber build rate, and to be able to capture objectives while under the effects of its Uber for both the healer and patient.**

### April 26, 2025
- **The reverted Tide Turner's blast and fire damage resistances have been updated to 25% each to be more historically accurate (pre-Tough Break).**
  - *The Tide Turner*
     - +25% fire damage resistance on wearer
     - +25% explosive damage resistance on wearer
     - Full turning control while charging
     - Melee kills refill 75% of your charge meter
     - Taking damage while shield charging reduces remaining charging time
- **The reverted Soda Popper's visuals have been updated to be more historically accurate to its release version. When the Hype meter is full, the glow now shows up as a Mini-Crits glow instead of a purple glow.**
  - The purple glow will only appear if the Scout equips the Crit-a-Cola or the Bonk! Atomic Punch due to how the game technically handles Mini-Crit conditions.

### April 21, 2025
- **The Dead Ringer is now reverted to its most accurate state before Gun Mettle. 90% damage resistance for up to 6.5 seconds that gets reduced by damage received. This Dead Ringer is now able to tank 5 backstabs and 8 stickybombs from 125 HP, and 14 stickybombs when using the Kunai at 200 HP. The previous version of the revert would only tank 1 backstab and up to 4 to 5 stickybombs.**
- **Fixed reverted Powerjack bug where the Pyro gets healed when an enemy dies to afterburn while the Powerjack is the active weapon. It should only heal due to melee kills by the Powerjack.**

### April 17, 2025
- **Fixed reverted Black Box overheal bug where hitting an enemy removes the Soldier's overheal.**
- **Ball recharge time for the reverted Sandman is now 15 seconds long for historical accuracy (pre-Inferno).**
- **Claidheamh Mor +0.5s charge time increase now applies to other weapons.**
- **Reverted Powerjack to pre-Gun Mettle version, same stats as the modern one but with +75 HP on kill with overheal.**

	- *The Powerjack*
	  - When weapon is active:
	  - +15% faster move speed on wearer
	  - +75 health restored on kill
	  - Health restoration can overheal
	  - 20% damage vulnerability on wearer

### April 5, 2025
- **Reverted Black Box to pre-gunmettle, flat +15 per hit, uncapped**
  - *The Black Box*
    - On Hit: +15 health
    - -25% clip size

### April 4, 2025
- **Disabled Scottish Resistance revert. The server now uses the modern Scottish Resistance version.**
- **Reverted the following weapons:**
  - Wrangler to pre-Gun Mettle (shield values only)
  - Rescue Ranger to pre-Tough Break
  - Disciplinary Action to pre-Meet your Match
  - Razorback to pre-Jungle Inferno
  - Warrior's Spirit to pre-Tough Break
  - Cozy Camper to pre-Meet your Match
  - Dragons Fury (to its more accurate release version)
  - Ramp up for all Heavy Miniguns (pre-Love and War)
  - Deploy and holster speeds for all Demoman swords (pre-Tough Break)

### March 26, 2025
- **Reverted Rocket Jumper self-explosion damage immunity.**
- **Taunting with the Equalizer or Escape Plan while using the Rocket Jumper:**
  - No longer kills the Soldier
  - Leaves Soldier’s health intact and knocks them upward

### March 19, 2025
- **Reverted Brass Beast to the pre-Meet your Match version.**
  - *The Brass Beast*
    - +20% damage bonus
    - 20% damage resistance when spun up
    - 50% slower spin up time
    - -60% slower move speed while deployed

### March 9, 2025
- **Restored Saharan Spy Item Set Bonus (does not require Familiar Fez)**
  - *The Saharan Spy*
    - L'Etranger
    - Your Eternal Reward
  - **Item Set Bonus:**
    - Reduced decloak sound volume
    - 0.5 sec longer Cloak blink time

### February 24, 2025
- **Changed Backburner to Hatless Update version**
  - *The Backburner*
    - 100% critical hits from behind
    - Extinguishing teammates restores 20 health
    - 10% increased damage
    - +150% airblast cost
- **Reverted Cleaner's Carbine to release version**
  - *The Cleaner's Carbine*
    - On Kill: 3 seconds of 100% critical chance
    - -20% clip size
    - 35% slower firing speed
    - No random critical hits

### February 12, 2025
- **Reverted Backburner to 119th Update version**
  - *The Backburner*
    - 100% critical hits from behind
    - Extinguishing teammates restores 20 health
    - 20% increased damage
    - No airblast

### February 2, 2025
- **Reverted Claidheamh Mòr to pre-Tough Break**
  - *The Claidheamh Mòr*
    - 0.5 sec increase in charge duration
    - Melee kills refill 25% of your charge meter
    - No random critical hits
    - -15 max health on wearer
    - This weapon has a large melee range and deploys and holsters slower
  - *Note: deploy and holster speeds weren't changed in this patch.*
- **Fixed extra damage taken with the Eviction Notice when equipped but not deployed**

### January 20, 2025
- **Reverted Tribalman's Shiv to release version**
  - *The Tribalman's Shiv*
    - On Hit: Bleed for 8 seconds
    - -35% damage penalty

### January 15, 2025
- **Disabled airblast revert — using current vanilla airblast version**

### January 11, 2025
- **Reverted Spy-cicle to pre-Gun Mettle**
  - *The Spy-cicle*
    - Silent Killer: No attack noise from backstabs
    - On Hit by Fire: Become fireproof for 2 seconds
    - Backstab turns victim to ice
    - Melts in fire, regenerates after 15 seconds
    - Changed fireproof duration from 3 to 2 seconds

### December 29, 2024
- **Reverted Pretty Boy's Pocket Pistol to release**
  - *Pretty Boy's Pocket Pistol*
    - +15 max health on wearer
    - Wearer never takes falling damage
    - 25% slower firing speed
    - 50% fire damage vulnerability on wearer

### December 28, 2024
- **Reverted Loch-n-Load back to post-Smissmas 2014 / pre-Gun Mettle Update**
  - *The Loch-n-Load*
    - +20% damage bonus
    - +25% projectile speed
    - -25% clip size (3 pipes in clip)
    - -25% explosion radius
    - Launched bombs shatter on surfaces

### December 26, 2024
- **Reverted Scottish Resistance to release**
  - *The Scottish Resistance*
    - +50% max secondary ammo on wearer
    - +6 max pipebombs out
    - Detonates stickybombs near crosshair
    - Able to destroy enemy stickybombs
    - 0.4 sec slower bomb arm time
- **Reverted Loch-n-Load to pre-Smissmas 2014**
  - *The Loch-n-Load*
    - +20% damage bonus
    - +25% projectile speed
    - -50% clip size (2 pipes in clip)
    - +25% damage to self
    - Launched bombs shatter on surfaces
  - **Note: when this was implemented, the grenade tumbling attribute was not included, so this reverted version was historically inaccurate.**
    - Historically, the grenade tumbling attribute in the pre-Smissmas 2014 Loch-n-Load was not only a visual difference, but also slowed down the old Loch-n-Load's projectile speed.
      - See video for a demonstration of the grenade tumbling attribute affecting projectile speed: https://youtu.be/ACfafLuLmy8?t=143
      - This is caused by the Source physics engine including air resistance with projectiles.
   
### December 12, 2024
- **All Castaway.tf servers now use Bakugo's Weapon Reverts plugin.**

### November 14, 2024
- **Crit-a-Cola has been reverted to pre-Meet your Match around this time.**
  - *The Crit-a-Cola*
    - While under the effects, +25% movement speed, your attacks mini-crit, and damage taken increased by 10%.

### November 11, 2024
- **Changed the plugin used for the Weapon Reverts servers (Bakugo's Weapon Reverts instead of NotnHeavy's Pre-Gun Mettle Reverts). Instead of a blanket gun-mettle revert, it selectively reverts weapons. It also doesn't cause lag.**

### October 10, 2024
- **Some Castaway.tf servers now uses the blanket Pre-Gun Mettle reverts plugin made by NotnHeavy.**
