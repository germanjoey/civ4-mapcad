## A Different Way of Generating and Manipulating Maps

Because Civ4 already comes with an excellent map editor, that's even been expanded by the mod community to further levels of functionality (such as Platy Builder here: http://forums.civfanatics.com/showthread.php?t=491837), there's no need here to implement tools for tile-by-tile editing tasks.  Instead, the goal of this tool is to focus on large tasks, such as "moving a large island or starting area northwest by 6 tiles" or "add a large continent to a map and randomly populate it with trees, varied terrain, and resources." If the WorldBuilder is like MS Paint, then Civ4 Map Cad is supposed to be all those special features of Photoshop that let you do more sophisticated stuff than just simple clicking on pixels.

Philosophically, this tool was designed to work like CAD tools used to build integrated circuits. Building computer chips is similar to building a Civ4 map in that you have a big, multi-colored grid where the tiles/shapes/blocks actually mean specific things about how the circuit works, similar to how Civ4 tiles mean specific things for yield/movement-cost/unit-enabling/etc. These grids are simply far too big to even imagine manipulating stuff a tile at a time (chips these days may contain a few billion transistors), so most manipulations tend to be command-line based. You do a command, then refresh the view, repeat. Multiple commands can be chained together in the form of a script. It's sort of like programming, except its not really programming because you'll have very few functions or loops or custom data structures, and ideally none at all. &#42;Everything&#42; is done with commands. Commands tend to be very specific and have few options so that you can be sure that what the command does is actually what you want it to do. A command might look like this:

    > move_layer_by $pb34.start3 3 0
    
This command moves a layer named "$pb34.start3" (a layer is a map object) 3 tiles to the right. How do I know? Because I can read about what each command does by reading its description via --help:

    > move_layer_by --help

    move_layer_by $groupname.layername int int 
      param 1: layer to move
      param 2: move by this amount in the x direction
      param 3: move by this amount in the y direction
      
    Description:
    The specified layer is moved by offsetX, offsetY within its group.
    
    >
    
Some commands are very simple in what they do, like this one, while others are very sophisticated, like *export_sims* or "rotate_layer*. However, they all very specifically do a single thing.