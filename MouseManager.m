classdef MouseManager < handle
%MouseManager   Class object for managing interactive mouse-based controls.
%   MMOBJ = MouseManager(HFIGURE) will create a MouseManager object MMOBJ
%   that provides a general-purpose interface for managing mouse-based
%   interactions with figure objects. HFIGURE must be a valid figure
%   handle. The lifecycle of MMOBJ is bound to HFIGURE; deleting HFIGURE
%   will cause MMOBJ to be deleted as well.
%
%   Graphics objects to be managed by MMOBJ, along with their pertinent
%   callback functions, can be added using the MouseManager.add_item
%   method. MMOBJ can be enabled/disabled using the MouseManager.enable
%   method.
%
%   See also handle, MouseManager.enable, MouseManager.add_item,
%            MouseManager.default_hover_fcn.

% TODO:
% - Do HandleVisibility and HitTest properties of objects need to be
%   modified when added?
% - Allow input of just the selection type without the operation!
% - Add listeners for object deletions and WindowFcn changes!
% - Add Tag property?
% - Add check to enable() for numeric/logical input.
% - Add help!
%   - Fix help for public methods!
% - Add disp method to show table of function handles?
% - Will mouse_op still work if private method?

% Author: Ken Eaton
% Version: MATLAB R2016b
% Last modified: 2/28/17
% Copyright 2017 by Kenneth P. Eaton
%--------------------------------------------------------------------------

%~~~Property blocks~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  %------------------------------------------------------------------------
  properties (SetAccess = immutable)

    hFigure

  end

  %------------------------------------------------------------------------
  properties (SetAccess = private)

    enabled logical = false
    itemList
    isHoverable
    itemFcnTable
    defaultHoverFcn

  end

  %------------------------------------------------------------------------
  properties (Access = private)

    isActive logical = false
    selectionType = 'none'
    figurePoint
    itemIndex
    hoverRegion
    scrollEventData

  end

%~~~Event blocks~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%~~~Method blocks~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  %------------------------------------------------------------------------
  methods

    %----------------------------------------------------------------------
    function obj = MouseManager(hFigure)

      if (nargin > 0)
        assert(ishandle(hFigure) && strcmpi(hFigure.Type, 'figure'), ...
               'MouseManager:invalidFigureObject', ...
               'Argument must be a valid figure object.');
        obj.hFigure = hFigure;
        addlistener(hFigure, 'ObjectBeingDestroyed', @(~, ~) obj.delete());
      end

    end

    %----------------------------------------------------------------------
    function enable(obj, newState)
    %MouseManager.enable   Enable/disable a MouseManager object.
    %   MMOBJ.enable(NEWSTATE) will set the new enabled state of MMOBJ to
    %   NEWSTATE. NEWSTATE can be a boolean (TRUE/FALSE) or character
    %   string ('on'/'off') input.
    %
    %   When enabled, the WindowButtonDownFcn, WindowButtonMotionFcn,
    %   WindowButtonUpFcn, and WindowScrollWheelFcn properties of the
    %   linked figure will be updated for use by MMOBJ. If at any time
    %   these properties are modified, all of them will be removed and
    %   MMOBJ will be disabled.
    %
    %   See also MouseManager.

      % Convert character string input into a logical:

      if ischar(newState)
        newState = lower(newState);
        assert(ismember(newState, {'on', 'off'}), ...
               'MouseManager:invalidInputString', ...
               'Input must be either ''on'' or ''off''.');
        newState = strcmp(newState, 'on');
      end

      % Add or remove callback functions as needed:

      if (obj.enabled ~= newState)
        if newState
          set(obj.hFigure, ...
              'WindowButtonDownFcn', {@obj.mouse_op; 'down'}, ...
              'WindowButtonMotionFcn', {@obj.mouse_op; 'motion'}, ...
              'WindowButtonUpFcn', {@obj.mouse_op; 'up'}, ...
              'WindowScrollWheelFcn', {@obj.mouse_op; 'scroll'});
          %Turn on listeners!
        else
          %Turn off listeners!
          set(obj.hFigure, 'WindowButtonDownFcn', '', ...
                           'WindowButtonMotionFcn', '', ...
                           'WindowButtonUpFcn', '', ...
                           'WindowScrollWheelFcn', '');
        end
        obj.enabled = newState;
      end

    end

    %----------------------------------------------------------------------
    function add_item(obj, hItem, varargin)
    %MouseManager.add_item   Add interactive mouse controls for an object.
    %   MMOBJ.add_item(H, (OPER), (SELECTION), CALLBACKFCN, ...) will add a
    %   graphics object H to a MouseManager object MMOBJ such that the
    %   function CALLBACKFCN will be invoked for a given mouse operation
    %   OPER and mouse selection SELECTION.
    %
    %   OPER can be any one of: 'click', 'drag', 'release', 'hover', or
    %   'scroll'. SELECTION can be any one of: 'normal' (left click),
    %   'extend' (middle click), 'alt' (right click), or 'open' (double
    %   click). One or both of OPER or SELECTION can be a cell array
    %   containing a subset of the above values, in which case all
    %   combinations of OPER and SELECTION will invoke CALLBACKFCN. One or
    %   both of OPER or SELECTION can be omitted, in which case all
    %   possible respective values will be used.
    %
    %   CALLBACKFCN must be written to accept two input arguments: a handle
    %   SOURCE and a structure EVENTDATA. SOURCE will be the handle H, and
    %   EVENTDATA will be a structure with the following fields:
    %       operation        -- Mouse operation (values above)
    %       selectionType    -- Mouse selection (values above, or 'none')
    %       figurePoint      -- The CurrentPoint property of the linked
    %                           figure when CALLBACKFCN is invoked
    %       figureRegion     -- The position of H in pixels relative to the
    %                           linked figure (from getpixelposition)
    %       scrollEventData  -- Event data for scroll operations (empty
    %                           when not scrolling)
    %   You should not have to make any calls to drawnow within
    %   CALLBACKFCN, as graphics refreshing is handled by the MouseManager
    %   class object.
    %
    %   The input argument list can contain repeated sets of OPER,
    %   SELECTION, and CALLBACKFCN for setting more than one callback
    %   function for object H in a single call.
    %
    %   If H is deleted at any time, all callback functions associated with
    %   H through add_item will be removed from MMOBJ.
    %
    %   See also MouseManager, getpixelposition.

      % Add the new graphics object if it is not in the list already:

      assert(ishandle(hItem), 'MouseManager:invalidGraphicsObject', ...
             'Argument must be a valid graphics object.');
      newList = obj.itemList;
      newHoverable = obj.isHoverable;
      newFcnTable = obj.itemFcnTable;
      index = find(hItem == newList);
      if isempty(index)
        newList = [newList; hItem];
        newHoverable = [newHoverable; false];
        newFcnTable = [newFcnTable; MouseManager.fcn_table_entry()];
        index = numel(newList);
      end

      % Parse input list:

      while ~isempty(varargin)
        inArgs = {{'click', 'drag', 'release', 'hover', 'scroll'}, ...
                  {'normal', 'extend', 'alt', 'open'}};
        [varargin, inArgs] = MouseManager.parse_input(varargin, inArgs);
        for oper = inArgs{1}
          if isstruct(newFcnTable(index).(oper{1}))
            for selection = inArgs{2}
              newFcnTable(index).(oper{1}).(selection{1}) = inArgs{3};
            end
          else
            newHoverable(index) = true;
            newFcnTable(index).(oper{1}) = inArgs{3};
          end
        end
      end

      % Update item list and function table:

      obj.itemList = newList;
      obj.isHoverable = newHoverable;
      obj.itemFcnTable = newFcnTable;

    end

    %----------------------------------------------------------------------
    function default_hover_fcn(obj, hoverFcn)
    %MouseManager.default_hover_fcn   Add a default hover function.
    %   MMOBJ.default_hover_fcn(@CALLBACKFCN) will add a callback function
    %   CALLBACKFCN to a MouseManager object MMOBJ to be evaluated when the
    %   mouse is hovering over the parent figure window but not over any
    %   other object managed by MMOBJ which has a callback defined for
    %   hovering or scrolling behavior.
    %
    %   See also MouseManager, MouseManager.add_item.

      if ~isempty(hoverFcn)
        assert(isa(hoverFcn, 'function_handle'), ...
               'MouseManager:invalidFunctionHandle', ...
               'Function handle argument is invalid.');
      end
      obj.defaultHoverFcn = hoverFcn;

    end

    %----------------------------------------------------------------------
    % Evaluate mouse operations.
    function mouse_op(obj, ~, eventData, mouseOperation)

      switch mouseOperation

        case 'down'

          if (~obj.isActive)
            obj.figurePoint = obj.hFigure.CurrentPoint;
            obj.selectionType = obj.hFigure.SelectionType;
            obj.scrollEventData = [];
            if obj.click_selected() || obj.hover_selected()
              obj.isActive = true;
              obj.evaluate_operation('click');
              drawnow limitrate
            end
          end

        case 'motion'

          obj.figurePoint = obj.hFigure.CurrentPoint;
          if obj.isActive
            obj.evaluate_operation('drag');
          else
            obj.scrollEventData = [];
            obj.hover_selected();
            obj.evaluate_operation('hover');
          end
          drawnow limitrate

        case 'up'

          if obj.isActive
            obj.figurePoint = obj.hFigure.CurrentPoint;
            obj.evaluate_operation('drag');
            obj.evaluate_operation('release');
            obj.isActive = false;
            obj.selectionType = 'none';
            obj.hover_selected();
            obj.evaluate_operation('hover');
            drawnow limitrate
          end

        case 'scroll'

          if (~obj.isActive)
            obj.figurePoint = obj.hFigure.CurrentPoint;
            obj.scrollEventData = eventData;
            obj.hover_selected();
            obj.evaluate_operation('scroll');
            drawnow limitrate
          end

      end

    end

  end

  %------------------------------------------------------------------------
  methods (Access = private)

    %----------------------------------------------------------------------
    % Check if an item was last selected by clicking.
    function clickSelected = click_selected(obj)

      obj.itemIndex = [];
      obj.hoverRegion = [];
      if ~isempty(obj.itemList) && ~isempty(obj.hFigure.CurrentObject)
        obj.itemIndex = find(obj.hFigure.CurrentObject == obj.itemList);
      end
      clickSelected = ~isempty(obj.itemIndex);

    end

    %----------------------------------------------------------------------
    % Check if an item was last selected by hovering.
    function hoverSelected = hover_selected(obj)

      obj.itemIndex = [];
      obj.hoverRegion = [];
      for index = find(obj.isHoverable.')
        hoverObject = obj.itemList(index);
        position = getpixelposition(hoverObject, true);
        if all(obj.figurePoint >= position(1:2)) && ...
           all(obj.figurePoint <= (position(1:2) + position(3:4)))
          obj.itemIndex = index;
          obj.hoverRegion = position;
          break
        end
      end
      hoverSelected = ~isempty(obj.itemIndex);

    end

    %----------------------------------------------------------------------
    % Fetch and evaluate a mouse operation.
    function evaluate_operation(obj, oper)

      if ~isempty(obj.itemIndex)
        fcn = obj.itemFcnTable(obj.itemIndex).(oper);
        if isstruct(fcn)
          fcn = fcn.(obj.selectionType);
        end
        if ~isempty(fcn)
          fcn(obj.itemList(obj.itemIndex), obj.event_data(oper));
        end
      elseif strcmp(oper, 'hover') && ~isempty(obj.defaultHoverFcn)
        obj.defaultHoverFcn([], obj.event_data(oper));
      end

    end

    %----------------------------------------------------------------------
    % Create an event data structure.
    function eventData = event_data(obj, oper)

      eventData = struct('operation', oper, ...
                         'selectionType', obj.selectionType, ...
                         'figurePoint', obj.figurePoint, ...
                         'figureRegion', obj.hoverRegion, ...
                         'scrollEventData', obj.scrollEventData);

    end

  end

  %------------------------------------------------------------------------
  methods (Access = private, Static)

    %----------------------------------------------------------------------
    % Create a new entry for itemFcnTable.
    function newEntry = fcn_table_entry

      selectionStruct = struct('normal', [], ...
                               'extend', [], ...
                               'alt', [], ...
                               'open', [], ...
                               'none', []);
      newEntry = struct('click', selectionStruct, ...
                        'drag', selectionStruct, ...
                        'release', selectionStruct, ...
                        'hover', [], ...
                        'scroll', []);

    end

    %----------------------------------------------------------------------
    % Parse input arguments.
    function [argList, inArgs] = parse_input(argList, inArgs)

      % Check up to 3 arguments from the argument list:

      for inputIndex = 1:min(3, numel(argList))

        % Check first for a function handle (or empty) argument:

        newArg = argList{inputIndex};
        if isempty(newArg) || isa(newArg, 'function_handle')
          inArgs{3} = newArg;
          break
        elseif (inputIndex == 3)
          break
        end

        % Check and format character and cell array arguments:

        switch class(newArg)

          case 'char'  %START HERE!!!

            newArg = lower(newArg);
            assert(ismember(newArg, inArgs{inputIndex}), ...
                   'MouseManager:invalidArgumentString', ...
                   ['Valid options for input argument are: ' ...
                    sprintf('%s ', inArgs{inputIndex}{:})]);
            inArgs{inputIndex} = {newArg};

          case 'cell'

            assert(cellfun('isclass', newArg, 'char'), ...
                   'MouseManager:invalidArgumentType', ...
                   ['Cell array input argument must be a cell array ' ...
                    'of character strings.']);
            newArg = lower(newArg);
            assert(all(ismember(newArg, inArgs{inputIndex})), ...
                   'MouseManager:invalidArgumentString', ...
                   ['Valid options for input argument are: ' ...
                    sprintf('%s ', inArgs{inputIndex}{:})]);
            inArgs{inputIndex} = newArg;

          otherwise

            throw(MException('MouseManager:invalidArgumentType', ...
                             ['Input argument must be a character ' ...
                              'string, cell array of character ' ...
                              'strings, or function handle.']));

        end

      end

      % Check that a function handle (or empty) argument exists:

      if (numel(inArgs) < 3)
        throw(MException('MouseManager:invalidInputFormat', ...
                         ['Input argument list does not have the ' ...
                          'correct format.']));
      end

      % Shrink the argument list:

      argList = argList((inputIndex+1):end);

    end

  end

end