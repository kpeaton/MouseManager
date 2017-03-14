## `MouseManager` ##

The `MouseManager` class provides a general-purpose, easy-to-use interface for managing mouse-based interactions with objects in a figure. A `MouseManager` object is associated with a figure window and helps handle any mouse-driven interactions (such as clicking, hovering, and scrolling) with multiple graphics objects within the figure, particularly axes objects and their children.

`MMOBJ = MouseManager(HFIGURE)` will create a `MouseManager` object `MMOBJ` that provides a general-purpose interface for managing mouse-based interactions with figure objects. `HFIGURE` must be a valid figure handle. The lifecycle of `MMOBJ` is bound to `HFIGURE`; deleting `HFIGURE` will cause `MMOBJ` to be deleted as well.

Graphics objects to be managed by `MMOBJ`, along with their associated callback functions, can be added using the `MouseManager.add_item` method. `MMOBJ` can be enabled/disabled using the `MouseManager.enable` method.

Examples applications of `MouseManager` can be found in the demo script [MouseManager_demo.m](https://github.com/kpeaton/MouseManager/blob/master/MouseManager_demo.m) or in published form in [MouseManager_demo.html](https://github.com/kpeaton/MouseManager/blob/master/html/MouseManager_demo.html).

***Note:** The code in the master branch may not be fully tested or stable. Stable, tested releases appear in the [Releases tab](https://github.com/kpeaton/MouseManager/releases). Additional information can be found on the [MathWorks File Exchange submission page](https://www.mathworks.com/matlabcentral/fileexchange/61975-mousemanager).*
