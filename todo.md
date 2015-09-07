B: required for beta release (v0.2)
P: required for pre-final release (v0.3)

Big Ticket TODO:

    - P: tests
    - P: code examples directory
    - P: "map_library" directory
        - have both wb files, dump files, and a readme.md with descriptions of each map in that directory

Medium Ticket TODO:

    - P: handle how cities share tiles better, because the current way punishes cities that need shared food
         as their only food. also i think we're double-counting trees still...
            - this may not as difficult as I thought; we just need to keep a list of blocked tiles per-city,
              and then recompute choose_tiles and the growth targets whenever a new city is added or expands
              borders. we already return an expanded-borders event so thats already there, and then the
              choose_tiles just needs to ignore the blocked tiles. finally, in the algorithm that chooses which
              tiles are blocked, we just: a.) try to balance food tiles (give to those in need), b.) weight
              how other tiles are split based on the settling turn and the size of the safe zone (to detect
              "fillers")
            - as for trees, cities should keep full count of their trees and then when trees are shared we
              should subract from one and give to the other
              
    - B: search_helptexts command
        - via Commands.md
    - B: organize module methods
    - N: river tools
        - rivers handled well right now, but need to have at least a "draw_river_along_points" command
    - B: grow_bfc command
        - done, needs testing
    - B: bonus to cities grabbing *NEW* food in strat adjust
    - N: allow rotations from arbitrary origin points
        - just move the layer before/after
        - we might want to redo the rotation algorithm, based on the idea of recomputing the horizontal rotation pattern for  
          each step
    - N: check_map command
        - checks to make sure each active civ has 2 techs
        - checks for floodplains/oasis on non desert/ice tiles and for river adjacency
        - checks for jungles on peaks (resources too i guess)
        - fixes river direction
        - clears rivers from coast edge
        
Small Ticket TODO:

    - B: add note about uploading image folder in debug.html
    - N: add a see_also field to params
    - B: test find_difference again
        - that code is goddamn ancient
    - B: delete_tile option for modify_layer_with_mask? separate command?
    - N: clear_workspace
        - deletes objects
    - N: balance subroutine for determining the strength of a capital move
    - B: new mask from layer commands should return a minimum of 0.01
    