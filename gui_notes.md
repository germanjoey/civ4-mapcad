A full editor gui shouldn't be too hard to make on top of the existing architecture because the map manipulation is already command-driven.

    - This needs to wait until *AFTER* version 1 release
    
    - Main document
        - outgoing commands are sent via a single function
            - very simple protocal; only a single string is sent
            - stuff from the command-line widget can be sent exactly
            - stuff from the toolbox widgets can be formed into a command
                - the widgets should have their own special commands probably
        - installs a listener event that either refreshes the map-display frame or dumps text to the command-line frame
            - ideally, instead of refreshing the whole map display frame, we receive json that describes the new map and then only a particular tab gets updated.
                - this is probably hell of a lot more work
            - websocket server can be implemented with something like this:
                - http://mojolicio.us/
        - i have a really good keypress dispatcher that i wrote for another project; it would be installed here
            - it's really nice because it will bind a particular function only when a key is pressed when a particular dom element is active. it makes things super simple even if e.g. you have many of the same type of element on the page (e.g. toolboxes), the keypress function don't need to know about the other ones.
    
    - Command-line interface
        - is implemented w/ my websocket chat widget
        - commands get relayed up to the parent document, which handles the socket-io
        - whenever a command that updates anything currently on display executes, the page is refreshed
            - the debug_* commands should track what is being dumped
            - there needs to be a "remove_from_debug" command, activated when the display tab is x-ed out
            - currently tracked dumps get refreshed when set_variable sets them to something new
    
    - Map display
        - each tab contains and iframe
        - Essentially the same as debug.html now, except now also has some toolboxes on each tab and the tabs can be loaded individually.
            - iirc jquery-ui tabs can be loaded through ajax... look into that
        - Commands from clicking on buttons or whatever get relayed up to the parent document, which relays the command to the server
        - **Each tab will have its own seperate gui instantiation**
            - three different guis:
                - Group
                    - info box allows resizing (invokes expand/crop command) but NOT changing map settings
                    - layer box allows hiding layers and increasing/decreasing layer priority by dragging (using a jquery-ui sortable)
                    - map display gets a toolbox to its left
                        - toolbox can do the stuff in the worldbuilder map tab, e.g. editing tiles, setting improvements, etc. one change at a time.
                    - layers will be displayed on top of the map
                        - should have a different color border for each layer
                        - can be dragged via the thick border to move (using jquery-ui draggable and hooking the on-stop event)
                        - fresh water should be displayed, but salt-water should be hidden except on the bottom layer
                        - only top-displayed tile is hidden
                - Layer
                    - info box allows changing map settings but NOT resizing
                        - single tiles can still be added one at a time
                        - static text becomes dropdowns, bound with an onchange, that executes a set_layer_info command or something like that
                    - map display gets a toolbox to its left
                        - toolbox can do the stuff in the worldbuilder map tab, e.g. editing tiles, setting improvements, etc. one change at a time.
                        - same as the one in the group-view
                - Mask
                    - clicking a mask coordinate brings up a text box, which has an onSubmit event that executes a change_mask_coordinate command

    - Toolbox
        - Instances nested to the left of a group or layer view
        - Edits made with these buttons should not need to refresh the page
            - the edit should change the display to mirror what the command would do
            - the actual command gets relayed to the parent document in parallel, which sends the command to change the tile via websocket
            
        - similar to the "map" section of worldbuilder
            - box for improvements
                - maybe not, at least for the first version
            - box for terrain and features
            - box for bonuses
            
        - clicking a button for a thing (improvement/terrain/feature/bonus) makes that thing active
            - once a thing is active, clicking on tiles will trigger an onclick event registered on the tile
            - clicking on another button makes another thing active, or clicking on the original button again deactivates the button