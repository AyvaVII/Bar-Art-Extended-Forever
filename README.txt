Bar Art Extended 0.1
====================

Blizzard-style artwork for your action bars: borders, dividers, slot backgrounds
and (with Bartender4) gryphons. Works with the default UI and with Bartender4.
Made for the WoW Forever beta (build 16001).

Installation
------------
1. Close WoW.
2. If you used "Blizzard Art Expanded" before, delete its folder from Interface\AddOns.
3. Unzip the "BarArtExtended" folder to
   World of Warcraft\_classic_beta_\Interface\AddOns
   (The folder name in front of "Interface" may change when WoW Forever is released.)
4. Start WoW.

Usage
-----
Open the options with /bae  (Game Menu > Options > AddOns > Bar Art Extended).
Pages: Bar Art Extended, Dark Mode, Profiles.

Default UI:  bars 2-8 are decorated, bar 1 keeps Blizzard's own artwork.
             Gryphons and button spacing are set in Blizzard's Edit Mode.
Bartender4:  All Bartender4 bars are decorated, including gryphons on bar 1.
             Layout, scale and spacing are set in Bartender4.
             Blizzard bars that Bartender4 does not manage are decorated as well.

Commands
--------
/bae                         open the options
/bae on | off                switch the artwork on or off
/bae gryph <x> <y>           move the gryphons (Bartender4)
/bae gryph scale <0.25-1.5>  gryphon size (Bartender4)
/bae gryph front | back      gryphons in front of / behind the bar (Bartender4)
/bae margins <l> <r> <t> <b> border margins by hand, "/bae margins auto" to reset
/bae profile [name]          list or switch profiles
/bae reset                   reset the active profile
/bae debug                   print what the addon found (useful for bug reports)

Version 0.1 is the first release and is only tested with the WoW Forever beta.

Author: AyvaVII
