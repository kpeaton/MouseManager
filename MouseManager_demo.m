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
% |panning_demo.m|:
% 
% <include>panning_demo.m</include>
%

%%
% First, an image is loaded and then displayed in a figure window. A
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
% associated with 'click' operations made over the image, specifically
% 'open' (i.e. double-click) selections made with any mouse button.
%
% Finally, a call to the |enable| method is made to enable |mmObject|,
% which starts in the default 'off' state. This activates all of the above
% mouse-based interactions.
%
% Looking at the |pan_image| function, we can see that it uses the
% |eventData| structure that is automatically passed to it by the
% |MouseManager| object. Since |pan_image| handles all operations for
% 'normal' (left) mouse button selections, the |operation| field of the
% |eventData| structure is used to determine if either a 'click' or 'drag'
% operation is currently being performed.
%
% When a left click is initially made, a number of variable are initialized
% that are used to handle the panning operation. This includes the initial
% position of the cursor (|panOrigin|, gotten from the |figurePoint| field
% of the |eventData| structure), the initial limits of the axes
% (|panLimits|), and the scale factor used to compute axes limit changes
% from cursor position changes (|panScale|, which uses the |figureRegion|
% field in the |eventData| structure to determine

%% Windowing data with sliding lines
% :

%%
% 

%% Displaying information while hovering over an axes
% :

%% 3D interaction using camera operations
%