# Farming Simulator modification - FollowMe

To read more about this mod, find it on;
- http://www.farming-simulator.com/mods.php
- http://fs-uk.com - http://fs-uk.com/mods/list/team/45

## FS19 - Change-log

Changelog 1.5.0.24:
- After several iterations of testing and fixing, multiplayer support is implemented

Changelog 1.4.0.10:
- First attempt at multiplayer support
- Added 'Collision Sensor on/off' toggle
- Fix for "lights flashing"
- Misc. code cleanup

1.3.0.6:
- Hiding the HUD-text after 5 seconds. Player must issue another 'Follow Me'-input-action to vehicle for displaying HUD-text again.
- Fix/work-around for making a follower-combine NOT stop at headlands/turning, due to its cutter detecting 'no more crops' to harvest.
- Reduced 'is blocked'-notifications, when obstacle/collision is detected.
- Removed superfluous 'title' and 'description' XML-tags from ModDesc.XML, for languages that are not shown in (the in-game) ModHub anyway.

1.2.0.3:
- "Quick-tap" keys activation threshold changed to '0.3 second' (was previously '150 ms')
- Attempt at obstacle/collision detection

1.1.0.2:
- Fix for causing error: "/specializations/Plow.lua(680) : attempt to compare number with nil"

1.0.1.1:
- Upgraded to FS19
- As per ModHub Team certification report request, have reduced to only using 'EN'-title, due to using same title-name for all languages


## FS17 - Change-log
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
- Release for ModHub

1.0.2.34
- Tweaks for speed and timers

1.0.2.32
- Italian translation update by Paxly
- Russian translation update Gonimy-Vetrom
- Polish translation update Ziuta

1.0.2.30
- Italian translation update by xno
- Changed speed & driving behaviour
- Limit speed when equipment active
- Fix motor stop problem
- Fix for vehicle reset/delete

1.0.1.21
- Spanish translation update by Vanquish081
- Possible work-around of the 'currentHelper' problem.

1.0.0.17
- Upgraded to FS17
- Added turn-light indication-state to 'trail-crumbs'
- Had to remove collision-box, so will crash into other vehicles!
- Changed versionnumbering-scheme due to ModHub


## FS15 - Change-log
2.3.0
- Version bump due to official updated release

2.2.3
- Misc. minor description changes

2.2.2
- Italian translation update by xno.
- Russian translation updated by Gonimy-Vetrom.

2.2.1
- Polish translation updated by Dzi4d3k.
- Minor fixes for the other translations too.

2.2.0
- Added ability to toggle offset between 'current offset' and zero.
- Changed input-bindings/actions to the following default keys:

    Note that the <kbd>*modifier*</kbd> shown below, is either;
    the <kbd>RIGHT CTRL</kbd> key, for the vehicle that the player is currently occupying, or
    the <kbd>RIGHT SHIFT</kbd> key, to control the follower that is behind the vehicle the player is in.

    Default keys, which can be changed in the Options Controls screen:
    <kbd>*modifier*</kbd>+<kbd>F</kbd> - start/stop 'Follow Me'.
    <kbd>*modifier*</kbd>+<kbd>H</kbd> - wait/resume.
    <kbd>*modifier*</kbd>+<kbd>W</kbd> / <kbd>*modifier*</kbd>+<kbd>S</kbd> - increase/decrease distance to leading vehicle. Hold keys to repeat.
    <kbd>*modifier*</kbd>+<kbd>A</kbd> / <kbd>*modifier*</kbd>+<kbd>D</kbd> - change left/right offset to leading vehicle. Hold keys to repeat.
    Quick tap <kbd>*modifier*</kbd>+<kbd>X</kbd> - toggle offset between 'current offset' and zero.
    Long press <kbd>*modifier*</kbd>+<kbd>X</kbd> - invert offset.

2.x.x
- No change-log was kept.
