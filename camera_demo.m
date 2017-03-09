function camera_demo

  % Sample data:
  [X, Y, Z] = peaks();

  % Create figure and graphics objects:
  hFigure = figure('Color', 'k', 'Name', 'Camera Demo', ...
                   'NumberTitle', 'off');
  hAxes = axes(hFigure, 'CameraPosition', [-10 -10 10], ...
                        'CameraTarget', [0 0 0], ...
                        'CameraUpVector', [0 0 1], ...
                        'CameraViewAngle', 30, ...
                        'Color', 'k', ...
                        'DataAspectRatio', [1 1 2], ...
                        'NextPlot', 'add', ...
                        'Position', [0 0 1 1], ...
                        'Projection', 'perspective', ...
                        'Tag', 'AXES_1', ...
                        'XColor', 'none', ...
                        'XLim', [-3 3], ...
                        'YColor', 'none', ...
                        'YLim', [-3 3], ...
                        'ZColor', 'none', ...
                        'ZLim', [-7 9]);
  hSurf = surf(hAxes, X, Y, Z, del2(Z));
  set(hSurf, 'EdgeColor', 'none');

  % Create MouseManager and intialize:
  mmObject = MouseManager(hFigure);
  mmObject.add_item(hAxes, {'click', 'drag'}, 'normal', @orbit_camera, ...
                           {'click', 'drag'}, 'alt', @dolly_camera, ...
                           'click', 'open', @reset_camera, ...
                           'scroll', @zoom_camera);
  mmObject.enable(true);
  display(mmObject);

  % Nested functions:

  function orbit_camera(hObject, eventData)
    persistent orbitOrigin orbitScale
    switch eventData.operation
      case 'click'
        orbitOrigin = eventData.figurePoint;
        orbitScale = [360 180]./eventData.figureRegion(3:4);
      case 'drag'
        offset = orbitScale.*(orbitOrigin-eventData.figurePoint);
        orbitOrigin = eventData.figurePoint;
        camorbit(hObject, offset(1), offset(2));
    end
  end

  function dolly_camera(hObject, eventData)
    persistent dollyOrigin
    switch eventData.operation
      case 'click'
        dollyOrigin = eventData.figurePoint;
      case 'drag'
        offset = (dollyOrigin-eventData.figurePoint)./200;
        dollyOrigin = eventData.figurePoint;
        camdolly(hObject, offset(1), offset(2), 0);
    end
  end

  function zoom_camera(hObject, eventData)
    camzoom(hObject, 1-0.1*eventData.scrollEventData.VerticalScrollCount);
  end

  function reset_camera(hObject, ~)
    set(hObject, 'CameraPosition', [-10 -10 10], ...
                 'CameraTarget', [0 0 0], ...
                 'CameraUpVector', [0 0 1], ...
                 'CameraViewAngle', 30);
  end

end