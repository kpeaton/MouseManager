function windowing_demo

  % Sample data:
  demoData = rand(1, 100);

  % Create figure and graphics objects:
  handles.figure = figure('Name', 'Windowing Demo', 'NumberTitle', 'off');
  handles.axes = axes(handles.figure, 'NextPlot', 'add', ...
                      'XLim', [1 100], 'YLim', [0 1]);
  handles.data = line(handles.axes, 1:100, demoData, 'Color', 'k');
  handles.overlay = line(handles.axes, 1:100, demoData, 'Color', 'r');
  handles.lower = line(handles.axes, [1 1], [0 1], 'Color', 'b', ...
                       'LineWidth', 2, 'Tag', 'LOWER');
  handles.upper = line(handles.axes, [100 100], [0 1], 'Color', 'b', ...
                       'LineWidth', 2, 'Tag', 'UPPER');

  % Create MouseManager and intialize:
  mmObject = MouseManager(handles.figure);
  mmObject.add_item(handles.lower, 'drag', 'normal', {@move_line, handles});
  mmObject.add_item(handles.upper, 'drag', 'normal', {@move_line, handles});
  mmObject.enable(true);
  display(mmObject);

end

% Local function:

function move_line(hObject, ~, handles)

  axesPoint = get(handles.axes, 'CurrentPoint');
  yData = get(handles.data, 'YData');

  switch hObject

    case handles.lower  % Adjust lower threshold

      maxLimit = get(handles.upper, 'XData');
      newValue = min(max(ceil(axesPoint(1, 1)), 1), maxLimit(1));
      xData = newValue:maxLimit;

    case handles.upper  % Adjust upper threshold

      minLimit = get(handles.lower, 'XData');
      newValue = min(max(floor(axesPoint(1, 1)), minLimit(1)), 100);
      xData = minLimit:newValue;

  end

  set(hObject, 'XData', [newValue newValue]);
  yData = yData(xData);
  set(handles.overlay, 'XData', xData, 'YData', yData);
  title(handles.axes, sprintf('Mean = %f', mean(yData)));

end