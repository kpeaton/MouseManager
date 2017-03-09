function hovering_demo

  % Load image:
  demoImage = imread('peppers.png');
  [nRows, nColumns, ~] = size(demoImage);

  % Create figure and graphics objects:
  hFigure = figure('Name', 'Hovering Demo', 'NumberTitle', 'off');
  hAxes = axes(hFigure, 'Color', 'k', ...
                        'DataAspectRatio', [1 1 1], ...
                        'NextPlot', 'add', ...
                        'Tag', 'AXES_1', ...
                        'XColor', 'none', ...
                        'XLim', [0.5 nColumns+0.5], ...
                        'YColor', 'none', ...
                        'YDir', 'reverse', ...
                        'YLim', [0.5 nRows+0.5]);
  image(hAxes, demoImage);
  hText = text(hAxes, 1, 1, '', 'Color', [0 0.8 0.8], ...
                                'HorizontalAlignment', 'center', ...
                                'VerticalAlignment', 'bottom');

  % Create MouseManager and intialize:
  mmObject = MouseManager(hFigure);
  mmObject.add_item(hAxes, 'hover', @display_rgb);
  mmObject.default_hover_fcn(@clear_display);
  mmObject.enable(true);
  display(mmObject);

  % Nested functions:

  function display_rgb(hSource, ~)
    axesPoint = get(hSource, 'CurrentPoint');
    axesPoint = round(axesPoint(1, 1:2));
    if any(axesPoint < [1 1]) || any(axesPoint > [nColumns nRows])
      set(hText, 'String', '');
    else
      pixelData = demoImage(axesPoint(2), axesPoint(1), 1:3);
      set(hText, 'Position', [axesPoint 0], ...
                 'String', sprintf('(%d,%d,%d)', pixelData(:)));
    end
  end

  function clear_display(~, ~)
    set(hText, 'String', '');
  end

end