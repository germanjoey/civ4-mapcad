B: required for beta release (v0.2)
P: required for pre-final release (v0.3)

Big Ticket TODO:

    - P: tests
    - P: code examples directory
    - P: "map_library" directory
        - have both wb files, dump files, and a readme.md with descriptions of each map in that directory

Medium Ticket TODO:
              
    - B: search_helptexts command
        - via Commands.md
    - B: organize module methods
    - N: river tools
        - rivers handled well right now, but need to have at least a "draw_river_along_points" command
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

    - N: add a see_also field to params
    - B: test find_difference again
        - that code is goddamn ancient
    - B: delete_tile option for modify_layer_with_mask? separate command?
    - N: clear_workspace
        - deletes objects
    - N: balance subroutine for determining the strength of a capital move
    