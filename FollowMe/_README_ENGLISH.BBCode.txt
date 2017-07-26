[b]Follow Me[/b]

[i]Remember to check the support topic for any additional information regarding this mod[/i]


[b][u]Changelog[/u][/b]
1.2.2.44
- Translations updated by contributors.

1.2.2.43
- Disallow MoreRealistic vehicles to 'speed up to catch up', as a temporary fix, until a better speed algorithm is found.
- MoreRealistic vehicles now apply brake if 'going faster than leader-vehicle'.

1.2.1.40
- Increased starting distance to 20, from 10.
- Fix for saving/loading distance and offset between savegame-sessions.

1.2.0.39
- Support for baler-and-wrapper combination; FBP 3135 (Kuhn DLC)

1.1.0.38
- Italian translation of keys description, by Paxly

1.1.0.37
- French translation update by Taco29

1.1.0.36
- Dutch translation update by pewemo

1.1.0.35
- Changed speed & driving behaviour
- Limit speed when equipment active
- Translations contributed/updated;
  - Russian by Gonimy-Vetrom
  - Polish by Ziuta
  - Italian by xno & Paxly
  - Spanish by Vanquish081
- Fix motor stop problem
- Fix for vehicle reset/delete
- Possible work-around of the 'currentHelper' problem

1.0.0.17
- Upgraded to FS17
- Added turn-light indication-state to 'trail-crumbs'
- Had to remove traffic-collision-triggerboxes, so will crash into other vehicles! Drive carefully.
- Changed versionnumbering-scheme due to ModHub


[b][u]Mod description[/u][/b]

Have you ever wanted to make a transport convoy, or just be able to; cut grass - dry it - rake it - bale it - wrap it - pick it up, with multiple tractors all in one go?

With the 'Follow Me' mod, a vehicle can be told to follow after another vehicle.


[b][u]How to use it[/u][/b]

Before telling about the controls, here's a list of [u]known problems[/u] that may occur when you use it:

- The speed of followers may not always be 100% accurate as it could be, with regards to how fast/slow they should drive when following the "[i]trail[/i]".

- Some vehicles may start to zig-zag, in the attempt at following the "[i]trail[/i]", due to trying to [i]touch[/i] every "[i]trail crumb[/i]". This is most obvious when reaching a turn at high speeds, and trying to "get back on track".

- Turning on beaconlights, when having set up a circular convoy - i.e. vehicle-A follows vehicle-B follows vehicle-C follows vehicle-A - will make the beaconlights repeatedly turn on and off.

[u]Controls[/u]

The action-keys, which can be changed in Options - Controls, are defined in two sets:

[i]Myself[/i] - For the vehicle the player is driving:

[b]RIGHT CTRL[/b] + [b]F  [/b] = Start/stop following the vehicle in front (if possible).
[b]RIGHT CTRL[/b] + [b]H  [/b] = Pause/resume following.
[b]RIGHT CTRL[/b] + [b]W/S[/b] = Decrease/increase following distance, in steps of [b]5[/b].
[b]RIGHT CTRL[/b] + [b]A/D[/b] = Adjust left/right offset when following, in steps of 0.5.
[b]RIGHT CTRL[/b] + [b]X  [/b] = Toggle offset between zero and last value.
[i]press-and-hold[/i] [b]RIGHT CTRL[/b] + [b]X[/b] = Invert the offset (left-to-right, right-to-left).
[i]press-and-hold[/i] [b]RIGHT CTRL[/b] + [b]W/S[/b] to repeat decrease/increase in steps of [b]1[/b].

[i]Behind[/i] - To control the vehicle that is following behind [i]me[/i] (if any):

[b]RIGHT SHIFT[/b] + [b]F  [/b] = Stop the follower.
[b]RIGHT SHIFT[/b] + [b]H  [/b] = Pause/resume the follower.
[b]RIGHT SHIFT[/b] + [b]W/S[/b] = Decrease/increase the follower's distance to [i]me[/i], in steps of [b]5[/b].
[b]RIGHT SHIFT[/b] + [b]A/D[/b] = Adjust the follower's left/right offset, in steps of 0.5.
[b]RIGHT SHIFT[/b] + [b]X  [/b] = Toggle the follower's offset between zero and last value.
[i]press-and-hold[/i] [b]RIGHT SHIFT[/b] + [b]X[/b] = Invert the follower's offset (left-to-right, right-to-left).
[i]press-and-hold[/i] [b]RIGHT SHIFT[/b] + [b]W/S[/b] to repeat decrease/increase in steps of [b]1[/b].

Note: Each set of action-keys [u]must use[/u] the same modifier-key!

[u]Switching it on/off[/u]

To follow some vehicle, point your own vehicle towards it and press the start action (RIGHT CTRL + F).

If no "[i]trail crumbs[/i]" can be found, or the vehicle already is followed by another, a warning will appear and you will have to either move a little bit further towards/back, or change to follow another vehicle.

It is possible to "pause" driving, and then later "resume" following the leader's trail, using the wait/resume action (RIGHT CTRL + H).

To stop following, press the same action again (RIGHT CTRL + F).

[u]Distance and offset[/u]

The follow distance can be set using RIGHT CTRL + W/S, in increments of approximate 5 meters. Positive values are "keep back" distance (up to +250), and negative values are "in front" (up to -50).

Do please note that current there are no traffic-collision-triggerboxes, so vehicles will not be able to detect when/if they collide into the leading vehicle or some other vehicle - so you better set the distance further back.

Left/right offset is set using RIGHT CTRL + A/D, in increments of approximate 0.5 meter.

The offset can be toggled between 'zero' and 'last offset value' (RIGHT CTRL + X), or inverted (press-and-hold RIGHT CTRL + X).

[u]Equipment/tools handling[/u]

If a follower has a [i]turned on[/i] round-baler or a bale-wrapper, it will now automatically unload the bale. Please note; primarily only the vanilla Baler/BaleWrapper scripts are supported, so some mod balers may not work as intended.


[b][u]Restrictions[/u][/b]

This mod's script files MAY NOT, SHALL NOT and MUST NOT be embedded in any other mod nor any map-mod!

Please do NOT upload this mod to any other hosting site - I can do that myself, when needed!

Keep the original download link!


[b][u]Problems or bugs?[/u][/b]

If you encounter problems or bugs using this mod, please use the support-thread.

Known bugs/problems:
- Followers are not able to detect traffic-vehicles, and will therefore collide with them.
- Followers speed is not always 100% accurate.
- Too high speed into a turn, or having a slow steering, will make the follower go zig-zag in an attempt at "getting back on track".
- Follower-vehicles that has no build in traffic-collision-box can (obviously) not detect if they are about to collide with something in front.


Credits:
Script:
- Decker_MMIV
Contributors/Translations:
- DrUptown, spinah, fendtfreek, Gonimy_Vetrom, bbj89, DD ModPassion, pokers, Ziuta, pewemo, Alfredo Prieto, xno,
- Vanquish081, Paxly, Taco29, Anonymous
