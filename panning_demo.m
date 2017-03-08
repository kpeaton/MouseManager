function panning_demo

  % Load image:
  demoImage = imread('peppers.png');
  [nRows, nColumns, ~] = size(demoImage);
  xLimits = [0.5 nColumns+0.5];
  yLimits = [0.5 nRows+0.5];

  % Create figure and display an image:
  hFigure = figure('Name', 'Panning Demo', 'NumberTitle', 'off');
  hAxes = axes(hFigure, 'DataAspectRatio', [1 1 1], ...
                        'NextPlot', 'add', ...
                        'Tag', 'AXES_1', ...
                        'Visible', 'off', ...
                        'XLim', xLimits, ...
                        'YDir', 'reverse', ...
                        'YLim', yLimits);
  image(hAxes, demoImage);

  % Create MouseManager and intialize:
  mmObject = MouseManager(hFigure);
  mmObject.add_item(hAxes, 'normal', @pan_image, ...
                           'scroll', @zoom_image, ...
                           'click', 'open', @reset_image);
  mmObject.enable(true);
  display(mmObject);

  % Nested functions:

  function pan_image(hObject, eventData)
    persistent panOrigin panLimits panScale
    switch eventData.operation
      case 'click'
        panOrigin = eventData.figurePoint;
        panLimits = [hObject.XLim hObject.YLim];
        axesPosition = eventData.figureRegion;
        panScale = max([diff(panLimits(1:2))/axesPosition(3) ...
                        diff(panLimits(3:4))/axesPosition(4)]);
      case 'drag'
        offset = panScale.*(eventData.figurePoint-panOrigin);
        hObject.XLim = panLimits(1:2) - offset(1);
        hObject.YLim = panLimits(3:4) + offset(2);
    end
  end

  function zoom_image(hObject, eventData)
    fraction = (1-1.25^eventData.scrollEventData.VerticalScrollCount)/2;
    hObject.XLim = hObject.XLim + [1 -1].*fraction.*diff(hObject.XLim);
    hObject.YLim = hObject.YLim + [1 -1].*fraction.*diff(hObject.YLim);
  end

  function reset_image(hObject, ~)
    hObject.XLim = xLimits;
    hObject.YLim = yLimits;
  end

end