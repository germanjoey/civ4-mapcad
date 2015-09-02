loaded_ok = 1;

var alloc_found = 0;
var alloc_visibility = 1;
function toggleAllocVis () {
    for (var i=0; i < 39; i++) {
        var c = $('.c' + i);
        if (c.length == 0) {
            break;
        }
        
        if (alloc_visibility == 1) {
            c.each(function (index) { $(this).css('visibility', 'hidden') });
        }
        else {
            c.each(function (index) { $(this).css('visibility', 'visible') });
        }
    }
    
    alloc_visibility = (alloc_visibility == 1) ? 0 : 1;
}
        
// we use abbreviated names to try to reduce the file size a bit, since this shit is spammed everywhere
// makes a big difference in the output file size, believe it or not
var show_tiles = {
    '0' : {
        'hl' : 1, // hill
        'jl' : 1, // forest
        'ft' : 1  // jungle
    }
};

function toggle_resources (checkbox, type) {
    var parent_tab = $(checkbox).parents('.map_tab').first();
    
    if(checkbox.checked) {
        $('.' + type, $(parent_tab)).removeClass('transpar');
    }
    else {
        $('.' + type, $(parent_tab)).addClass('transpar');
    }
}

function toggle_hills (checkbox) {
    var parent_tab = $(checkbox).parents('.map_tab').first();
    var tabID = $("#tabs").tabs("option", "active");
    
    var types = ['ft', 'jl'];
    if(checkbox.checked) {
        show_tiles[tabID]['hl'] = 1;
        
        for (var i=0; i<2; i++) {
            var t = types[i];
            if (show_tiles[tabID][t]) {
                var sel = $('.' + t + 'hl_n_hl', $(parent_tab));
                sel.removeClass(t + 'hl_n_hl');
                sel.addClass(t + 'hl');
            }
            else {
                var sel = $('.' + t + 'hl_b', $(parent_tab));
                sel.removeClass(t + 'hl_b');
                sel.addClass(t + 'hl_n_' + t);
            }
        }
        
        var sel = $('.hl_b', $(parent_tab));
        sel.removeClass('hl_b');
        sel.addClass('hl');
    }
    else {
        show_tiles[tabID]['hl'] = 0;
    
        for (var i=0; i<2; i++) {
            var t = types[i];
            if (show_tiles[tabID][t]) {
                var sel = $('.' + t + 'hl', $(parent_tab));
                sel.removeClass(t + 'hl');
                sel.addClass(t + 'hl_n_hl');
            }
            else {
                var sel = $('.' + t + 'hl_n_' + t, $(parent_tab));
                sel.removeClass(t + 'hl_n_' + t);
                sel.addClass(t + 'hl_b');
            }
        }
        
        var sel = $('.hl', $(parent_tab));
        sel.removeClass('hl');
        sel.addClass('hl_b');
    }
}

function toggle_trees (checkbox, t) {
    var parent_tab = $(checkbox).parents('.map_tab').first();
    var tabID = $("#tabs").tabs("option", "active");
    
    if(checkbox.checked) {
        show_tiles[tabID][t] = 1;
        
        if (show_tiles[tabID]['hl']) {
            var sel = $('.' + t + 'hl_n_' + t, $(parent_tab));
            sel.removeClass(t + 'hl_n_' + t);
            sel.addClass(t + 'hl');
        }
        else {
            var sel = $('.' + t + 'hl_b', $(parent_tab));
            sel.removeClass(t + 'hl_b');
            sel.addClass(t + 'hl_n_hl');
        }
        
        var sel = $('.' + t + '_bare', $(parent_tab));
        sel.removeClass(t + '_bare');
        sel.addClass(t);
    }
    else {
        show_tiles[tabID][t] = 0;
    
        if (show_tiles[tabID]['hl']) {
            var sel = $('.' + t + 'hl', $(parent_tab));
            sel.removeClass(t + 'hl');
            sel.addClass(t + 'hl_n_' + t);
        }
        else {
            var sel = $('.' + t + 'hl_n_hl', $(parent_tab));
            sel.removeClass(t + 'hl_n_hl');
            sel.addClass(t + 'hl_b');
        }
    
        var sel = $('.' + t, $(parent_tab));
        sel.removeClass(t);
        sel.addClass(t + '_bare');
    }
}