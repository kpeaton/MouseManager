classdef MouseManager < handle
%MouseManager   Class object for managing interactive mouse-based controls.
%   The MouseManager class provides a general-purpose interface for
%   managing mouse-based interactions with figure objects.
%
%   See also handle

% TODO:
% - Do HandleVisibility and HitTest properties of objects need to be
%   modified when added?
% - Allow input of just the selection type without the operation!
% - Is the use of drawnow limitrate OK?!
% - drawnow is not advised to use in user functions!
% - Add listeners for object deletions and WindowFcn changes!
% - Allow an object to appear in only one of clickList or hoverList!
%   - Allow moving from one to the other?
%   - COMBINE LISTS???
%     - Create hoverEnabled array property to distiguish
%     - Merge add_clickable and add_hoverable (add_managed?)
% - Add help!
%   - Fix help for public methods!
% - Add disp method to show table of function handles?

% Author: Ken Eaton
% Version: MATLAB R2016b
% Last modified: 2/25/17
% Copyright 2017 by Kenneth P. Eaton
%--------------------------------------------------------------------------

%~~~Property blocks~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  properties (SetAccess = immutable)
  %------------------------------------------------------------------------
  % Properties that need to be defined on construction.
  %------------------------------------------------------------------------
    hFigure
  end

  properties (SetAccess = private)
  %------------------------------------------------------------------------
  % Properties that are modified by class methods only.
  %------------------------------------------------------------------------
    enabled logical = false
  end

  properties (Access = private)
  %------------------------------------------------------------------------
  % Private properties.
  %------------------------------------------------------------------------
    isActive logical = false
    selectionType = 'none'
    figurePoint
    clickList
    clickIndex
    clickFcnTable
    hoverList
    hoverIndex
    hoverFcnTable
    hoverRegion
    defaultHoverFcn
    scrollEventData
  end

%~~~Event blocks~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%~~~Method blocks~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  methods
  %------------------------------------------------------------------------
  % Public methods.
  %------------------------------------------------------------------------

    %----------------------------------------------------------------------
    function obj = MouseManager(hFigure)
    %
    %   MouseManager constructor.
    %
    %----------------------------------------------------------------------

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
    %
    %   Function for enabling/disabling mouse control.
    %
    %----------------------------------------------------------------------

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
    function add_clickable(obj, hObject, varargin)
    %
    %   Function for adding interactive control for a clickable object.
    %
    %----------------------------------------------------------------------

      % Add the new graphics object if it is not in the list already:

      assert(ishandle(hObject), 'MouseManager:invalidGraphicsObject', ...
             'Argument must be a valid graphics object.');
      newList = obj.clickList;
      newFcnTable = obj.clickFcnTable;
      index = find(hObject == newList);
      if isempty(index)
        newList = [newList; hObject];
        newFcnTable = [newFcnTable; MouseManager.click_fcn_table_entry()];
        index = numel(newList);
      end

      % Parse input list:

      while ~isempty(varargin)
        inArgs = {{'click', 'drag', 'release'}, ...
                  {'normal', 'extend', 'alt', 'open'}};
        [varargin, inArgs] = MouseManager.parse_input(varargin, inArgs);
        for oper = inArgs{1}
          for selection = inArgs{2}
            newFcnTable(index).(oper{1}).(selection{1}) = inArgs{3};
          end
        end
      end

      % Update clickable list and function table:

      obj.clickList = newList;
      obj.clickFcnTable = newFcnTable;

    end

    %----------------------------------------------------------------------
    function add_hoverable(obj, hObject, varargin)
    %
    %   Function for adding interactive control for a hoverable object.
    %
    %----------------------------------------------------------------------

      % Add the new graphics object if it is not in the list already:

      assert(ishandle(hObject), 'MouseManager:invalidGraphicsObject', ...
             'Argument must be a valid graphics object.');
      newList = obj.hoverList;
      newFcnTable = obj.hoverFcnTable;
      index = find(hObject == newList);
      if isempty(index)
        newList = [newList; hObject];
        newFcnTable = [newFcnTable; MouseManager.hover_fcn_table_entry()];
        index = numel(newList);
      end

      % Parse inputs:

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
            newFcnTable(index).(oper{1}) = inArgs{3};
          end
        end
      end

      % Update hoverable list and function table:

      obj.hoverList = newList;
      obj.hoverFcnTable = newFcnTable;

    end

    %----------------------------------------------------------------------
    function default_hover_fcn(obj, hoverFcn)
    %
    %   Function for adding a default hover function (evaluates when the
    %   mouse is not hovering over any other hoverable objects).
    %
    %----------------------------------------------------------------------

      if ~isempty(hoverFcn)
        assert(isa(hoverFcn, 'function_handle'), ...
               'MouseManager:invalidFunctionHandle', ...
               'Function handle argument is invalid.');
      end
      obj.defaultHoverFcn = hoverFcn;

    end

    %----------------------------------------------------------------------
    function mouse_op(obj, ~, eventData, mouseOperation)
    %
    %   Function that evaluates mouse operations.
    %
    %----------------------------------------------------------------------

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
            obj.clickIndex = [];
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

  methods (Access = private)
  %------------------------------------------------------------------------
  % Private methods.
  %------------------------------------------------------------------------

    %----------------------------------------------------------------------
    function clickSelected = click_selected(obj)
    %
    %   Function for checking if a clickable object was last selected.
    %
    %----------------------------------------------------------------------

      obj.clickIndex = [];
      if ~isempty(obj.clickList) && ~isempty(obj.hFigure.CurrentObject)
        obj.clickIndex = find(obj.hFigure.CurrentObject == obj.clickList);
      end
      clickSelected = ~isempty(obj.clickIndex);

    end

    %----------------------------------------------------------------------
    function hoverSelected = hover_selected(obj)
    %
    %   Function for checking if a hoverable object is selected.
    %
    %----------------------------------------------------------------------

      obj.hoverIndex = [];
      obj.hoverRegion = [];
      for index = 1:numel(obj.hoverList)
        hoverObject = obj.hoverList(index);
        position = getpixelposition(hoverObject, true);
        if all(obj.figurePoint >= position(1:2)) && ...
           all(obj.figurePoint <= (position(1:2) + position(3:4)))
          obj.hoverIndex = index;
          obj.hoverRegion = position;
          break
        end
      end
      hoverSelected = ~isempty(obj.hoverIndex);

    end

    %----------------------------------------------------------------------
    function evaluate_operation(obj, oper)
    %
    %   Function for fetching and evaluating a mouse operation.
    %
    %----------------------------------------------------------------------

      if ~isempty(obj.clickIndex)
        fcn = obj.clickFcnTable(obj.clickIndex).(oper).(obj.selectionType);
        if ~isempty(fcn)
          fcn(obj.clickList(obj.clickIndex), obj.event_data(oper));
        end
      elseif ~isempty(obj.hoverIndex)
        fcn = obj.hoverFcnTable(obj.hoverIndex).(oper);
        if isstruct(fcn)
          fcn = fcn.(obj.selectionType);
        end
        if ~isempty(fcn)
          fcn(obj.hoverList(obj.hoverIndex), obj.event_data(oper));
        end
      elseif strcmp(oper, 'hover') && ~isempty(obj.defaultHoverFcn)
        obj.defaultHoverFcn([], obj.event_data(oper));
      end

    end

    %----------------------------------------------------------------------
    function eventData = event_data(obj, oper)
    %
    %   Function to create an event data structure.
    %
    %----------------------------------------------------------------------

      eventData = struct('operation', oper, ...
                         'selectionType', obj.selectionType, ...
                         'figurePoint', obj.figurePoint, ...
                         'figureRegion', obj.hoverRegion, ...
                         'scrollEventData', obj.scrollEventData);

    end

  end

  methods (Access = private, Static)
  %------------------------------------------------------------------------
  % Static helper functions.
  %------------------------------------------------------------------------

    %----------------------------------------------------------------------
    function newEntry = click_fcn_table_entry
    %
    %   Function to create a new entry for clickFcnTable.
    %
    %----------------------------------------------------------------------

      selectionStruct = struct('normal', [], ...
                               'extend', [], ...
                               'alt', [], ...
                               'open', [], ...
                               'none', []);
      newEntry = struct('click', selectionStruct, ...
                        'drag', selectionStruct, ...
                        'release', selectionStruct);

    end

    %----------------------------------------------------------------------
    function newEntry = hover_fcn_table_entry
    %
    %   Function to create a new entry for hoverFcnTable.
    %
    %----------------------------------------------------------------------

      newEntry = MouseManager.click_fcn_table_entry();
      newEntry.hover = [];
      newEntry.scroll = [];

    end

    %----------------------------------------------------------------------
    function [argList, inArgs] = parse_input(argList, inArgs)
    %
    %   Function to parse input arguments.
    %
    %----------------------------------------------------------------------

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