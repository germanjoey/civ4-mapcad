

Ah, after relaxing with a quiet evening spent playing your pitboss turns, you settle into bed with expectations of blissful dreams. The drama and tension of the game... it all begins to fades away. You stir and suddenly flames erupt in a ring around your room  and a gaunt, disheveled man with eyes of coal materializes before you. Materializes? Huh? Or was he always there? What??? Is this hell, you ask him. Oh, perhaps, perhaps, he smirks with a low growl. At least, it is if these guys have anything to do with it. Out of your closest pop five men in raggeddy banana suits... and they start to dance. It's the original members of [TEAM BANANA](http://www.garath.net/Sullla/Civ4/ADG12.html) from the infamous Apolyton Demogame... and they want YOU to make a map for their reunion game!!




The first thing we'll need to do is make our banana. We could just draw this out in the worldbuilder and import it, similar to what we did in the last tutorial, but instead let's try creating one using Civ4 MC's special terrain generation tools: Masks, Weights, and Shapes.

Before we continue, let me explain what these things are and what they do. The first, Masks, are kind of like a stencil that sits on top of the map. The mask is essentially a 2d plane, just like a map, and can be of any size. Instead of tiles, a mask is made up of values between "1" and "0". Thinking about the most simple case, where values are *only* 1 and 0, a Mask is like a cookie cutter. The cookie dough is the background, and the shape of the cutter itself (if it were solid inside) would be a bunch of 1's.

![tutorial1-img1](t2/i1.jpg)

If we think of it like ascii art, it might look like this, where the '*' have a value of 1.0 and the blank spaces have a value of 0.0:

             ***     
            *****    
             ***     
         *********** 
          *********  
            *****    
           *******   
          **** ****  
         ****   ****  

Civ4 MC has a way to turn ascii art like this directly into a mask object... we just need to put it into a file and then load it with the 'import_mask_from_ascii' command. Unfortunately, a gingerbread man won't help us make a banana... we need something else. Now, we could just make a big banana ascii art (an image-to-ascii service (e.g. [http://www.text-image.com/convert/](http://www.text-image.com/convert/)) and the "cleanup_ascii" commands might help here) but instead we're going to do things in a little bit more fancy of a way to show off some other Civ4 MC commands.

First, let's import a circle ascii art

    
         
So, with Masks we have a way to describe a shape. How do we then turn that into terrain? Enter Weight tables. Weight tables are kind of like paintbuckets for the inside of the cookiecutter. The fill specific value-ranges with a type of tile. For example, a very simple Weight might look like this:

    > list_weights land
    
    %any_land
    %land
    %landfood
    %landoil
    
    > show_weights %land
    
    >= 1.00 => grass,
    >= 0.00 >= ocean
    

Next, let's try the fancy way. Try entering the following on the command line:

    > new_mask_from_shape *circle 17 17 --centerX 8 --centerY 8 --radius 7 => @seed
    
"new_mask_from_shape" is the command name, "*circle* is the shape (one of the defaults - you can see others with the "list_shapes" command, and notice all shapes have a "*" prefix), 17 x 17 is the size of the mask, while the --centerX, --centerY, and ---radius options are parameters of the shape itself. Finally, the result is stored in @seed. You can look at it with the "dump_mask" command:

    > dump_mask @seed
    
Load up dump.html and take a look. As you can see, we have

- mention min and max for random