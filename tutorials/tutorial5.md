## The More You Know

(UNFINISHED) Rather than a full step-by-step tutorial, here I'll show you some examples of other useful commands.

example 1

    set_player_data $banana_bunch 0 --player_name "Banana Bob" --leader "Montezuma" --civ "Inca"

example 2
    
    mask_from_landmass $banana_bunch.banana_bunch 2 3 --choose_coast => @coast 
    new_weight_table >= 0.96 => coast_clam,
                     >= 0.92 => coast_crab,
                     >= 0.88 => coast_fish
                     >= 0.00 => coast
                     => %coastfood
    generate_layer_from_mask @coast %coastfood --offsetX -1 --offsetY -2 => $banana_bunch.seafood
    
example 3
    
    mask_from_landmass $the_real_banana.bfc 4 6 --include_coast => @island
    grow_mask @island1 1 => @island_plus1
    mask_difference @island_plus1 @island => @island_border
    new_weight_table >= 0.96 => ocean_fish
                     >= 0.00 => ocean
                     => %oceanfood
    generate_layer_from_mask @island_border %oceanfood --offsetX 2 --offsetY 2 => $the_real_banana.oceanfish
    
example 4
    
    mask_from_landmass $the_real_banana.bfc 4 6 => @island1_only
    cutout_layer_with_mask $banana_bunch.banana_bunch @island1_only => $banana_bunch.island1
    increase_priority $banana_bunch.island1
    rotate_layer $banana_bunch.island1 10
    flatten_group $banana_bunch --rename_final_layer