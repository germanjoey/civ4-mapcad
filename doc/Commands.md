##add_scouts_to_settlers

Command format:

add_scouts_to_settlers $groupname
  param 1: group to add to  Description:

Wherever a settler is found in any layer, a scout is added on top of it.
This command modifies the group.

##apply_shape_to_mask

Command format:

apply_shape_to_mask @maskname $groupname.layername [ --offsetX 0
--offsetY 0 --copy ] --shape_param1 value1 --shape_param2 value2 =>
$groupname.$layername

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.

  Specifying a result is optional; if not specified, the original
  layer will be overwritten.

##combine_groups

Command format:

combine_groups $groupname $groupname => $groupname
  param 1: group A
  param 2: group B

  Specifying a result is optional; if not specified, the original
  group will be overwritten.  Description:

Merges two groups A and B, into one; all layers in B will be placed under
all layers in A. If a result is not specified, Group A will be overwritten.

##copy_group

Command format:

copy_group $groupname => $groupname
  param 1: group to copy  Description:

Copy one group into another.

##copy_layer_from_group

Command format:

copy_layer_from_group $groupname.layername => $groupname.$layername
  param 1: layer to copy  Description:

Copy a layer from one group to another (or the same) group. If a new name
is not specified, the same name is used.

##crop_group

Command format:

crop_group $groupname int int int int => $groupname
  param 1: group to crop
  param 2: left
  param 3: bottom
  param 4: right
  param 5: top

  Specifying a result is optional; if not specified, the original
  group will be overwritten.  Description:

The group's dimensions are trimmed to left/bottom/right/top, from the
nominal dimensions of 0 / 0 / width-1 / height-1. Any member layers that
exceed these dimensions are cropped as well.

##crop_layer

Command format:

crop_layer $groupname.layername int int int int => $groupname.$layername
  param 1: layer to crop
  param 2: left
  param 3: bottom
  param 4: right
  param 5: top

  Specifying a result is optional; if not specified, the original
  layer will be overwritten.  Description:

This layer's dimensions are trimmed to left/bottom/right/top, from the
nominal dimensions of 0 / 0 / width-1 / height-1.

##cutout_layer_with_mask

Command format:

cutout_layer_with_mask $groupname.layername @maskname [ --offsetY 0
--copy --offsetX 0 ] => $groupname.$layername
  param 1: layer to cutout from
  param 2: mask to define selection

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.

##decrease_layer_priority

Command format:

decrease_layer_priority $groupname.layername
  param 1: layer to set  Description:

Moves a layer 'down' in the visibility stack; see 'set_layer_priority'
for more details.

##delete_layer

Command format:

delete_layer $groupname.layername
  param 1: the layer to delete  Description:

Deletes a layer from a group.

##dump_group

Command format:

dump_group $groupname [ --info_too --add_to_existing ]

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

Displays a group in the dump.html debugging window. Each layer will
appear as its own tab. If 'add_to_existing' is specified, the dump will add
additional tabs to the existing dump.html. If '--info_too' is specified,
all per-layer map information will be specified in a table.

##dump_layer

Command format:

dump_layer $groupname.layername [ --info_too --add_to_existing ]

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

Displays a single layer in the dump.html debugging window. If
'add_to_existing' is specified, the dump will add additional tabs to the
existing dump.html. If '--info_too' is specified, all per-layer map
information will be specified in a table.

##dump_mask

Command format:

dump_mask @maskname [ --add_to_existing ]

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.

##dump_mask_to_console

Command format:

dump_mask_to_console @maskname  Description:

Dump a mask as ascii-art for quick debugging.

##eval

Command format:

eval <code>

Description:
Evaluates perl code and prints the result. Everything on the command line
after the 'eval' keyword will be evaluated.

##evaluate_weight

Command format:

evaluate_weight %weightname float
  param 1: weight
  param 2: value to evaluate  Description:

The 'evaluate_weight' command returns the result of a Weight Table were
it to be evaluated with a floating point value,   as if that value were the
coordinate of a mask. Thus, that value needs to be between 0 and 1.
'evaluate_weight' is only   intended to be a debugging command; please see
the Mask-related commands, e.g. 'generate_layer_from_mask',  
'modify_layer_from_mask', for actually using weights to generate/modify
tiles.

##exit

Command format:

exit

Description:
Exits.

##expand_group_canvas

Command format:

expand_group_canvas $groupname int int
  param 1: group to expand
  param 2: expand width by
  param 3: expand height by  Description:

Expands a group's dimensions.

##expand_layer_canvas

Command format:

expand_layer_canvas $groupname.layername int int
  param 1: layer to expand
  param 2: expand width by
  param 3: expand height by  Description:

Expands a layer's dimensions; attempting to expand the layer to be bigger
than its containing group will cause an error.

##export_group

Command format:

export_group $groupname
  param 1: group to export  Description:

Exports a flat version of the group as a CivBeyondSwordWBSave in addition
to also doing so for each layer seperately.

##export_mask_to_ascii

Command format:

export_mask_to_ascii @maskname "string" [ --mapping_file
"def/standard_ascii.mapping" ]
  param 1: output filename

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

This command generates an ascii rendering of a mask based on a mapping
file. The second parameter is the    output filename. The format of the
mapping file is that there's one character and one	value per line.
Values that don't exactly match will instead use the closest value instead.

##export_mask_to_table

Command format:

export_mask_to_table @maskname "string" [ --mapping_file
"def/standard_ascii.mapping" ]
  param 1: mask to export
  param 2: output filename

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

Exports the mask to a table file; one line per coordinate, first column
x, second column y, third column value.

##export_sims

Command format:

export_sims $groupname [ --delete_existing ]
  param 1: group to extract from

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

The '@bfc_for_sim' mask is applied on each settler, and then that
selected area is extracted as a new layer. The group is then exported ala
the 'export_group' command, with each layer being saved as its own
CivBeyondSwordWBSave. This command does not modify the specified group.

##extract_starts

Command format:

extract_starts $groupname => $groupname
  param 1: group to extract from

  Specifying a result is optional; if not specified, the original
  group will be overwritten.  Description:

The '@bfc_tight' mask is applied on each settler, and then that selected
area is extracted as a new layer. If a result is not specified, this
command modifies the group.

##extract_starts_as_mask

Command format:

extract_starts_as_mask $groupname => @maskname
  param 1: group to extract from  Description:

Return a group of masks highlighting each start... not yet implemented.

##find_difference

Command format:

find_difference $groupname $groupname => $groupname
  param 1: group A
  param 2: group B  Description:

Take positive difference between mapobj a and mapobj b to create a new
mapobj c, such that merging c onto a creates b    ocean means "nothing",
fallout over ocean means actual ocean. Basically, this is useful if you're
creating a map in    pieces and want to do hand-edits in the middle. That
way, you can regenerate the map from scratch while still including	your
hand-edits. This command acts on two flat groups, so merge all layers first
if you need to.

##find_starts

Command format:

find_starts $groupname
  param 1: group to find settlers in  Description:

Finds starts (settlers) in a group and reports their locations.

##flatten_group

Command format:

flatten_group $groupname [ --rename_final_layer ] => $groupname
  param 1: group to flatten

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.

  Specifying a result is optional; if not specified, the original
  group will be overwritten.  Description:

Flattens a group by merging all layers down, starting with the highest
priority. Tiles at the same coordinates in an 'upper' layer will overwrite
ones on a 'lower' layer. Ocean tiles are counted as "transparent" in the
upper layer. If you do not specify a result, the group will be overwritten.
If the '--rename_final' flag is set, the final layer will be renamed to the
same name as the group's name. Use the 'list_layers' command to see layer
priorities.

##flip_layer_lr

Command format:

flip_layer_lr $groupname.layername => $groupname.$layername
  param 1: layer to flip

  Specifying a result is optional; if not specified, the original
  layer will be overwritten.  Description:

Flip a layer horizontally.

##flip_layer_tb

Command format:

flip_layer_tb $groupname.layername => $groupname.$layername
  param 1: layer to flip

  Specifying a result is optional; if not specified, the original
  layer will be overwritten.  Description:

Flip a layer horizontally.

##generate_layer_from_mask

Command format:

generate_layer_from_mask @maskname %weightname [ --offsetY 0 --offsetX 0
] => $groupname.$layername
  param 1: mask to generate from
  param 2: weight table used to translate values into terrain

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

Create a layer by applying a weight table to a mask. The value at each
mask coordinate is evaluated according to the weight table, which is used
to generate a new tile. For example, if the mask's value at coordinate 3,2
is equal to 0.45, and the weight table specifies that values	  between 0.4
and 1 map to an ordinary grassland tile, then the output layer will have a
grassland tile at 3,2.

##help

.

##history

Command format:

history  Description:

Prints a list of all previous commands back to the command line.

##import_group

Command format:

import_group "string" => $groupname
  param 1: filename  Description:

Create a new group by importing an existing worldbuilder file. The new
group will have a single layer with the same name as the result group.

##import_mask_from_ascii

Command format:

import_mask_from_ascii "string" [ --mapping_file
"def/standard_ascii.mapping" ] => @maskname
  param 1: input filename

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

The 'import_mask_from_ascii' command generates a mask by reading in an
ascii art shape and translating the characters    into 1's and zeroes, if,
for examples, you wanted to create a landmass that looked like some kind of
defined shape. By    default, a '*' equals a value of 1.0, while a ' '
equals a 0.0.

##import_mask_from_table

Command format:

import_mask_from_table "string" => @maskname
  param 1: input filename  Description:

Imports a mask from a table file; one line per coordinate, first column
x, second column y, third column value.

##import_shape

Command format:

import_shape "string" => *shapename
  param 1: path  Description:

TODO

##import_weight_table_from_file

Command format:

import_weight_table_from_file "string" => %weightname
  param 1: weight definition filename  Description:

The 'import_weight_table_from_file' command creates a new Weight Table
from a definition described in  a file. In short, it follows a format of
"operator threshold => result". The result can be either be a  terrain or
another already-existing Weight Table, the threshold should be a floating
point number,  and the operator should be either '==' or '>='. See the
'evaluate_weight' command for a description  of how Weights Tables are
evaluated, 'generate_layer_from_mask' for how Weights Tables are used to 
generate actual tiles with Masks, or the 'Masks and Filters' section of the
html documentation for  more information on Weight Tables in general.

##increase_layer_priority

Command format:

increase_layer_priority $groupname.layername
  param 1: layer to set  Description:

Moves a layer 'up' in the visibility stack; see 'set_layer_priority' for
more details.

##list_groups

Command Format: 

  list_groups search_term

The search_term is optional; if not supplied, all groups will be listed.

##list_layers

Command format:

list_layers $groupname  Description:

Lists all layers of a group by priority.

##list_masks

Command Format: 

  list_masks search_term

The search_term is optional; if not supplied, all masks will be listed.

##list_shapes

Command Format: 

  list_shapes search_term

The search_term is optional; if not supplied, all shapes will be listed.

##list_terrain

Command Format: 

  list_terrain search_term

The search_term is optional; if not supplied, all terrain will be listed.

##list_weights

Command Format: 

  list_weights search_term

The search_term is optional; if not supplied, all weights will be listed.

##load_terrain

Command format:

load_terrain "string"
  param 1: terrain filename  Description:

The 'load_terrain' command imports terrain definitions (in the same
format as a CivBeyondSwordWBSave) into    as objects usable in Weight
tables, that can then subsequently be used with Masks to actually create
tiles.    Please see def/base_terrain.cfg for an example terrain definition
file, and the 'import_weight_table_from_file',    'evaluate_weight', and
'generate_layer_from_mask' commands to better understand how terrain works
with Weights and Masks.

##mask_difference

Command format:

mask_difference @maskname @maskname [ --offsetY 0 --offsetX 0 ] =>
@maskname
  param 1: mask A
  param 2: mask B

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

Finds the difference between two masks; if mask A has value '1' at
coordinate X,Y while mask B has value '0' at the same coordinate (after
applying the offset), then the result will have value '1', and otherwise
'0'. For masks with decimal values, then the result is max(0, A-B).
'--offsetX' and '--offsetY' specify how much to move B before the
difference is taken; at any rate, the resulting mask will be stretched to
encompass both A and B, including the offset.

##mask_intersect

Command format:

mask_intersect @maskname @maskname [ --offsetX 0 --offsetY 0 ] =>
@maskname
  param 1: mask A
  param 2: mask B

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

Finds the intersection between two masks; if mask A has value '1' at
coordinate X,Y and mask B has value '1', the result will have value '1';
otherwise, if either value is '0', then the result will also be '0'. For
masks with decimal values, then the result is A*B. offsetX and offsetY
specify how much to move B before the difference is taken, while wrapX and
wrapY determine whether B wraps. '--offsetX' and '--offsetY' specify how
much to move B before the difference is taken; at any rate, the resulting
mask will be stretched to encompass both A and B, including the offset.

##mask_invert

Command format:

mask_invert @maskname => @maskname
  param 1: input mask  Description:

Inverts a mask; that is, '1's become '0's and vice versa. For masks with
decimal values, then the result is 1-value.

##mask_threshold

Command format:

mask_threshold @maskname float => @maskname
  param 1: input mask  Description:

Swings values to either a '1' or a '0' depending on the threshold value,
which is the second parameter to this command. Mask values below this value
become a '0', and values above or equal become a '1'.

##mask_union

Command format:

mask_union @maskname @maskname [ --offsetX 0 --offsetY 0 ] => @maskname
  param 1: mask A
  param 2: mask B

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

Finds the union between two masks; if mask A has value '1' at coordinate
X,Y while mask B has value '0' at the same coordinate (after applying the
offset), then the result will have value '0', and otherwise '0'. For masks
with decimal values, then the result is min(1, A+B). '--offsetX' and
'--offsetY' specify how much to move B before the difference is taken; at
any rate, the resulting mask will be stretched to encompass both A and B,
including the offset.

##merge_two_layers

Command format:

merge_two_layers $groupname.layername $groupname.layername
  param 1: top layer
  param 2: bottom layer  Description:

Merges two layers based on their order when calling this command, rather
than based on priority in the group (like with the 'flatten_group'
command). The first layer wll be considered on top and be the remaining
layer after flattening, while the second layer is considered the
"background." Both layers must be members of the same group.

##modify_layer_with_mask

Command format:

modify_layer_with_mask $groupname.layername @maskname %weightname [
--offsetX 0 --offsetY 0 ] => $groupname.$layername
  param 1: layer to modify
  param 2: mask to generate from
  param 3: weight table to generate terrain from

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.

  Specifying a result is optional; if not specified, the original
  layer will be overwritten.

##move_layer_by

Command format:

move_layer_by $groupname.layername int int
  param 1: layer to move
  param 2: move by this amount in the x direction
  param 3: move by this amount in the y direction  Description:

The specified layer is moved by offsetX, offsetY within its group.

##move_layer_to

Command format:

move_layer_to $groupname.layername int int
  param 1: layer to move
  param 2: layer's 0,0 will be moved to this x coordinate within its group
  param 3: layer's 0,0 will be moved to this y coordinate within its group  Description:

The specified layer is moved to location x,y within its group.

##new_group

Command format:

new_group int int => $groupname
  param 1: width
  param 2: height  Description:

Create a new group with a blank canvas with a size of width/height. The
new group will have a single layer with the same name as the result group.

##new_mask_from_magic_wand

Command format:

new_mask_from_magic_wand $groupname.layername %weightname int int
--shape_param1 value1 --shape_param2 value2 => @maskname
  param 1: layer to select from
  param 2: inverse weight to match to tiles
  param 3: start coordinate X
  param 4: start coordinate Y  Description:

##new_mask_from_shape

Command format:

new_mask_from_shape *shapename int int --shape_param1 value1
--shape_param2 value2 => @maskname
  param 1: shape to generate mask with
  param 2: width
  param 3: height  Description:

The 'new_mask_from_shape' command generates a mask by applying a shape
function to a blank canvas of size width/height.    (the two required
integer paramaters). See the 'Shapes and Masks' section of the html
documentation for more details.

##new_weight_table

Command Format: 

  new_weight_table >= float => result, [>= float => result,] => %weightname

The 'new_weight_table' command creates a new Weight Table on the command
line. It's really only suited for short and simple tables with just a couple
choices.  For anything more complex than that, please see the
'import_weight_table_from_file' command.

##normalize_starts

Command format:

normalize_starts $groupname
  param 1: group to normalize  Description:

Reorganizes a group's settlers so that each one is tied to a unique
start, useful if, say, you mirror a common BFC design for every player.
This command modifies the group.

##rename_layer

Command format:

rename_layer $groupname.layername "string"
  param 1: the layer to rename
  param 2: the short name of the layer; no "$" or group name needed  Description:

Renames a layer, if you don't want to use copy_layer_from_group +
delete_layer.

##return

Command format:

return <result>

Description:
Returns a result from a script to be assigned to some other objec. The 
return type may be any type of group/layer/mask/weight, but not shape. If
this result is ignored, a warning will be produced.

##run_script

Command format:

run_script "string" => optional_result_name
  param 1: filename of script to run

Loads a script and runs the commands within. A result to this command may be
specified; if so, then the 'return' command may be used in the script to
return a result. The result may be any type (group/layer/mask/weight) but must
match the type returned by the script.

##set_layer_priority

Command format:

set_layer_priority $groupname.layername int
  param 1: layer to set
  param 2: priority  Description:

The specified layer's priority is set to the specified value; the higher
the number, the higher the priority. Higher priority layers are considered
"above" those with lower priorities. When priority is set, the number will
be adjusted so that there are no "gaps" in the priority list, and layers
with equal or lower priority will be moved down.

##set_mask_coord

Command format:

set_mask_coord @maskname int int float => @maskname
  param 1: the mask to modify
  param 2: x coordinate
  param 3: y coordinate
  param 4: value to set

  Specifying a result is optional; if not specified, the original
  mask will be overwritten.  Description:

Sets a mask's value at a specific coordinate to a specific value.

##set_mod

Command format:

set_mod "string"
  param 1: mod name  Description:

'set_mod' sets the current mod to set the maximum number of players
recognized by the save. This value can be either "RtR" (which allows a
maximum of 40 players) or "none" (maximum allowed is 18 players). All
existing groups will be converted to this mod and any newly
created/imported groups will be automatically converted as well.

##set_output_dir

Command format:

set_output_dir "string" [ --delete_existing ]
  param 1: directory path

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

'set_output_dir' sets the default output directory for other commands,
e.g. export_sims.

##set_tile

Command format:

set_tile $groupname.layername int int terrainname =>
$groupname.$layername
  param 1: the layer to modify
  param 2: x coordinate
  param 3: y coordinate
  param 4: terrain name to set

  Specifying a result is optional; if not specified, the original
  layer will be overwritten.  Description:

Sets a specific coordinate in a layer to a specific terrain value.

##set_wrap

Command format:

set_wrap $groupname [ --nowrapX --nowrapY ]
  param 1: group to set

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

Sets wrap properties for a group and all its member layers. By default,
all new blank groups wrap in both the X and Y dimensions; use this command
in combination with the '--nowrapX' and/or '--nowrapY' flags to turn off
wrap in the X and/or Y dimensions, respectively. If one of these flags is
missing, the wrap value will default to 'true' for that direction.

##show_weights

Command format:

show_weights %weightname [ --flatten ]

  Flag arguments (e.g. --thesethings) are always optional. The
  value after the flag is the default value; flags without a 
  value are considered true/false, and default to false.  Description:

Shows the definition for a weight. The optional 'flatten' arguments
determines whether nested weights are expanded or not. (off by default)

##strip_nonsettlers

Command format:

strip_nonsettlers $groupname
  param 1: group to strip from  Description:

All non-settler units are removed from all layers. If a result is not
specified, this command modifies the group.