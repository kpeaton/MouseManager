%% |MouseManager| demo
% The |MouseManager| class provides a general-purpose, easy-to-use
% interface for managing mouse-based interactions with objects in a figure.
% A |MouseManager| object is associated with a figure window and helps
% handle any mouse-driven interactions (such as clicking, hovering, and
% scrolling) with multiple graphics objects within the figure, particularly
% axes objects and their children. Below are four examples of how
% |MouseManager| can be used to easily add mouse-based interaction to your
% GUIs.
%%

%% Panning/Zooming/Resetting an axes
% The code for this demo is included below and can be found in the file
% |panning_demo.m|. After running the code, an image will be displayed in a
% figure window. You can left click and drag to pan, scroll to zoom in and
% out, and double-click to reset to the default view:
% 
% <include>panning_demo.m</include>

%%
% First, the code loads an image and displays it in a figure window. A
% |MouseManager| object |mmObject| is then created and associated with the
% figure window. The axes object is added as a managed item using the
% |add_item| method and 3 callback functions (in this case nested
% functions) are added:
%
% * |pan_image|, which handles panning of the image, is associated with
% 'normal' (i.e. left) mouse button operations (clicking, dragging, etc.)
% involving the axes object.
% * |zoom_image|, which handles zooming in and out on the image, is
% associated with 'scroll' operations made over the axes object.
% * |reset_image|, which returns the image to its default display, is
% associated with 'click' operations made over the axes, specifically
% 'open' (i.e. double-click) selections made with any mouse button.
%
% Finally, a call to the |enable| method is made to enable |mmObject|,
% which starts in the default 'off' state. This activates all of the above
% mouse-based interactions.

%%
% *The |pan_image| function*
%
% Looking at the |pan_image| function, we can see that it uses the
% |eventData| structure that is automatically passed to it by the
% |MouseManager| object. Since |pan_image| handles all operations for
% 'normal' (left) mouse button selections, the |operation| field of the
% |eventData| structure is used to determine if either a 'click' or 'drag'
% operation is currently being performed. The handle of the currently
% active managed object (i.e. the axes object) is passed as the first
% argument to |pan_image|.
%
% When a left click is initially made, a number of variable are initialized
% that are used to handle the panning operation. This includes the initial
% position of the cursor (|panOrigin|, gotten from the |figurePoint| field
% of the |eventData| structure), the initial limits of the axes
% (|panLimits|), and the scale factor used to compute axes limit changes
% from cursor position changes (|panScale|, which uses the |figureRegion|
% field in the |eventData| structure to get the figure-level position, in
% pixels, of the axes object).
%
% When the left mouse button is clicked and held while the mouse is moved,
% the 'drag' operation is performed. The current cursor position (which
% moves with the mouse) is again gotten from the |figurePoint| field of the
% |eventData| structure and used to calculate the offset which is applied
% to the axes limits. The scaling is such that the axes panning mirrors the
% cursor movements.

%%
% *The |zoom_image| function*
%
% The |zoom_image| function is invoked when a 'scroll' event occurs. It
% fetches the |scrollEventData| field from the |eventData| structure and
% then gets the |VerticalScrollCount| field from that. A fractional change
% in the axes limits is computed and applied to the axes object.

%%
% *The |reset_image| function*
%
% The |reset_image| function is invoked when double-clicking with any mouse
% button over the axes. The axes limits are reset to default values
% (|xLimits| and |yLimits|, whose scope spans the |panning_demo| and
% |reset_image| functions).

%%
% *|MouseManager| object information*
%
% The |panning_demo| function will display the |MouseManager| object
% information in the command window when run. Here's what it displays:
%
%   mmObject = 
% 
%     MouseManager object:
% 
%             hFigure: 'Panning Demo'
%             enabled: 1
%     defaultHoverFcn: []
% 
%               Item (Tag)  |  operation___selection___callbackFcn
%     ----------------------+--------------------------------------------------
%            axes (AXES_1)  |  ___click_____normal___@panning_demo/pan_image
%                           |   |         \_open_____@panning_demo/reset_image
%                           |   \_drag______normal___@panning_demo/pan_image
%                           |   \_release___normal___@panning_demo/pan_image
%                           |   \_hover_____@panning_demo/pan_image   
%                           |   \_scroll____@panning_demo/zoom_image
%
% In addition to listing the name of the associated figure window, enabled
% state of the |MouseManager| object, and the default hover function (see
% the *Displaying information while hovering over an axes* section below
% for more detail about this), a table of managed items and their
% associated callbacks are displayed. The type of object and its 'Tag'
% property, if it has one, is displayed along with a heirarchy of
% operations, mouse selections, and callback functions.
%
% Note that the |pan_image| callback is defined for 'click', 'drag',
% 'release', and 'hover' operations. When we added this callback, we only
% specified the 'normal' selection and no operation arguments:
%
%   mmObject.add_item(hAxes, 'normal', @pan_image, ...
%
% As such, *all* possible operations were set to use |pan_image|. This
% includes the 'scroll' operation, although we subsequently overwrote that
% with |zoom_image| when we specified a 'scroll' operation callback. Since
% |pan_image| doesn't do anything for 'release' or 'hover' operations, we
% could be more specific when we add the callbacks, like so:
%
%   mmObject.add_item(hAxes, {'click', 'drag'}, 'normal', @pan_image, ...
%                            'scroll', @zoom_image, ...
%                            'click', 'open', @reset_image);
%
% And the callback heirarchy would now look like this:
%
%               Item (Tag)  |  operation___selection___callbackFcn
%     ----------------------+--------------------------------------------------
%            axes (AXES_1)  |  ___click_____normal___@panning_demo/pan_image
%                           |   |         \_open_____@panning_demo/reset_image
%                           |   \_drag______normal___@panning_demo/pan_image
%                           |   \_scroll____@panning_demo/zoom_image
%
% There is a lot of flexibility in defining callbacks. You could specify a
% separate callback for every individual operation/selection combination,
% or a single callback function to handle everything for a given object:
%
%   mmObject.add_item(hItem, @do_it_all);
%
% |do_it_all| would simply have to fetch the current operation and mouse
% selection from the |operation| and |selectionType| fields, respectively,
% of the |eventData| structure in order to perform the correct action.
%
% In truth, you may gain some slight performance advantages from specifying
% each individual combination, as that reduces the number of switch
% statements and function calls. However, this may be a micro-optimization.
% It's probably more important to organize things logically, like how
% |pan_image| handles all panning operations, and can therefore use
% persistent variables to store initial calculations.

%% Windowing data with sliding markers
% The code for this demo is included below and can be found in the file
% |windowing_demo.m|. After running the code, a plot will be displayed in a
% figure window. You can left click and drag the upper and lower marker
% lines to select a region of the plot between them (shown in red). The
% mean of values in this region is displayed above the plot:
%
% <include>windowing_demo.m</include>

%%
% This demo illustrates a situation similar to how GUIs are created through
% <https://www.mathworks.com/help/matlab/guide-or-matlab-functions.html
% GUIDE>, where object handles are stored in a |handles| structure and
% passed as an extra parameter to callback functions. The code creates a
% figure, axes, two plots of data, and two vertical marker lines that
% define lower and upper bounds on a subset of the plotted data. These two
% lines are added to the |MouseManager| object with an associated callback
% for 'drag' operations using the left ('normal' selection) mouse button.
% This callback function is added as a cell array with the first entry
% being a function handle to the local function |move_line| and the second
% entry being the structure of object handles |handles|. Here's what the
% |windowing_demo| function will display in the command window when run:
%
%   mmObject = 
% 
%     MouseManager object:
% 
%             hFigure: 'Windowing Demo'
%             enabled: 1
%     defaultHoverFcn: []
% 
%               Item (Tag)  |  operation___selection___callbackFcn
%     ----------------------+--------------------------------------------------
%             line (LOWER)  |  ___drag______normal___{@move_line, ...}
%     ----------------------+--------------------------------------------------
%             line (UPPER)  |  ___drag______normal___{@move_line, ...}

%% Displaying information while hovering over an axes
% The code for this demo is included below and can be found in the file
% |hovering_demo.m|. After running the code, an image will be displayed in
% a figure window. When you hover the mouse over the image, text will
% appear above the cursor displaying the RGB triple for the pixel beneath
% the cursor pointer. This text only appears over the image and no where
% else in the figure.
%
% <include>hovering_demo.m</include>

%%
% This demo illustrates the use of a default hover function for the figure
% window. The axes is first added to |mmObject| as a managed object with a
% callback function |display_rgb| for 'hover' operations. Then the
% |default_hover_fcn| method is used to add |clear_display| as a default
% hover function that executes whenever the cursor is not hovering over and
% other managed object. Here's the |MouseManager| object information that
% the |hovering_demo| function will display in the command window:
%
%   mmObject = 
% 
%     MouseManager object:
% 
%             hFigure: 'Hovering Demo'
%             enabled: 1
%     defaultHoverFcn: @hovering_demo/clear_display
% 
%               Item (Tag)  |  operation___selection___callbackFcn
%     ----------------------+--------------------------------------------------
%            axes (AXES_1)  |  ___hover_____@hovering_demo/display_rgb

%%
% The |display_rgb| function is evaluated when the cursor is over the axes,
% specifically when the axes 'CurrentPoint' property is over a pixel of the
% plotted image. If the cursor moves off the edge of the image, that
% movement might take it off the edge of the axes object as well. That
% would mean the |display_rgb| function wouldn't be evaluated again, and
% the last displayed text would still remain in its previous position. The
% use of the default hover function |clear_display| is necessary in this
% case to ensure the text is removed when the cursor moves off the axes.

%% 3D interaction using camera operations
%