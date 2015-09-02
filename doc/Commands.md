#Command List
This file is auto-generated from bin/make_command_doc.pl from the in-program help text for each command.

##add_scouts_to_settlers
    add_scouts_to_settlers $groupname 
      param 1: group to add to

Wherever a settler is found in any layer, a scout is added on top of it. This command modifies the group.

##add_sign
    add_sign $groupname.layername int int "string" 
      param 1: layer in which to add the sign
      param 2: x coordinate
      param 3: y coordinate
      param 4: caption

Adds a sign to a specified coordinate

##apply_shape_to_mask
    apply_shape_to_mask *shapename @maskname --shape_param1 value1 --shape_param2 value2 => @maskname 
      param 1: shape to apply
      param 2: mask to change

Transforms a mask by applying a shape to each coordinate of the mask, meaning that the current value of the coordinate is an input to the shape function.

##balance_report
    balance_report $groupname [ --options ] 
      param 1: group to report on

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 5 possible optional parameters:
     
    --balance_config "string": defaults to "def/balance.cfg".  configuration file for all the various constants used in the allocation algorithm.  
    --heatmap "string": defaults to "bfc_value".  Creates a mask from some attribute of the mask and then immediately makes an html view of it, as if 'debug_mask' was used. If a name is preceded by a '+', then the heatmap will be appended to the current debug output, as if 
    --add_to_existing were used.  
    --iterations int: defaults to 100.  Number of times to simulate  
    --sim_to_turn int: defaults to 155.  Ending turn of each simulation. It can be a good idea to check the status of the map at various different endpoints  
    --tuning_iterations int: defaults to 40.  Number of extra times to simulate to set the estimate for contention  

Generates a balance report based on an MCMC land allocation algorithm.

##combine_groups
    combine_groups $groupname $groupname => $groupname 
      param 1: group A
      param 2: group B

    Specifying a result for this command is optional; if not specified, the original group will be overwritten.

Merges two groups A and B, into one; all layers in B will be placed under all layers in A.

##copy_group
    copy_group $groupname => $groupname 
      param 1: group to copy

Copy one group into duplicate with a different name.

##copy_layer_from_group
    copy_layer_from_group $groupname.layername [ --options ] => $groupname.layername 
      param 1: layer to copy

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --place_on_top: optional; defaults to false.  If set, then the copied layer is set to top priority in the new group.  

Copy a layer from one group to another (or the same) group.

##count_mask_value
    count_mask_value @maskname float [ --options ] 
      param 1: mask to generate from
      param 2: weight table used to translate values into terrain

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --threshold: optional; defaults to false.  If set, then the mask will be thresholded first, and then counted.  
    --threshold_value float: defaults to 0.5.  Threshold level for 
    --threshold.  

Counts the number of values in the mask that match the target value. If '--threshold' is set, the mask will be thresholded first, and then counted.

##count_tiles
    count_tiles $groupname.layername %weightname float [ --options ] 
      param 1: the layer to find tiles in
      param 2: the weight to filter the layer with

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 4 possible optional parameters:
     
    --exact_match: optional; defaults to false.  Require exact matches from tiles to terrains.  
    --post_match_threshold int: defaults to 0.  If the weight matched but evaluates to 0, it will instead be boosted to this value to differentiate it from non-matches.  
    --pre_count_threshold: optional; defaults to false.  Run a threshold operation on the mask before the count is performed.  
    --pre_count_threshold_value float: defaults to 0.0001.  if 
    --pre_count_threshold is set, then any value greater or equal to this will be raised to 1  

Filters tiles in a layer based on a weight, and then counts the ones that match a value. Matches by default are not exact; e.g. a 'bare_hill' would match both a grassland hill or a plains hill.

##crop_group
    crop_group $groupname int int int int => $groupname 
      param 1: group to crop
      param 2: left
      param 3: bottom
      param 4: right
      param 5: top

    Specifying a result for this command is optional; if not specified, the original group will be overwritten.

The group's dimensions are trimmed to left/bottom/right/top, from the nominal dimensions of 0 / 0 / width-1 / height-1. Any member layers that exceed these dimensions are cropped as well.

##crop_layer
    crop_layer $groupname.layername int int int int => $groupname.layername 
      param 1: layer to crop
      param 2: left
      param 3: bottom
      param 4: right
      param 5: top

    Specifying a result for this command is optional; if not specified, the original layer will be overwritten.

This layer's dimensions are trimmed to left/bottom/right/top, from the nominal dimensions of 0 / 0 / width-1 / height-1, in reference to the layer. After the crop, the layer is then moved by -left, -bottom, so that tiles are essentially in the exact same place they started.

##cutout_layer_with_mask
    cutout_layer_with_mask $groupname.layername @maskname [ --options ] => $groupname.layername 
      param 1: layer to cutout from
      param 2: mask to define selection

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 3 possible optional parameters:
     
    --copy_tiles: optional; defaults to false.  If set, then the tiles in the original layer will not be deleted.  
    --offsetX int: defaults to 0.  The X-offset of the mask compared to the layer tile at 0,0, i.e. the mask is moved this many columns before the cutout occurs.  
    --offsetY int: defaults to 0.  The Y-offset of the mask compared to the layer tile at 0,0, i.e. the mask is moved this many rows before the cutout occurs.  

Cuts tiles out of a layer with a mask into a new layer, as if the mask were a cookie-cutter and the original layer was dough. Tiles in the original layer are deleted. (replaced with blank tiles (ocean)).

##debug_group
    debug_group $groupname [ --options ] 
      param 1: group to debug

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --add_to_existing: optional; defaults to false.  If used, the group visualization will be appended to the most recent debug window as a set of new tabs.  
    --alloc_file "string": defaults to "".  Used by report_balance and balance.pl; if specified, this command will use the alloc file to generate the empire overlay visualization. You probably shouldn't this on your own.  

Displays a group in the debug.html debugging window. Each layer will appear as its own tab.

##debug_layer
    debug_layer $groupname.layername [ --options ] 
      param 1: layer to debug

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --add_to_existing: optional; defaults to false.  If used, the layer visualization will be appended to the most recent debug window as a set of new tab.  

Displays a single layer in the debug.html debugging window.

##debug_mask
    debug_mask @maskname [ --options ] 
      param 1: mask to debug

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --add_to_existing: optional; defaults to false.  If used, the mask visualization will be appended to the most recent debug window as a new tab.  

Displays a mask into the debug.html debugging window as a visual grid. Mask values closer to zero will appear blue, while those closer to 1 will appear red.

##debug_mask_in_console
    debug_mask_in_console @maskname 
      param 1: mask to debug

Debug a mask as ascii-art in the console for quick debugging.

##debug_weight
    debug_weight %weightname [ --options ] 
      param 1: weight to describe

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --add_to_existing: optional; defaults to false.  If used, the weight definition will be appended to the most recent debug window as a new tab.  
    --flatten: optional; defaults to false.  Determines whether nested weights are expanded or not.  

Shows the definition for a weight in the console.

##decrease_layer_priority
    decrease_layer_priority $groupname.layername 
      param 1: layer to set

Moves a layer 'down' in the visibility stack; see 'set_layer_priority' for more details.

##delete_from_layer_with_mask
    delete_from_layer_with_mask $groupname.layername @maskname [ --options ] 
      param 1: layer to modify
      param 2: mask to select with

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --offsetX int: defaults to 0.  The X-offset of the mask compared to the layer tile at 0,0, i.e. the mask is moved this many columns before the tile deletion occurs.  
    --offsetY int: defaults to 0.  The Y-offset of the mask compared to the layer tile at 0,0, i.e. the mask is moved this many rows before the tile deletion occurs.  

Uses a mask to match tiles on a layer, and then sets them to blank ocean tiles. Any mask coordinate with a positive value will match a tile.

##delete_layer
    delete_layer $groupname.layername 
      param 1: the layer to delete

Deletes a layer from a group.

##eval
    eval <code> 

Evaluates perl code and prints the result. Everything on the command line after the 'eval' keyword will be evaluated.

##evaluate_weight
    evaluate_weight %weightname float 
      param 1: weight
      param 2: value to evaluate

Evaluates the result of a weight table with an arbitrary floating point value between 0 and 1, e.g. as if that value were the coordinate 'evaluate_weight' is only intended to be a debugging command; please see the Mask-related commands, e.g. 'generate_layer_from_mask', 'modify_layer_from_mask', for actually using weights to generate/modify tiles.

##evaluate_weight_inverse
    evaluate_weight_inverse %weightname terrainname [ --options ] 
      param 1: weight
      param 2: terrain to evaluate

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --exact_match: optional; defaults to false.  Require exact matches from tiles to terrains.  

Evaluates the inverse result of a weight table with an terrain in order to get the corresponding value, e.g. as if this terrain were at the coordinates of a layer tile. 'evaluate_weight_inverse' is only intended to be a debugging command; please see the Mask-related commands, e.g. 'generate_layer_from_mask', 'modify_layer_from_mask', for actually using weights to generate/modify tiles.

##exit
    exit 

Exits.

##expand_group_canvas
    expand_group_canvas $groupname int int 
      param 1: group to expand
      param 2: expand width by
      param 3: expand height by

Expands a group's dimensions by an extra amount.

##expand_layer_canvas
    expand_layer_canvas $groupname.layername int int 
      param 1: layer to expand
      param 2: expand width by
      param 3: expand height by

Expands a layer's dimensions; attempting to expand the layer to be bigger than its containing group will cause an error.

##export_group
    export_group $groupname 
      param 1: group to export

Exports a flat version of the group as a CivBeyondSwordWBSave, in addition to also doing so for each layer seperately.

##export_mask_to_ascii
    export_mask_to_ascii @maskname "string" [ --options ] 
      param 1: output filename

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --mapping_file "string": defaults to "def/standard_ascii.mapping".  Specify a custom mapping file. See def/standard_ascii.mapping for an example.  

This command generates an ascii rendering of a mask based on a mapping file. The second parameter is the output filename. The format of the mapping file is that there's one character and one value per line. Values that don't exactly match will instead use the closest value instead.

##export_mask_to_table
    export_mask_to_table @maskname "string" 
      param 1: mask to export
      param 2: output filename

Exports the mask to a table file; one line per coordinate, first column x, second column y, third column value.

##export_sims
    export_sims $groupname 
      param 1: group to extract from

The '@bfc' mask is applied on each settler, and then that selected area is extracted as a new layer. The group is then exported ala the 'export_group' command, with each layer being saved as its own CivBeyondSwordWBSave. This command does not modify the group.

##extract_starts
    extract_starts $groupname => $groupname 
      param 1: group to extract from

    Specifying a result for this command is optional; if not specified, the original group will be overwritten.

The '@bfc' mask is applied on each settler, and then that selected area is extracted as a new layer.

##find_difference
    find_difference $groupname $groupname => $groupname 
      param 1: group A
      param 2: group B

Take a positive difference between mapobj a and mapobj b to create a new mapobj c, such that merging c onto a creates b ocean means "nothing", and fallout over ocean means actual ocean. Basically, this is useful if you're creating a map in pieces and want to do hand-edits in the middle. That way, you can regenerate the map from scratch while still including your hand-edits. This command acts on two flat groups, so merge all layers first if you need to.

##find_starts
    find_starts $groupname 
      param 1: group to find settlers in

Finds starts (settlers) in a group and reports their locations.

##flatten_group
    flatten_group $groupname [ --options ] => $groupname 
      param 1: group to flatten

    Specifying a result for this command is optional; if not specified, the original group will be overwritten.

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --rename_final_layer: optional; defaults to false.  If set, the final layer will be renamed to the same name as the group's name.  

Flattens a group by merging all layers down, starting with the highest priority. Tiles at the same coordinates in an 'upper' layer will overwrite ones on a 'lower' layer. Ocean tiles are counted as "transparent" in the upper layer. Use the 'list_layers' command to see layer priorities.

##flip_layer_lr
    flip_layer_lr $groupname.layername => $groupname.layername 
      param 1: layer to flip

    Specifying a result for this command is optional; if not specified, the original layer will be overwritten.

Flip a layer horizontally. Rivers' direction in the layer are also flipped to match the new orientation.

##flip_layer_tb
    flip_layer_tb $groupname.layername => $groupname.layername 
      param 1: layer to flip

    Specifying a result for this command is optional; if not specified, the original layer will be overwritten.

Flip a layer horizontally. Rivers' direction in the layer are also flipped to match the new orientation.

##generate_layer_from_mask
    generate_layer_from_mask @maskname %weightname [ --options ] => $groupname.layername 
      param 1: mask to generate from
      param 2: weight table used to translate values into terrain

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --offsetX int: defaults to 0.  The X-offset of the mask compared to the layer tile at 0,0, i.e. the mask is moved this many columns before the tile generation occurs.  
    --offsetY int: defaults to 0.  The Y-offset of the mask compared to the layer tile at 0,0, i.e. the mask is moved this many rows before the tile generation occurs.  

Create a layer by applying a weight table to a mask. The value at each mask coordinate is evaluated according to the weight table, which is used to generate a new tile. For example, if the mask's value at coordinate 3,2 is equal to 0.45, and the weight table specifies that values between 0.4 and 1 map to an ordinary grassland tile, then the output layer will have a grassland tile at 3,2.

##grow_mask
    grow_mask @maskname int [ --options ] => @maskname 
      param 1: mask to grow
      param 2: number of tiles to grow by

    Specifying a result for this command is optional; if not specified, the original mask will be overwritten.

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --rescale: optional; defaults to false.  If set, the command attempts to keep the same size mask as long as there is empty space to chop away.  
    --threshold float: defaults to 0.5.  Set a custom threshold level for the mask before the grow operation occurs.  

Expands the mask a certain number of tiles. Only values of '1' are considered; thus, before the actual grow operation occurs, the mask is first thresholded. The mask produced by this command will be larger in the input mask; all four directions will be stretched by the number of tiles that the mask is grown.

##grow_mask_by_bfc
    grow_mask_by_bfc @maskname [ --options ] => @maskname 
      param 1: mask to grow

    Specifying a result for this command is optional; if not specified, the original mask will be overwritten.

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 3 possible optional parameters:
     
    --threshold float: defaults to 0.5.  Set a custom threshold level for the mask before the grow operation occurs.  
    --wrapX: optional; defaults to false.  If set, the command attempts grow the mask across the edges, wrapping from left to right.  
    --wrapY: optional; defaults to false.  If set, the command attempts grow the mask across the edges, wrapping from top to bottom.  

Expands the mask as if you put a city's BFC on each value with a 1.0. Only values of '1' are considered; thus, before the actual grow operation occurs, the mask is first thresholded. Unlike 'grow_mask', this command does not increase the size of the output mask, since you're probably only going to use this to check something on a map. Instead, you're given the option to specify x/y wrap, both of which are off by default.

##help
    help searchstring 

Prints the list of available commands. A search string is optional, but, if present, the list of available commands will be filtered.

##history
    history 

Prints a list of all previous commands back to the command line.

##import_group
    import_group "string" => $groupname 
      param 1: filename

Create a new group by importing an existing worldbuilder file. The new group will have a single layer with the same name as the result group.

##import_mask_from_ascii
    import_mask_from_ascii "string" [ --options ] => @maskname 
      param 1: input filename

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --mapping_file "string": defaults to "def/standard_ascii.mapping".  Specify a custom mapping file. See def/standard_ascii.mapping for an example.  

The 'import_mask_from_ascii' command generates a mask by reading in an ascii art shape and translating the characters into 1's and zeroes, if, for examples, you wanted to create a landmass that looked like some kind of defined shape. By default, a '*' equals a value of 1.0, while a ' ' equals a 0.0; intermediate values map to letters of the alphabet, according to def/standard_ascii.mapping.

##import_mask_from_table
    import_mask_from_table "string" => @maskname 
      param 1: input filename

Imports a mask from a table file; one line per coordinate, first column x, second column y, third column value.

##import_shape
    import_shape "string" => *shapename 
      param 1: path

Imports a shape module from the shapes/ directory, probably during the Civ4MC bootup phase.

##import_weight_table_from_file
    import_weight_table_from_file "string" => %weightname 
      param 1: weight definition filename

Creates a new Weight Table from a definition described in a file. In short, it follows a format of "operator threshold => result". The result can be either be a terrain or another already-existing Weight Table, the threshold should be a floating point number, and the operator should be either '==' or '>='.

##increase_layer_priority
    increase_layer_priority $groupname.layername 
      param 1: layer to set

Moves a layer 'up' in the visibility stack; see 'set_layer_priority' for more details.

##list_civs
    list_civs [ --options ] 

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --civ "string": defaults to "".  If specified, then instead of listing all possible civs, this command will show all config data for that particular civ.  

Lists all available civs (loaded from the XML) that can be used with the 'set_player_data' command, for the current mod.

##list_colors
    list_colors [ --options ] 

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --color "string": defaults to "".  If specified, then instead of listing all possible colors, this command will show all civs that use that color by default.  

Lists all available colors (loaded from the XML) that can be used with the 'set_player_data' command, for the current mod.

##list_groups
    list_groups search_term 

The search_term is optional and not quoted; if not supplied, all live groups will be listed.

##list_layers
    list_layers $groupname 
      param 1: group to describe

Lists all layers of a group by priority.

##list_leaders
    list_leaders [ --options ] 

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --trait "string": defaults to "".  If specified, then instead of listing all possible leaders, this command will show all leaders that have that particular trait.  

List all valid leader names (loaded from the XML) that can be used with the 'set_player_data' command, for the current mod.

##list_masks
    list_masks search_term 

The search_term is optional and not quoted; if not supplied, all live masks will be listed.

##list_mods
    list_mods 

Lists all available mods that can be set via the 'set_mod' command.

##list_shapes
    list_shapes search_term 

The search_term is optional and not quoted; if not supplied, all live shapes will be listed.

##list_techs
    list_techs [ --options ] 

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --tech "string": defaults to "".  If specified, then instead of listing all possible techs, this command will show all civs that start with that particular tech.  

Lists all valid starting techs (loaded from the XML) for the current mod.

##list_terrain
    list_terrain search_term 

The search_term is optional and not quoted; if not supplied, all terrain will be listed.

##list_traits
    list_traits [ --options ] 

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --trait "string": defaults to "".  If specified, then instead of listing all possible traits, this command will show all leaders that have that particular trait.  

List all valid traits (loaded from the XML) that can be used with the 'set_player_data' command, for the current mod.

##list_weights
    list_weights search_term 

The search_term is optional and not quoted; if not supplied, all live weights will be listed.

##load_terrain
    load_terrain "string" 
      param 1: terrain filename

Imports terrain definitions from a config file into terrain objects usable in Weight tables. Please see def/base_terrain.cfg for an example terrain definition file, and its extension def/base_terrain.civ4mc. Most likely, you won't ever have to use this unless you're working on a new mod as all terrain should be loaded which this tool starts up.

##load_xml_data
    load_xml_data 

Loads leader, civ, color, and tech data from the xml files. Set paths in def/config.xml to change the locations of the xml files read, and use the 'list_civs', 'list_leaders', 'list_colors', 'list_techs', 'set_player_data' commands to browse/manipulate the read data.

##ls
    ls "string" 
      param 1: directory path

List directory. Like the unix command, except there's no corresponding 'cd'. Sorry.

##mask_difference
    mask_difference @maskname @maskname [ --options ] => @maskname 
      param 1: mask A
      param 2: mask B

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --offsetX int: defaults to 0.  The X-offset of Mask B compared to A, i.e. Mask B is moved this many columns before the operation.  
    --offsetY int: defaults to 0.  Y-offset of Mask B compared to A, i.e. Mask B is moved this many rows before the operation.  

Finds the difference between two masks; if mask A has value '1' at coordinate X,Y while mask B has value '0' at the same coordinate (after applying the offset), then the result will have value '1', and otherwise '0'. For masks with decimal values, the result is max(0, A-B).

##mask_eval1
    mask_eval1 @maskname "string" => @maskname 
      param 1: mask
      param 2: code to evaluate

Applies an arbitrary function of perl code to the value of each individual cell of the mask. The mask value is available, as $a, while he current x,y coordinate is available as $x and $y.

##mask_eval2
    mask_eval2 @maskname @maskname "string" [ --options ] => @maskname 
      param 1: mask A
      param 2: mask B
      param 3: code to evaluate

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --offsetX int: defaults to 0.  The x-offset of Mask B compared to A, i.e. Mask B is moved this many columns before the operation.  
    --offsetY int: defaults to 0.  y-offset of Mask B compared to A, i.e. Mask B is moved this many rows before the operation.  

Applies an arbitrary function of perl code to the values of each individual pair of coordinates from masks A and B. A's cells can be referred to as $a, while B's are $b. The current x,y coordinate is available as $x and $y.

##mask_intersect
    mask_intersect @maskname @maskname [ --options ] => @maskname 
      param 1: mask A
      param 2: mask B

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --offsetX int: defaults to 0.  The X-offset of Mask B compared to A, i.e. Mask B is moved this many columns before the operation.  
    --offsetY int: defaults to 0.  Y-offset of Mask B compared to A, i.e. Mask B is moved this many rows before the operation.  

Finds the intersection between two masks; if mask A has value '1' at coordinate X,Y and mask B has value '1', the result will have value '1'; otherwise, if either value is '0', then the result will also be '0'. For masks with decimal values, the result is A*B.

##mask_invert
    mask_invert @maskname => @maskname 
      param 1: mask

Inverts a mask; that is, '1's become '0's and vice versa. For masks with decimal values, then the result is 1-value.

##mask_threshold
    mask_threshold @maskname float => @maskname 
      param 1: input mask
      param 2: threshold level

Swings cell values to either a '1' or a '0' depending on the threshold value, which is the second parameter to this command. Mask cells below this value become a '0', and values above or equal become a '1'.

##mask_union
    mask_union @maskname @maskname [ --options ] => @maskname 
      param 1: mask A
      param 2: mask B

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --offsetX int: defaults to 0.  The X-offset of Mask B compared to A, i.e. Mask B is moved this many columns before the operation.  
    --offsetY int: defaults to 0.  Y-offset of Mask B compared to A, i.e. Mask B is moved this many rows before the operation.  

Finds the union between two masks; if mask A has value '1' at coordinate X,Y while mask B has value '0' at the same coordinate (after applying the offset), then the result will have value '0', and otherwise '0'. For masks with decimal values, the result is min(1, A+B).

##merge_two_layers
    merge_two_layers $groupname.layername $groupname.layername 
      param 1: top layer
      param 2: bottom layer

Merges two layers based on their order when calling this command, rather than based on priority in the group (like with the 'flatten_group' command). The first layer wll be considered on top and be the remaining layer after flattening, while the second layer is considered the "background." Both layers must be members of the same group.

##modify_layer_with_mask
    modify_layer_with_mask $groupname.layername @maskname %weightname [ --options ] => $groupname.layername 
      param 1: layer to modify
      param 2: mask to generate from
      param 3: weight table to generate terrain from

    Specifying a result for this command is optional; if not specified, the original layer will be overwritten.

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 8 possible optional parameters:
     
    --check_bonus: optional; defaults to false.  If set, the tile needs to have the same BonusType presense/absense and value to successfully match in the weight table.  
    --check_feature: optional; defaults to false.  If set, the tile needs to have the same FeatureType presense/absense and value to successfully match in the weight table. FeatureVariety is ignored unless 
    --check_variety is specified.  
    --check_height: optional; defaults to false.  If set, the tile needs to have the same PlotType to successfully match in the weight table.  
    --check_type: optional; defaults to false.  If set, the tile needs to have the same TerrainType to successfully match in the weight table.  
    --check_variety: optional; defaults to false.  If set, the tile needs to have the same FeatureVariety presense/absense and value to successfully match in the weight table.  
    --clear_all_matched: optional; defaults to false.  If set, clears any matched tile regardless of what terrain the weight table matches.  
    --offsetX int: defaults to 0.  The X-offset of the mask compared to the layer tile at 0,0, i.e. the mask is moved this many columns before the tile modification occurs.  
    --offsetY int: defaults to 0.  The Y-offset of the mask compared to the layer tile at 0,0, i.e. the mask is moved this many rows before the tile modification occurs.  

Modifies a layer by applying a weight table to a mask. The value at each mask coordinate is evaluated according to the weight, which is used to *modify* the existing tile. Only terrain attributes specified with flags will be checked, e.g. if '--check_bonus' and '--check_feature' are checked, height and terrain type of the tiles will be untouched regardless of what the weight specifies.

##move_layer_by
    move_layer_by $groupname.layername int int 
      param 1: layer to move
      param 2: move by this amount in the x direction
      param 3: move by this amount in the y direction

The specified layer is moved by offsetX, offsetY within its group, referenced from the lower-right corner of the layer.

##move_layer_to_location
    move_layer_to_location $groupname.layername int int 
      param 1: layer to move
      param 2: layer's 0,0 will be moved to this x coordinate within its group
      param 3: layer's 0,0 will be moved to this y coordinate within its group

The specified layer is moved to location x,y within its group, referenced from the lower-right corner of the layer.

##new_group
    new_group int int => $groupname 
      param 1: width
      param 2: height

Create a new group with a blank canvas with a size of width/height. The game settings and wrap properties for this group will be set when any layer is first added to it.

##new_mask_from_filtered_tiles
    new_mask_from_filtered_tiles $groupname.layername %weightname [ --options ] => @maskname 
      param 1: the layer to find tiles in
      param 2: the weight to filter the layer with

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --exact_match: optional; defaults to false.  Require exact matches from tiles to terrains.  
    --post_match_threshold int: defaults to 0.  If the weight matched but evaluates to 0, it will instead be boosted to this value to differentiate it from non-matches.  

Creates a mask by applying a weight to every single tile of a layer, i.e. a full scan. Matches by default are not exact; e.g. a 'bare_hill' would match both a grassland hill or a plains hill.

##new_mask_from_landmass
    new_mask_from_landmass $groupname.layername int int [ --options ] => @maskname 
      param 1: the layer to generate a mask from
      param 2: x coordinate of starting tile
      param 3: y coordinate of starting tile

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 3 possible optional parameters:
     
    --choose_coast: optional; defaults to false.  If set, the mask will select all water tiles adjacent to the landmass (i.e. its coast) instead of the actual landmass itself.  
    --include_coast: optional; defaults to false.  If set, both the landmass AND its coast will be selected.  
    --include_ocean_resources: optional; defaults to false.  If set along with either --choose_coast or --include_coast, then all ocean tiles that are both containing a resource and are adjacent to a coast tile that is adjacent to this landmass will be selected.  

Generate a mask based on a landmass. Sort of like a selection command. The starting tile must be a land tile; otherwise an error will be thrown.

##new_mask_from_magic_wand
    new_mask_from_magic_wand $groupname.layername %weightname int int [ --options ] --shape_param1 value1 --shape_param2 value2 => @maskname 
      param 1: layer to select from
      param 2: inverse weight to match to tiles
      param 3: start coordinate X
      param 4: start coordinate Y

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --exact_match: optional; defaults to false.  Require exact matches from tiles to terrains.  
    --post_match_threshold int: defaults to 0.  If the weight matched but evaluates to 0, it will instead be boosted to this value to differentiate it from non-matches.  

Creates a mask by applying a weight to a region, starting with a single tile. If this tile matches to a result greater than 0, then the tiles surrounding it will be tested, and so on, until the weight stops matching tiles or it runs out of tiles to match. (This command similar in concept to the "magic wand" selection tool in Photopshop). Matches by default are not exact; e.g. a 'bare_hill' would match both a grassland hill or a plains hill with a forest and a fur on it.

##new_mask_from_polygon
    new_mask_from_polygon int int "string" => @maskname 
      param 1: width
      param 2: height
      param 3+: coordinate, in the form "x,y"NOTE: this last parameter is expected to be a list of many. 

The 'new_mask_from_shape' command generates a mask by applying a shape function to a blank canvas of size width/height. The polygon must be a closed, simple (non-internally intersecting) shape, or else an error will be thrown.

##new_mask_from_shape
    new_mask_from_shape *shapename int int --shape_param1 value1 --shape_param2 value2 => @maskname 
      param 1: shape to generate mask with
      param 2: width
      param 3: height

Generates a mask by applying a shape function to a blank canvas of size width/height.

##new_mask_from_water
    new_mask_from_water $groupname.layername int int [ --options ] => @maskname 
      param 1: the layer to generate a mask from
      param 2: x coordinate of starting tile
      param 3: y coordinate of starting tile

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --choose_land: optional; defaults to false.  If set, only land tiles adjacent to this body of water will be selected. Cannot be used with 
    --include_coast.  
    --only_coast: optional; defaults to false.  If set, the mask will only select tiles adjacent to any land tile. (i.e. the coast). Cannot be used with --choose_land.  

Generate a mask based on a body of water. The starting tile must be a water tile; otherwise an error will be thrown.

##new_weight_table
    new_weight_table >= float => result, [>= float => result,] => %weightname 

Creates a new weight table, inline. This is usuable from the command line but it is more likely you'll use it from a script. For very complex weight tables, please see the 'import_weight_table_from_file' command.

##normalize_starts
    normalize_starts $groupname 
      param 1: group to normalize

Reorganizes a group's settlers so that each one is tied to a unique start, useful if, say, you mirror a common BFC design for every player. This command modifies the group. Note that this is always done automatically anyways when a group is exported.

##rename_layer
    rename_layer $groupname.layername "string" 
      param 1: the layer to rename
      param 2: the short name of the layer; no "$" or group name needed

Renames a layer, if you don't want to use copy_layer_from_group + delete_layer.

##return
    return <result> 

Returns a result from a script to be assigned to some other object. The  return type may be any type of group/layer/mask/weight, but not shape. If this result is ignored, a warning will be produced.

##rotate_layer
    rotate_layer $groupname.layername float [ --options ] => $groupname.layername 
      param 1: the layer to rotate
      param 2: the angle of rotation, in degrees

    Specifying a result for this command is optional; if not specified, the original layer will be overwritten.

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --autocrop: optional; defaults to false.  Rather than massively expanding/moving the layer to fit the actual tile rotation (e.g. both width and height would be doubled for a rotation of 180 degrees), that step is skipped. Dead space, including water, is trimmed away from the edges of the object.  
    --iterations int: defaults to 1.  Set to a higher value to rotate the object in this many small steps, which may give a different-looking result.  

This function rotate a layer around the origin point. Rotations of exacty 90/180/270 degrees will be exact, but rotations of arbitrary degrees will not be. There's two reasons for this. The first is because we'll have quantization error due to having a grid of tiles and only being able to move tiles by whole units. The second is because it is impossible to change the orientation of the tiles themselves. For example, lets say you have a wooden chess board in front of you, and you rotated it 30 degrees. Look at the checkboard: each individual square is also rotated by 30 degrees. However, we can't do that here; all tiles are always perfect squares, perpendicular to the X and Y axis. This command tries its very best to rotate a layer according to any angle and will report the actual rotation angle if it fails to get an exact match. 

If the rotation result is poor, you can try specifying '--iteration' to be a value greater than 1. In this case, the algorithm will attempt to rotate a pattern in small steps; e.g. if the rotation angle=39 and iterations=3, we'll do 3 rotations of 13 degrees. Rotating in small steps will give more accurate output angle but maybe jumble the result a bit more; again, some error is unavoidable due to the discrete nature of the problem. 

rotate_layer will scale the canvas and move the layer as appropriately so that the result will be an exact rotation once the layer's group is flattened. However, this will add a lot of empty space. You can stop this by using the '--autocrop' option. This can be useful if, for example, you want to just to crop the rotated result afterwards anyways.

##rotate_mask
    rotate_mask @maskname float [ --options ] => @maskname 
      param 1: the mask to rotate
      param 2: the angle of rotation, in degrees

    Specifying a result for this command is optional; if not specified, the original mask will be overwritten.

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --iterations int: defaults to 1.  Set to a higher value to rotate the object in this many small steps, which may give a different-looking result.  

Rotates a mask around its origin. See the rotate_layer command for a full description of rotation weirdness.

##run_script
    run_script "string" [ --debug_result ] => optional_result_name 
      param 1: filename of script to run

Loads a script and runs the commands within. A result to this command may be specified; if so, then the 'return' command may be used in the script to return a result. The result may be any type (group/layer/mask/weight) but must match the type returned by the script. If '--debug_result' is specified, the return value will be sent to the html view as if you used debug_group, debug_mask, etc.

##set_difficulty
    set_difficulty "string" 
      param 1: difficulty name

Sets difficulty level for all players of all civs. Acceptable values are: "HANDICAP_SETTLER", "HANDICAP_CHIEFTAIN", "HANDICAP_WARLORD", "HANDICAP_NOBLE", "HANDICAP_PRINCE", "HANDICAP_MONARCH", "HANDICAP_EMPEROR", "HANDICAP_IMMORTAL", and "HANDICAP_DEITY"

##set_layer_priority
    set_layer_priority $groupname.layername int 
      param 1: layer to set
      param 2: priority

The specified layer's priority is set to the specified value; the higher the number, the higher the priority. Higher priority layers are considered "above" those with lower priorities. When priority is set, the number will be adjusted so that there are no "gaps" in the priority list, and layers with equal or lower priority will be moved down.

##set_mask_coord
    set_mask_coord @maskname int int float 
      param 1: the mask to modify
      param 2: x coordinate
      param 3: y coordinate
      param 4: value to set

Sets a mask's value at a specific coordinate to a specific value.

##set_mod
    set_mod "string" 
      param 1: mod name

Sets the current mod, and thus a.) reloads all xml data, b.) clears and reloads all terrain definitions, and c.) set the maximum number of players recognized by the savefile. All existing groups in memory will be converted to assume this mod's format and any newly created/imported groups will be automatically converted as well, although keep in mind converting a group from a high number of players (e.g. an RtR mod save) to a low number (e.g. if the current mod is "none") and then back again (e.g. using set_mod "RtR 2.0.7.4" after the save is already imported) will end up clearing those players that couldn't fit in the low number.

##set_output_dir
    set_output_dir "string" 
      param 1: directory path

Sets the default output directory for other commands, e.g. export_sims.

##set_player_data
    set_player_data $groupname int [ --options ] 
      param 1: group with player to set
      param 2: the player number whose data to set

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 4 possible optional parameters:
     
    --civ "string": defaults to "".  Setting set (see 'list_civs' for possible values), will load all values for that civ, including a default leader, leader name, color, and techs.  
    --color "string": defaults to "".  If set (see 'list_colors' for possible values), will override the default color value from '--civ'  
    --leader "string": defaults to "".  If set (see 'list_leaders' for possible values), will override the default leader value from '--civ' If '--leader' is set but '--civ' is not, the matching restricted civ for that leader will be used.  
    --player_name "string": defaults to "".  If set (see 'http://pr0nname.com/' for possible values), the default name of a player's leader is overwritten.  

Sets a particular player's data. You can pick and choose from any or all four options (civ/leader/color/player_name), although a map will not be playable unless civ is set either with this command or from importing an already-built map.

##set_settings
    set_settings $groupname [ --options ] 
      param 1: group whose settings to set

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 3 possible optional parameters:
     
    --era "string": defaults to "".  Sets the game's starting tech era. Possible values are: ancient, classical, medieval, renaissance, industrial, modern, and future.  
    --size "string": defaults to "".  Sets the game's world size. Possible values are: duel, tiny, small, standard, large, and huge.  
    --speed "string": defaults to "".  Sets the game speed. Possible values are: quick, normal, epic, and marathon.  

Sets settings data for a group and all of its layers. Options that aren't set will be ignored.

##set_tile
    set_tile $groupname.layername int int terrainname 
      param 1: the layer to modify
      param 2: x coordinate
      param 3: y coordinate
      param 4: terrain name to set

Sets a specific coordinate in a layer to a specific terrain value.

##set_wrap
    set_wrap $groupname [ --options ] 
      param 1: group to set

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 2 possible optional parameters:
     
    --nowrapX: optional; defaults to false.  If set, the group and all its layers will be set not to wrap in the X direction. If missing, the group and all its layers *will* be set to wrap in the X direction.  
    --nowrapY: optional; defaults to false.  If set, the group and all its layers will be set not to wrap in the Y direction. If missing, the group and all its layers *will* be set to wrap in the Y direction.  

Sets wrap properties for a group and all its member layers. By default, all new blank groups wrap in both the X and Y dimensions; use this command in combination with the '--nowrapX' and/or '--nowrapY' flags to turn off wrap in the X and/or Y dimensions, respectively. If one of these flags is missing, the wrap value will default to 'true' for that direction.

##show_difficulty
    show_difficulty 

Shows the current difficulty level, which all players in all layers in all groups will share.

##show_weights
    show_weights %weightname [ --options ] 
      param 1: weight to describe

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --flatten: optional; defaults to false.  Determines whether nested weights are expanded or not.  

Shows the definition for a weight in the console.

##shrink_mask
    shrink_mask @maskname int [ --options ] => @maskname 
      param 1: mask to shrink
      param 2: number of tiles to shrink by

    Specifying a result for this command is optional; if not specified, the original mask will be overwritten.

    Flag parameters (i.e. --thesethings) specify some special/alternate behaivor of the command and are always optional. This command has 1 possible optional parameters:
     
    --threshold float: defaults to 0.5.  Set a custom threshold level for the mask before the shrink operation occurs.  

Contracts the mask a certain number of tiles. Only values of '0' are considered by the shrink; thus, before the actual shrink operation occurs, the mask is first thresholded. Use '--threshold' to set a custom threshold.

##strip_all_units
    strip_all_units $groupname 
      param 1: group to strip from

All units are removed from all layers. This command modifies the group.

##strip_all_units_from_layer
    strip_all_units_from_layer $groupname.layername 
      param 1: layer to strip from

All units are removed from the map. This command modifies the layer.

##strip_nonsettlers
    strip_nonsettlers $groupname 
      param 1: group to strip from

All non-settler units are removed from all layers. This command modifies the group.