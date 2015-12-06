## Civ4 Map Cad

New Update!! There's now a "quick start" mode; see instructions below.

Civ4 Map Cad (Civ4MC) is a tool for making multiplayer maps for Civilization 4! The goal of this project is a provide a way for map designers to quickly make interesting and fair multiplayer maps. Civ4MC's powerful macro-level map manipulation tools and balance checkers work hand in hand - with an accurate way to check balance, maps can be made more asymetrical/interesting while still being fair, and with ways to make large changes in the map without hassle or affecting the rest of the map, designers can more easily incorporate feedback from the balance checkers and lurkers.

Features:
* Powerful layer-based map manipulation tools that allow you to generate terrain out of arbitrary shapes and functions, cut, paste, and more!

* Built-in documentation for every command, and a series of six illustrated, in-depth [tutorials](tutorials/), starting at the very basics and going all the way to rolling and balancing a map!

* Generate a handy HTML view of your map! Mouse-hovering on each tile reports coordinates/resources/player info, making it very easy to collaborate with others and get lurker feedback from people browsing the forums at work! Example: [tutorial2 map](http://media.rhizzone.net/civ4mc/t2.html).

* Highly sophisticated balance tools ensure that your map is fair for all players even for highly asymetrical maps!

* Script-based design and a detailed HTML view of the maps allows for easy collaboration with fellow mapmakers and easy balance adjustments!

* Command line interface to map creation allows you to play around with Civ while at work - and it'll even still look like you're doing work!

* Generate starting sims for multiplayer games!

Read through the tutorials in the [tutorials/](tutorials/) directory or Commands.md in the [doc/](doc/) directory to find out more!

## Quickstart Mode

0.) Install actveperl, if you don't already have it: http://www.activestate.com/activeperl
1.) Download the new version, extract everything to a folder: https://github.com/germanjoey/civ4-mapcad/archive/master.zip (for example, drag the contents of this zip file to your My Documents folder)
2.) Put your map into the directory you just unzipped. This is the same directory as the one containing mapcad.pl and rename the map to map.CivBeyondSwordWBSave
3.) Double-click on easy_click.pl
4.) Press enter twice, if using Civ4 BTS. If using a different mod, pick the right mod.
5.) Wait a few minutes for the thing to calculate stuff
6.) Press enter again.
7.) Outputs are now ready.

The sims for each start and the checked map (named map_fixed.CivBeyondSwordWBSave) will be in the outputs/ folder, while map_fixed.html (the balance report) and map_fixed.bfc_value.html will be in the base directory. The actual balance report is attached in a big text box at the bottom of map_fixed.html.