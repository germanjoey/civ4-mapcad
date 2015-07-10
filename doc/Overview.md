Generating Maps and Editing Maps

Because Civ4 already comes with an excellent map editor, that's even been expanded by the mod community to further levels of functionality (such as Platy Builder here: http://forums.civfanatics.com/showthread.php?t=491837), there's no need here to implement tools for tile-by-tile editing tasks.  Instead, we focus on large tasks, such as "moving a large island or starting area northwest by 6 tiles" or "add a large continent to a map and randomly populating it with trees, varied terrain, and resources." The former we can do with "layers," while the latter we can do with the help of "masks."

Groups and Layers

Layers will likely be pretty easy understand. If you've ever used Photoshop, The Gimp, Powerpoint, etc, you're already familiar with the idea: seperate parts of an image are seperated from each other so that you can move them around independently of each other. When you're finally done with your design, layers get merged together (with content from layers on "top" overwriting that of those on the "bottom", but transparent areas from the top allowing content from the bottom to remain) so that the final product is one single image/presentation/map. Layers in this tool are grouped together as "Groups"

There are a few different ways to create Groups and Layers in this tool:

1.) Import an already-existing map file as a new project, which creates a Group with a single layer. (see the XXX command.)
2.) Copy a layer from a different group. (see the XXX command)
3.) Cut out a layer from another layer, as if you were using a cookie-cutter on a sheet of dough and forcing the cutout to float above. 
4.) Generate a layer with new terrain from a Mask  (more on these later)

Some of you might be wondering how we can support layers when Civ4 does not have a transparent/empty tile type. We need to cheat a little bit, and use ocean/coast tiles instead. Thus, a Group with these two layers:
