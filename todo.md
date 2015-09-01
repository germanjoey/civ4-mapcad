B: required for beta release (v0.2)
P: required for pre-final release (v0.3)

Big Ticket TODO:

    - P: tests
    - P: code examples directory
    - P: "map_library" directory
        - have both wb files, dump files, and a readme.md with descriptions of each map in that directory
    - P: handle how cities share tiles better, because the current way punishes cities that need shared food
         as their only food. also i think we're double-counting trees still...

Medium Ticket TODO:

    - B: search_helptexts command
        - via Commands.md
    - B: organize module methods
    - N: river tools
        - rivers handled well right now, but need to have at least a "draw_river_along_points" command
    - B: grow_bfc command
        - done, needs testing
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
    
Balance TODO: (all B)
    - write Command
    
SEVEN tutorials (4/7 done):
    - B: basic guide to what a command is
    - B: enhancing your banana / intermediate commands
        - setting leader/civ player names
        - adding seafood
    - B: balance
    
    
Final TODO before beta launch:
    0.) Finish writing tutorials
    1.) Write balance_report command
    2.) test grow_bfc
    3.) Screenshots for tutorials
    4.) new mask from layer commands should return a minimum of 0.01
        - and then revert weights back to a minimum of 0.00
    5.) add note about uploading image folder in debug.html
    6.) Go through help text once more
    7.) Regenerate Command.md
    8.) Upload example .html for each tutorial
 +  9.) Fix starting sim size
   10.) Spruce up index readmes
    
    