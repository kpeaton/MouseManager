classdef MouseManager < handle
%MouseManager   Create object to manage interactive mouse-based controls.
%   MMOBJ = MouseManager(HFIGURE) will create a MouseManager object MMOBJ
%   that provides a general-purpose interface for managing mouse-based
%   interactions with figure objects. HFIGURE must be a valid figure
%   handle. The lifecycle of MMOBJ is bound to HFIGURE; deleting HFIGURE
%   will cause MMOBJ to be deleted as well.
%
%   Graphics objects to be managed by MMOBJ, along with their associated
%   callback functions, can be added using the MouseManager.add_item
%   method. MMOBJ can be enabled/disabled using the MouseManager.enable
%   method.
%
%   See also handle, MouseManager.add_item, MouseManager.remove_item,
%            MouseManager.default_hover_fcn, MouseManager.enable,
%            MouseManager.delete.

% TODO:
% - Make MouseManager_demo:
%   - 3D interaction using camera operations

% Author: Ken Eaton
% Version: MATLAB R2016b
% Last modified: 3/9/17
% Copyright 2017 by Kenneth P. Eaton
%--------------------------------------------------------------------------

%~~~Property blocks~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  %------------------------------------------------------------------------
  properties (SetAccess = immutable)

    hFigure  % Figure that MouseManager object is bound to.

  end

  %------------------------------------------------------------------------
  properties (SetAccess = private)

    enabled logical = false  % Enabled state of MouseManager object.
    itemList         % List of managed graphics objects.
    itemFcnTable     % Structure of function handles.
    defaultHoverFcn  % Default function for hovering over figure.

  end

  %------------------------------------------------------------------------
  properties (Access = private)

    hListener                 % Listener for WindowButtonFcn properties.
    hItemListeners            % Listeners for managed graphics objects.
    isActive logical = false  % Indicates if a mouse button is active.
    selectionType = 'none'    % Mouse button selected.
    figurePoint               % Most recent figure CurrentPoint value.
    itemIndex                 % Index of managed object currently active.
    figureRegion              % Figure-level position of managed object.
    scrollEventData           % Event data for scroll operations.

  end

%~~~Event blocks~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%~~~Method blocks~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  %------------------------------------------------------------------------
  methods

    %----------------------------------------------------------------------
    function this = MouseManager(hFigure)

      if (nargin > 0)
        assert(ishandle(hFigure) && strcmpi(hFigure.Type, 'figure'), ...
               'MouseManager:invalidFigureObject', ...
               'Argument must be a valid figure object.');
        this.hFigure = hFigure;
        propertyNames = {'WindowButtonDownFcn', ...
                         'WindowButtonMotionFcn', ...
                         'WindowButtonUpFcn', ...
                         'WindowScrollWheelFcn'};
        this.hListener = addlistener(hFigure, propertyNames, 'PreSet', ...
                                     @(~, ~) this.enable(false));
        this.hListener.Enabled = false;
        addlistener(hFigure, 'ObjectBeingDestroyed', ...
                    @(~, ~) this.delete());
      end

    end

    %----------------------------------------------------------------------
    function enable(this, newState)
    %enable   Enable/disable a MouseManager object.
    %   MMOBJ.enable(NEWSTATE) will set the new enabled state of MMOBJ to
    %   NEWSTATE. NEWSTATE can be a logical (TRUE/FALSE) or character
    %   string ('on'/'off') input.
    %
    %   When enabled, the WindowButtonDownFcn, WindowButtonMotionFcn,
    %   WindowButtonUpFcn, and WindowScrollWheelFcn properties of the
    %   linked figure will be updated for use by MMOBJ. If at any time
    %   these properties are modified, all of them will be removed and
    %   MMOBJ will be disabled.
    %
    %   See also MouseManager.

      % Check input and convert into a logical:

      switch class(newState)

        case 'logical'

          assert(isscalar(newState), 'MouseManager:invalidInputSize', ...
                 'Logical input must be a scalar.');

        case 'char'

          newState = lower(newState);
          assert(ismember(newState, {'on', 'off'}), ...
                 'MouseManager:invalidInputString', ...
                 'Input must be either ''on'' or ''off''.');
          newState = strcmp(newState, 'on');

        otherwise

          try
            newState = logical(newState);
          catch
            throw(MException('MouseManager:invalidInput', ...
                             'Could not convert input to logical.'));
          end
          assert(isscalar(newState), 'MouseManager:invalidInputSize', ...
                 'Logical input must be a scalar.');
        
      end

      % Add or remove figure callback functions as needed:

      if (this.enabled ~= newState)
        if newState
          set(this.hFigure, ...
              'WindowButtonDownFcn', {@this.mouse_op; 'down'}, ...
              'WindowButtonMotionFcn', {@this.mouse_op; 'motion'}, ...
              'WindowButtonUpFcn', {@this.mouse_op; 'up'}, ...
              'WindowScrollWheelFcn', {@this.mouse_op; 'scroll'});
          this.hListener.Enabled = true;
        else
          this.hListener.Enabled = false;
          set(this.hFigure, 'WindowButtonDownFcn', '', ...
                            'WindowButtonMotionFcn', '', ...
                            'WindowButtonUpFcn', '', ...
                            'WindowScrollWheelFcn', '');
        end
        this.enabled = newState;
      end

    end

    %----------------------------------------------------------------------
    function add_item(this, hItem, varargin)
    %add_item   Add interactive mouse controls for an object.
    %   MMOBJ.add_item(H, (OPER), (SELECTION), CALLBACKFCN, ...) will add a
    %   graphics object H to a MouseManager object MMOBJ such that the
    %   function CALLBACKFCN will be invoked for a given mouse operation
    %   OPER and mouse selection SELECTION. The parent figure of H must
    %   match the figure MMOBJ is bound to. If H is already a managed
    %   object then CALLBACKFCN will overwrite any existing callback.
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
    %       figurePoint      -- The CurrentPoint property of the bound
    %                           figure when CALLBACKFCN is invoked
    %       figureRegion     -- The position of H in pixels relative to the
    %                           bound figure (from getpixelposition)
    %       scrollEventData  -- Event data for scroll operations (empty
    %                           when not scrolling)
    %   Making calls to drawnow from within CALLBACKFCN is strongly
    %   discouraged, as graphics refreshing is handled by the MouseManager
    %   class object. CALLBACKFCN can be a cell array where the first
    %   element is a function handle and the remaining elements are
    %   additional arguments to be passed to CALLBACKFCN. CALLBACKFCN can
    %   be empty, in which case any existing callback is cleared (and H is
    %   removed as a managed object if it has no associated callbacks).
    %
    %   The input argument list can contain repeated sets of OPER,
    %   SELECTION, and CALLBACKFCN for setting more than one callback
    %   function for object H in a single call.
    %
    %   If H is deleted at any time, then H and any callback functions
    %   associated with it through add_item will be removed from MMOBJ.
    %
    %   See also MouseManager, MouseManager.remove_item, getpixelposition.

      % Add the new graphics object if it is not in the list already:

      assert(ishandle(hItem), 'MouseManager:invalidGraphicsObject', ...
             'Object must be a valid graphics handle.');
      assert(ancestor(hItem, 'figure') == this.hFigure, ...
             'MouseManager:invalidGraphicsObject', ...
             'Parent figure of graphics object must match bound figure.');
      newList = this.itemList;
      newFcnTable = this.itemFcnTable;
      newListeners = this.hItemListeners;
      index = find(hItem == newList);
      isNewItem = isempty(index);
      if isNewItem
        newList = [newList; hItem];
        newFcnTable = [newFcnTable; MouseManager.fcn_table_entry()];
        newListeners = [newListeners; ...
                        addlistener(hItem, 'ObjectBeingDestroyed', ...
                                    @(hItem, ~) this.remove_item(hItem))];
        index = numel(newList);
      end

      % Parse input list:

      callbackWasCleared = false;
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
        callbackWasCleared = callbackWasCleared || isempty(inArgs{3});
      end

      % Update managed object information:

      this.itemFcnTable = newFcnTable;
      if isNewItem
        this.itemList = newList;
        this.hItemListeners = newListeners;
      end

      % Perform clean-up if any callbacks were cleared:

      if callbackWasCleared && isempty(newFcnTable(index).hover) ...
         && isempty(newFcnTable(index).scroll)
        clickFcns = struct2cell([newFcnTable(index).click; ...
                                 newFcnTable(index).drag; ...
                                 newFcnTable(index).release]);
        if all(cellfun('isempty', clickFcns(:)))
          this.remove_item(hItem);
        end
      end

    end

    %----------------------------------------------------------------------
    function remove_item(this, hRemove)
    %remove_item   Remove a managed object.
    %   MMOBJ.remove_item(H) will remove H as a managed object of MMOBJ.
    %   Any callbacks associated with H are removed. H can be a vector of
    %   graphics objects.
    %
    %   See also MouseManager, MouseManager.add_item.

      if ~this.isvalid()
        return
      end
      index = ismember(this.itemList, hRemove);
      this.itemList(index) = [];
      this.itemFcnTable(index) = [];
      delete(this.hItemListeners(index));
      this.hItemListeners(index) = [];

    end

    %----------------------------------------------------------------------
    function default_hover_fcn(this, hoverFcn)
    %default_hover_fcn   Add a default hover function.
    %   MMOBJ.default_hover_fcn(CALLBACKFCN) will add a callback function
    %   CALLBACKFCN to a MouseManager object MMOBJ to be evaluated when the
    %   mouse is hovering over the bound figure window but not over any
    %   other object managed by MMOBJ which has a callback defined for
    %   hovering or scrolling behavior.
    %
    %   CALLBACKFCN must be written to accept two input arguments: a handle
    %   SOURCE and a structure EVENTDATA. SOURCE will be empty, and
    %   EVENTDATA will be a structure with the following fields:
    %       operation        -- Mouse operation, set to 'hover'
    %       selectionType    -- Mouse selection, set to 'none'
    %       figurePoint      -- The CurrentPoint property of the bound
    %                           figure when CALLBACKFCN is invoked
    %       figureRegion     -- Empty
    %       scrollEventData  -- Empty
    %   Making calls to drawnow from within CALLBACKFCN is strongly
    %   discouraged, as graphics refreshing is handled by the MouseManager
    %   class object. CALLBACKFCN can be a cell array where the first
    %   element is a function handle and the remaining elements are
    %   additional arguments to be passed to CALLBACKFCN. CALLBACKFCN can
    %   be empty, in which case any existing default hover function is
    %   removed.
    %
    %   See also MouseManager, MouseManager.add_item.

      if ~isempty(hoverFcn)
        assert(isa(hoverFcn, 'function_handle') ...
               || (iscell(hoverFcn) ...
                   && isa(hoverFcn{1}, 'function_handle')), ...
               'MouseManager:invalidFunctionHandle', ...
               'Function handle argument is invalid.');
      end
      this.defaultHoverFcn = hoverFcn;

    end

    %----------------------------------------------------------------------
    function disp(this)
    %disp   Display method for MouseManager objects.
    %   disp(MMOBJ) displays information for the MouseManager object MMOBJ.
    %
    %   See also MouseManager.

      % Check object validity:

      if ~this.isvalid()
        link1 = ['matlab: helpview', ...
                 '([docroot ''/techdoc/matlab_oop/matlab_oop.map''],', ...
                 '''deleted_handle_objects'')'];
        link2 = 'matlab: help MouseManager';
        fprintf('   handle to %s %s\n\n', text2link('deleted', link1), ...
                text2link('MouseManager', link2, 'font-weight:bold;'));
        return
      end

      % Display general information:

      fprintf('   MouseManager object:\n\n');
      if isempty(this.defaultHoverFcn)
        fcnString = '[]';
      else
        fcnString = callback2str(this.defaultHoverFcn);
      end
      displayData = {'hFigure', ['''', this.hFigure.Name, ''''], ...
                     'enabled', int2str(this.enabled), ...
                     'defaultHoverFcn', fcnString}.';
      fprintf('%18s: %-s\n', displayData{:});

      % Display managed items and associated callbacks:

      fprintf('\n%23s  |  %-s\n', 'Item (Tag)', ...
              'operation___selection___callbackFcn');
      separator = ['   ', repmat('-', 1, 73), '\n'];
      separator(26) = '+';
      oper = {'click__'; 'drag___'; 'release'};
      selection = {'normal'; 'extend'; 'alt___'; 'open__'};
      for index = 1:numel(this.itemList)

        % Format data for click, drag, and release callbacks:

        tableData = struct2cell([this.itemFcnTable(index).click; ...
                                 this.itemFcnTable(index).drag; ...
                                 this.itemFcnTable(index).release]);
        tableData = [repmat({' | '}, 12, 1), ...
                     oper([1 1 1 1 2 2 2 2 3 3 3 3]), ...
                     repmat({' \_'}, 12, 1), ...
                     repmat(selection, 3, 1), ...
                     repmat({'___'}, 12, 1), ...
                     reshape(tableData(1:4, :), 12, 1)];
        tableData(cellfun('isempty', tableData(:, 6)), :) = [];
        tableData(:, 6) = cellfun(@(c) {callback2str(c)}, tableData(:, 6));
        [~, startIndex] = unique(tableData(:, 2));
        tableData(startIndex, 3) = {'___'};
        tableData(startIndex, 1) = {' \_'};
        tableData(setdiff(1:size(tableData, 1), startIndex), 2) = {''};

        % Format data for hover callback:

        hoverFcn = this.itemFcnTable(index).hover;
        if ~isempty(hoverFcn)
          tableData = [tableData; ...
                       {' \_', 'hover__', '___', ...
                        callback2str(hoverFcn), '', ''}]; %#ok<AGROW>
        end

        % Format data for scroll callback:

        scrollFcn = this.itemFcnTable(index).scroll;
        if ~isempty(scrollFcn)
          tableData = [tableData; ...
                       {' \_', 'scroll_', '___', ...
                        callback2str(scrollFcn), '', ''}]; %#ok<AGROW>
        end

        % Final formatting of callback data:

        tableData(1, 1) = {'___'};
        tableData = [repmat({''}, 1, size(tableData, 1)); tableData.'];
        tableData(1, 2:end) = {[blanks(25), '|  ']};

        % Display data for managed item:

        fprintf(separator);
        hItem = this.itemList(index);
        if isempty(hItem.Tag)
          itemString = hItem.Type;
        else
          itemString = [hItem.Type ' (' hItem.Tag ')'];
        end
        fprintf('%23s  |  %-s', itemString, ...
                sprintf('%s%3s%7s%3s%6s%3s%s\n', tableData{:}));

      end
      fprintf('\n');

      %--------------------------------------------------------------------
      % Convert text to an HTML link.
      function linkText = text2link(textString, textLink, textStyle)

        if nargin == 2
          textStyle = '';
        end
        linkText = sprintf('<a href="%s" style="%s">%s</a>', ...
                           textLink, textStyle, textString);

      end

      %--------------------------------------------------------------------
      % Convert a callback to a string.
      function callbackString = callback2str(callbackFcn)

        if iscell(callbackFcn)
          try
            argString = cellfun(@(c) {[', ', char(c)]}, ...
                                callbackFcn(2:end));
          catch
            argString = {', ...'};
          end
          callbackString = ['{', func2str(callbackFcn{1}), ...
                            argString{:}, '}'];
          if ~strcmp(callbackString(2), '@')
            callbackString = ['{@', callbackString(2:end)];
          end
        else
          callbackString = func2str(callbackFcn);
          if ~strcmp(callbackString(1), '@')
            callbackString = ['@', callbackString];
          end
        end

      end

    end

    %----------------------------------------------------------------------
    function delete(this)
    %delete   Delete a MouseManager object.
    %   delete(MMOBJ) deletes the MouseManager object MMOBJ. The object is
    %   deleted but is not cleared from the workspace. A deleted object is
    %   no longer valid.
    %
    %   See also MouseManager, MouseManager.isvalid.

      this.enable(false);
      delete@handle(this);

    end

  end

  %------------------------------------------------------------------------
  methods (Access = private)

    %----------------------------------------------------------------------
    % Evaluate mouse operations.
    function mouse_op(this, ~, eventData, mouseOperation)

      switch mouseOperation

        case 'down'

          if (~this.isActive)
            this.figurePoint = this.hFigure.CurrentPoint;
            this.selectionType = this.hFigure.SelectionType;
            this.scrollEventData = [];
            if this.click_selected() || this.hover_selected()
              this.isActive = true;
              this.evaluate_operation('click');
              drawnow limitrate
            end
          end

        case 'motion'

          this.figurePoint = this.hFigure.CurrentPoint;
          if this.isActive
            this.evaluate_operation('drag');
          else
            this.scrollEventData = [];
            this.hover_selected();
            this.evaluate_operation('hover');
          end
          drawnow limitrate

        case 'up'

          if this.isActive
            this.figurePoint = this.hFigure.CurrentPoint;
            this.evaluate_operation('drag');
            this.evaluate_operation('release');
            this.isActive = false;
            this.selectionType = 'none';
            this.hover_selected();
            this.evaluate_operation('hover');
            drawnow limitrate
          end

        case 'scroll'

          if (~this.isActive)
            this.figurePoint = this.hFigure.CurrentPoint;
            this.scrollEventData = eventData;
            this.hover_selected();
            this.evaluate_operation('scroll');
            drawnow limitrate
          end

      end

    end

    %----------------------------------------------------------------------
    % Check if an item was last selected by clicking.
    function clickSelected = click_selected(this)

      this.itemIndex = [];
      this.figureRegion = [];
      if ~isempty(this.itemList) && ~isempty(this.hFigure.CurrentObject)
        this.itemIndex = find(this.hFigure.CurrentObject == this.itemList);
      end
      clickSelected = ~isempty(this.itemIndex);
      if clickSelected
        clickObject = this.itemList(this.itemIndex);
        this.figureRegion = getpixelposition(clickObject, true);
      end

    end

    %----------------------------------------------------------------------
    % Check if an item was last selected by hovering.
    function hoverSelected = hover_selected(this)

      this.itemIndex = [];
      this.figureRegion = [];
      for index = 1:numel(this.itemList)
        hoverObject = this.itemList(index);
        position = getpixelposition(hoverObject, true);
        if all(this.figurePoint >= position(1:2)) && ...
           all(this.figurePoint <= (position(1:2) + position(3:4)))
          this.itemIndex = index;
          this.figureRegion = position;
          break
        end
      end
      hoverSelected = ~isempty(this.itemIndex);

    end

    %----------------------------------------------------------------------
    % Fetch and evaluate a mouse operation.
    function evaluate_operation(this, oper)

      if ~isempty(this.itemIndex)

        fcn = this.itemFcnTable(this.itemIndex).(oper);
        if isstruct(fcn)
          fcn = fcn.(this.selectionType);
        end
        if isempty(fcn)
          return
        end
        if iscell(fcn)
          fcn{1}(this.itemList(this.itemIndex), this.event_data(oper), ...
                 fcn{2:end});
        else
          fcn(this.itemList(this.itemIndex), this.event_data(oper));
        end

      elseif strcmp(oper, 'hover') && ~isempty(this.defaultHoverFcn)

        if iscell(this.defaultHoverFcn)
          this.defaultHoverFcn{1}([], this.event_data(oper), ...
                                  this.defaultHoverFcn{2:end});
        else
          this.defaultHoverFcn([], this.event_data(oper));
        end

      end

    end

    %----------------------------------------------------------------------
    % Create an event data structure.
    function eventData = event_data(this, oper)

      eventData = struct('operation', oper, ...
                         'selectionType', this.selectionType, ...
                         'figurePoint', this.figurePoint, ...
                         'figureRegion', this.figureRegion, ...
                         'scrollEventData', this.scrollEventData);

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

      argIsSet = false(1, 2);

      % Check up to 3 arguments from the argument list:

      for inputIndex = 1:min(3, numel(argList))

        % Check first for a function handle (or empty) argument:

        newArg = argList{inputIndex};
        if isempty(newArg) || isa(newArg, 'function_handle') ...
           || (iscell(newArg) && isa(newArg{1}, 'function_handle'))
          inArgs{3} = newArg;
          break
        elseif (inputIndex == 3)
          break
        end

        % Check and format character and cell array arguments:

        switch class(newArg)

          case 'char'

            newArg = lower(newArg);
            isValid = [ismember(newArg, inArgs{1}) ...
                       ismember(newArg, inArgs{2})];
            validArgs = [inArgs{~argIsSet}];
            assert(any(isValid), 'MouseManager:invalidArgumentString', ...
                   ['Valid options for input arguments are: ' ...
                    sprintf('%s ', validArgs{:})]);
            assert(~any(isValid & argIsSet), ...
                   'MouseManager:invalidFormat', ...
                   ['Multiple values for OPER or SELECTION must be ' ...
                    'contained in a cell array.']);
            inArgs{isValid} = {newArg};
            argIsSet = argIsSet | isValid;

          case 'cell'

            assert(all(cellfun('isclass', newArg, 'char')), ...
                   'MouseManager:invalidArgumentType', ...
                   ['Cell array input argument must be a cell array ' ...
                    'of character strings.']);
            newArg = unique(lower(newArg(:).'));
            isValid = [all(ismember(newArg, inArgs{1})) ...
                       all(ismember(newArg, inArgs{2}))];
            validArgs = [inArgs{~argIsSet}];
            assert(any(isValid), 'MouseManager:invalidArgumentString', ...
                   ['Valid options for input arguments are: ' ...
                    sprintf('%s ', validArgs{:})]);
            inArgs{inputIndex} = newArg;
            argIsSet = argIsSet | isValid;

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