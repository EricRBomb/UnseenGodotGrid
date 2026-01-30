# UnseenGodotGrid

Addon for Godot that creates a new main window copies basic functionalities of scene editor but is accessible via screen reader and keyboard controls. 

It allows moving, copying, and selecting items in a scene and is attached to the inspector, so selecting an instance in a scene pulls up that instances inspector.

Install:

Copy the folder to your addons folder, then go to project, project settings, plugins, and enable "Unseen Grid Editor"


Keyboard commands:

You can edit the variables at the top of grid_editor_plugin.gd and grid_panel.gd to change these.

CTRL+5 gets you to the cell sizer at the top of the grid. By default its 16, meaning each cell will represent 16x16 pixels in game.

If you want more fine control, make it smaller, if you want less fine control like big walls and spaced out enemies, make it bigger.

Space- selects the node in the cell you are viewing, making it be selected in the tree and loading it in inspector.

You have to hold CTLR+ these keys to do the following:

var open_grid := KEY_F2 - opens the unseen grid. Does not work alongside GMAP editor or if 3D editor is active

var jump_focused := KEY_U - if you have a node focused in scene editor, this takes you to it if you have the grid open

var copy_key = KEY_C - Saves the grid cell you are on to paste the contents of that grid cell elsewhere.

var cut_key = KEY_X - moves contents of a grid cell to another cell if you cut then paste it elsewhere

var paste_key = KEY_V if you have a grid cell copied or cut, pastes it.
