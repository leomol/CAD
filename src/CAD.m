% CAD - CNC drawing toolbox.
% 
% CAD methods where pointer position shifts:
%      tooth - Draw teeth.
%       wave - Draw waves.
%       line - Draw lines.
% 
% CAD methods where pointer position remains unchanged:
%       slit - Draw slits.
%  rectangle - Draw squares with round corners.
%     circle - Draw circle with a given resolution.
% 
% CAD methods:
%       move - Move pointer location.
%      shift - Move pointer location relative to current position.
%      pivot - Set pivot.
%     rotate - Rotate around pivot.
%      merge - Merge with another CAD object.
%      close - Close drawing by joining last and first points.
%        cut - Interrupt drawing.
%     export - Export drawing as svg.

% 2021-07-06. Leonardo Molina.
% 2023-09-13. Last modified.
classdef CAD < handle & matlab.mixin.Copyable
    properties
        x
        y
    end

    properties (Dependent)
        cursor
    end
    
    properties (Access = private)
        pivotIndex
        beginIndex
        cursor0
        xPivot
        yPivot
        x0
        y0
    end
    
    methods
        function c = get.cursor(obj)
            c = obj.cursor0;
        end
    end
    
    methods (Access = public)
        function obj = CAD(x, y)
            if nargin == 0
                x = 0;
                y = 0;
            end
            obj.pivotIndex = 1;
            obj.beginIndex = 1;
            
            obj.cursor0.x = x;
            obj.cursor0.y = y;
            
            obj.xPivot = x;
            obj.yPivot = y;
            
            obj.x = zeros(1, 0);
            obj.y = zeros(1, 0);
            obj.x0 = zeros(1, 0);
            obj.y0 = zeros(1, 0);
        end

        function obj = merge(obj, varargin)
            % CAD.merge(other);
            % Merge with other CAD object at cursor.
            % 
            % CAD.merge(x, y, other);
            % Merge with other CAD object at given position.
            switch numel(varargin)
                case 1
                    [sx, sy, others] = deal(obj.cursor0.x, obj.cursor0.y, varargin{1});
                case 3
                    [sx, sy, others] = deal(varargin{:});
            end
            for other = others
                %n = numel(obj.x);
                %obj.pivotIndex = other.pivotIndex + n;
                %obj.beginIndex = other.beginIndex + n;
                %obj.cursor = other.cursor;
                %obj.xPivot = other.xPivot;
                %obj.yPivot = other.yPivot;
                obj.x0 = [obj.x0, sx + other.x0];
                obj.y0 = [obj.y0, sy + other.y0];
                obj.x = [obj.x, sx + other.x];
                obj.y = [obj.y, sy + other.y];
            end
        end

        function obj = tooth(obj, varargin)
            % CAD.tooth(code, n, width, height, kerf, <protrude>);
            % Draw teeth.
            % 
            % code: <direction><left-modifier><levels><right-modifier>[-+-+]
            % 
            %        direction: NnEeSsWw
            %   left-modifiers: [{|:
            %           levels: 4 digit combinations of 0's and 1's.
            %  right-modifiers: ]}|:
            % 
            %      ---------------------------
            %      | modifier | grow | line |
            %      ---------------------------
            %      |     |    |   n  |   y  |
            %      |     :    |   n  |   n  |
            %      |     [    |   y  |   y  |
            %      |     {    |   y  |   n  |
            %      |     ]    |   y  |   y  |
            %      |     }    |   y  |   n  |
            %      ---------------------------
            % 
            % CAD.tooth(code, width, height, kerf, <protrude>)
            % code: <direction><left-modifier><level><right-modifier>[-+-+]
            % 
            %        direction: NnEeSsWw
            %   left-modifiers: [{|:
            %            level: 0 or 1.
            %  right-modifiers: ]}|:
            % 
            % Example:
            %     h = 5;
            %     v = 9;
            %     width = 3;
            %     height = 1;
            %     kerf = 0.1;
            %     protrude = true;
            %     vars = {width, height, kerf, protrude};
            %     
            %     box = CAD();
            %     box.tooth('N|1011]', h, vars{:});
            %     box.tooth('E:1011]', v, vars{:});
            %     box.tooth('S:1001|', h, vars{:});
            %     box.tooth('W|1001|', v, vars{:});
            %     
            %     cla();
            %     plot(box.x, box.y);
            %     axis('equal');
            
            if ~islogical(varargin{end})
                kerf = varargin{end};
                varargin{end + 1} = kerf(end) >= 0;
            end
            
            switch numel(varargin)
                case 5
                    [code, width, heights, kerf, protrude] = deal(varargin{:});
                    n = 2;
                    width = width / 2;
                case 6
                    [code, n, width, heights, kerf, protrude] = deal(varargin{:});
            end
            if numel(heights) == 1
                heights = heights([1, 1, 1]);
            end
            if numel(code) < 7
                % E[1]++ ==> E[1111]++
                code = [code(1:2), code([3, 3, 3, 3]), code(4:end)];
            end
            
            [xs, ys] = toothInterface(code, n, width, heights, kerf, protrude);
            obj.x = [obj.x, xs + obj.cursor0.x];
            obj.y = [obj.y, ys + obj.cursor0.y];
            
            [xs, ys, xEnd, yEnd] = toothInterface(code, n, width, heights, 0, protrude);
            xs(end) = xEnd;
            ys(end) = yEnd;
            obj.x0 = [obj.x0, xs + obj.cursor0.x];
            obj.y0 = [obj.y0, ys + obj.cursor0.y];
            
            obj.move();
        end
        
        function obj = wave(obj, varargin)
            % CAD.wave(code, n, width, height, <resolution>, kerf);
            % 
            % Draw waves.
            % 
            % code: <direction><level>
            % 
            %        direction: NnEeSsWw
            %            level: 01/\
            % 
            % Example:
            %     n = 5;
            %     width = 5;
            %     height = 2;
            %     kerf = 0.5;
            %     
            %     model = CAD();
            %     model.wave('E0', n, width, height, 0);
            %     
            %     outer = CAD();
            %     outer.wave('E0', n, width, height, kerf);
            %     
            %     inner = CAD();
            %     inner.wave('e0', n, width, height, kerf);
            %     
            %     cla();
            %     hold('all');
            %     plot(model.x, model.y, '--', 'DisplayName', 'Model');
            %     plot(outer.x, outer.y, 'DisplayName', 'Outer');
            %     plot(inner.x, inner.y, 'DisplayName', 'Inner');
            %     legend('show');
            %     axis('equal');
            
            switch numel(varargin)
                case 5
                    [code, n, width, height, kerf] = deal(varargin{:});
                    resolution = 90;
                case 6
                    [code, n, width, height, resolution, kerf] = deal(varargin{:});
            end
            
            [xs, ys] = waveInterface(code, n, width, height, resolution, kerf);
            obj.x = [obj.x, xs + obj.cursor0.x];
            obj.y = [obj.y, ys + obj.cursor0.y];
            
            [xs, ys] = waveInterface(code, n, width, height, resolution, 0);
            obj.x0 = [obj.x0, xs + obj.cursor0.x];
            obj.y0 = [obj.y0, ys + obj.cursor0.y];
            
            obj.move();
        end
        
        function obj = line(obj, varargin)
            % CAD.line(code, width, kerf);
            % CAD.line(x, y, [xKerf, yKerf]);
            % 
            % Draw lines.
            % 
            %   code: <direction>[horizontalKerf]
            %        direction: NESW
            %        horizontalKerf: [--,-+,+-,++]
            %   
            % if horizontalKerf is missing:
            %   if kerf >= 0, line grows
            %   if kerf <  0, line shrinks
            % if direction is upper-case:
            %   if kerf >= 0, line shifts up
            %   if kerf <  0, line shifts down
            % if direction is lower-case:
            %   if kerf >= 0, line shifts down
            %   if kerf <  0, line shifts up
            % 
            % Using left-hand rule.
            % 
            % Example:
            %     w = 15;
            %     kerf = 0.1;
            % 
            %     cla();
            %     hold('all');
            %     axis('equal');
            % 
            %     block1 = CAD(0 * w, 0);
            %     block1.line('N', w, +kerf);
            %     block1.line('E', w, +kerf);
            %     block1.line('S', w, +kerf);
            %     block1.line('W', w, +kerf);
            %     plot(block1.x, block1.y, 'b');
            % 
            %     block2 = CAD(1 * w, 0);
            %     block2.line('N-+', w, +kerf);
            %     block2.line('E-+', w, +kerf);
            %     block2.line('S-+', w, +kerf);
            %     block2.line('W-+', w, +kerf);
            %     plot(block2.x, block2.y, 'b');
            % 
            %     block3 = CAD(2 * w, w);
            %     block3.line('s', w, +kerf);
            %     block3.line('e', w, +kerf);
            %     block3.line('n', w, +kerf);
            %     block3.line('w', w, +kerf);
            %     plot(block3.x, block3.y, 'b');
            % 
            %     block4 = CAD(3 * w, 0);
            %     block4.line('n-+', w, -kerf);
            %     block4.line('e-+', w, -kerf);
            %     block4.line('s-+', w, -kerf);
            %     block4.line('w-+', w, -kerf);
            %     plot(block4.x, block4.y, 'b');
            % 
            %     hole1 = CAD(0 * w, 0);
            %     hole1.line('N', w, -kerf);
            %     hole1.line('E', w, -kerf);
            %     hole1.line('S', w, -kerf);
            %     hole1.line('W', w, -kerf);
            %     plot(hole1.x, hole1.y, 'r--');
            % 
            %     hole2 = CAD(1 * w, w);
            %     hole2.line('s', w, -kerf);
            %     hole2.line('e', w, -kerf);
            %     hole2.line('n', w, -kerf);
            %     hole2.line('w', w, -kerf);
            %     plot(hole2.x, hole2.y, 'r--');
            % 
            %     hole3 = CAD(2 * w, w);
            %     hole3.line('s+-', w, -kerf);
            %     hole3.line('e+-', w, -kerf);
            %     hole3.line('n+-', w, -kerf);
            %     hole3.line('w+-', w, -kerf);
            %     plot(hole3.x, hole3.y, 'r--');
            % 
            %     hole4 = CAD(3 * w, 0);
            %     hole4.line('n+-', w, +kerf);
            %     hole4.line('e+-', w, +kerf);
            %     hole4.line('s+-', w, +kerf);
            %     hole4.line('w+-', w, +kerf);
            %     plot(hole4.x, hole4.y, 'r--');
            
            if ischar(varargin{1})
                [code, width, kerf] = deal(varargin{:});

                [xs, ys] = lineInterface(code, width, kerf);
                obj.x = [obj.x, xs + obj.cursor0.x];
                obj.y = [obj.y, ys + obj.cursor0.y];

                [xs, ys] = lineInterface(code, width, 0);
                obj.x0 = [obj.x0, xs + obj.cursor0.x];
                obj.y0 = [obj.y0, ys + obj.cursor0.y];
            else
                x2 = varargin{1};
                y2 = varargin{2};
                if numel(varargin) < 3
                    kerf = [0, 0];
                else
                    kerf = varargin{3};
                end
                obj.x = [obj.x, x2 + obj.cursor0.x + kerf(1)];
                obj.y = [obj.y, y2 + obj.cursor0.y + kerf(2)];
                obj.x0 = [obj.x0, x2 + obj.cursor0.x];
                obj.y0 = [obj.y0, y2 + obj.cursor0.y];
            end
            obj.move();
        end
        
        function obj = slit(obj, code, n, width, height, kerf)
            % CAD.slit(code, n, width, height, kerf);
            % 
            % Draw slits.
            % 
            % code: <direction><level>
            % 
            %        direction: NnEeSsWw
            %            level: 01
            % 
            % Example:
            %     n = 5;
            %     width = 3;
            %     height = 1;
            %     kerf = 0.1;
            %     vars = {width, height, kerf};
            %     
            %     even = CAD();
            %     even.slit('E0', n, vars{:});
            %     
            %     odd = CAD();
            %     odd.slit('E1', n, vars{:});
            %     odd.slit('N1', n, vars{:});
            %     odd.slit('n1', n, vars{:});
            %     
            %     cla();
            %     hold('all');
            %     plot(even.x, even.y);
            %     plot(odd.x, odd.y);
            %     axis('equal');
            
            [xs, ys] = slitInterface(code, n, width, height, kerf);
            obj.x = [obj.x, xs + obj.cursor0.x];
            obj.y = [obj.y, ys + obj.cursor0.y];
            
            [xs, ys] = slitInterface(code, n, width, height, 0);
            obj.x0 = [obj.x0, xs + obj.cursor0.x];
            obj.y0 = [obj.y0, ys + obj.cursor0.y];
        end
        
        function obj = rectangle(obj, varargin)
            % CAD.rectangle(width, height, kerf);
            % CAD.rectangle(width, height, radius, kerf);
            % CAD.rectangle(width, height, radius, resolution, kerf);
            % 
            % Draw a positive square with round corners.
            % 
            % Example:
            %     width = 5;
            %     height = 4;
            %     radius = 1;
            %     kerf = 0.1;
            %     
            %     sharp = CAD();
            %     sharp.rectangle(width, height, 0);
            %     
            %     outer = CAD();
            %     outer.rectangle(width, height, radius, +kerf);
            %     
            %     inner = CAD();
            %     inner.rectangle(width, height, radius, -kerf);
            %     
            %     cla();
            %     hold('all');
            %     plot(sharp.x, sharp.y, 'DisplayName', 'Reference');
            %     plot(inner.x, inner.y, 'DisplayName', 'Inner');
            %     plot(outer.x, outer.y, 'DisplayName', 'Outer');
            %     legend('show');
            %     axis('equal');
            
            switch numel(varargin)
                case 3
                    [width, height, kerf] = deal(varargin{:});
                    radius = 0;
                    resolution = 0;
                case 4
                    [width, height, radius, kerf] = deal(varargin{:});
                    resolution = round(max(90, 90 * radius / max(abs(width), abs(height))));
                case 5
                    [width, height, radius, resolution, kerf] = deal(varargin{:});
            end
            
            if numel(kerf) == 1
                kerf = [kerf, kerf];
            end
            
            [xs, ys] = rectangleInterface(width, height, radius, resolution, kerf);
            obj.x = [obj.x, xs + obj.cursor0.x];
            obj.y = [obj.y, ys + obj.cursor0.y];
            
            [xs, ys] = rectangleInterface(width, height, radius, resolution, [0, 0]);
            obj.x0 = [obj.x0, xs + obj.cursor0.x];
            obj.y0 = [obj.y0, ys + obj.cursor0.y];
        end
        
        function obj = arc(obj, varargin)
            % CAD.arc(direction, width, kerf)
            % CAD.arc(direction, width, degrees, kerf)
            % CAD.arc(direction, width, degrees, resolution, kerf)
            % CAD.arc(dx, dy, kerf)
            % CAD.arc(dx, dy, degrees, kerf)
            % CAD.arc(dx, dy, degrees, resolution, kerf)
            % 
            %    direction:
            %        N, E, S, W, NW, NE, SE, SW
            % 
            % Draw an arc that passes thru last and current points.
            % 
            % Example:
            %     width = 1;
            %     degrees = pi;
            %     kerf = 0.1;
            %     args = {degrees, kerf};
            %     
            %     sketch = CAD(x, y);
            %     sketch.arc('NE', width, args{:});
            %     
            %     cla();
            %     hold('all');
            %     plot(sketch.x, sketch.y, '-');
            %     axis('equal');
            
            switch numel(varargin)
                case 3
                    [parameter1, parameter2, kerf] = deal(varargin{:});
                    degrees = pi / 2;
                    resolution = 90;
                case 4
                    [parameter1, parameter2, degrees, kerf] = deal(varargin{:});
                    resolution = 90;
                case 5
                    [parameter1, parameter2, degrees, resolution, kerf] = deal(varargin{:});
            end
            
            if ischar(parameter1) || isstring(parameter1)
                [direction, width] = deal(parameter1, parameter2);
                [x2, y2] = direction2coordinate(direction, width);
            else
                [x2, y2] = deal(parameter1, parameter2);
            end
            [xs, ys] = arc(x2, y2, degrees, 1, resolution, kerf);
            obj.x = [obj.x, xs + obj.cursor0.x];
            obj.y = [obj.y, ys + obj.cursor0.y];

            [xs, ys] = arc(x2, y2, degrees, 1, resolution, 0);
            obj.x0 = [obj.x0, xs + obj.cursor0.x];
            obj.y0 = [obj.y0, ys + obj.cursor0.y];
            
            obj.move();
        end
        
        function obj = circle(obj, varargin)
            % CAD.circle(obj, radius, kerf)
            % CAD.circle(obj, radius, resolution, kerf)
            % CAD.circle(obj, x, y, radius, kerf)
            % CAD.circle(obj, x, y, radius, resolution, kerf)
            % 
            % Example:
            %     kerf = 0.1;
            %     radius = 1;
            %     x = 2 * (radius + kerf) * (-1:1);
            %     y = zeros(1, 3);
            %     
            %     reference = CAD(0, 0);
            %     reference.circle(radius, 0);
            %     outer = CAD(0, 0);
            %     outer.circle(x, y, radius, +kerf);
            %     inner = CAD(0, 0);
            %     inner.circle(x, y, radius, -kerf);
            %     
            %     cla();
            %     hold('all');
            %     plot(reference.x, reference.y, '-', 'DisplayName', 'Reference');
            %     plot(outer.x, outer.y, '-', 'DisplayName', 'Outer');
            %     plot(inner.x, inner.y, '-', 'DisplayName', 'Inner');
            %     legend('show');
            %     axis('equal');
            
            switch numel(varargin)
                case 2
                    [radius, kerf] = deal(varargin{:});
                    xs = 0;
                    ys = 0;
                    resolution = 360;
                case 3
                    [radius, resolution, kerf] = deal(varargin{:});
                    xs = 0;
                    ys = 0;
                case 4
                    [xs, ys, radius, kerf] = deal(varargin{:});
                    resolution = 360;
                case 5
                    [xs, ys, radius, resolution, kerf] = deal(varargin{:});
            end
            
            [xs1, ys1] = circleInterface(xs, ys, radius, resolution, kerf);
            obj.x = [obj.x, xs1 + obj.cursor0.x];
            obj.y = [obj.y, ys1 + obj.cursor0.y];
            
            [xs0, ys0] = circleInterface(xs, ys, radius, resolution, 0);
            obj.x0 = [obj.x0, xs0 + obj.cursor0.x];
            obj.y0 = [obj.y0, ys0 + obj.cursor0.y];
        end
        
        function obj = flex(obj, code, width, height, count, margin)
            % CAD.flex(code, width, height, count, margin)
            % code: [NESW]<[01]>
            % 
            % Create cuts for live hinges.
            % 
            % Example:
            %     width = 10;
            %     height = 5;
            %     count = 6;
            %     margin = 2;
            %     sketch = CAD();
            %     sketch.flex('E0', width, height, count, margin);
            %     
            %     cla();
            %     plot(sketch.x, sketch.y)
            %     axis('equal');
            
            direction = code(1);
            start = code(2) == '1';
            xs = NaN;
            ys = NaN;
            dy = height / count;
            dx = width - 2 * margin;
            for i = 0:count
                offset = i * dy;
                if mod(i + start, 2) ~= 0
                    xs = cat(2, xs, margin, margin + dx, NaN);
                    ys = cat(2, ys, offset, offset, NaN);
                else
                    xs = cat(2, xs, 0, 0.5 * dx, NaN, 0.5 * dx + 2 * margin, width, NaN);
                    ys = cat(2, ys, offset, offset, NaN, offset, offset, NaN);
                end
            end
            
            angles = [0, 90, 180, 270] / 180 * pi;
            angle = angles(ismember('ENWS', direction));
            [xs, ys] = rotate(angle, xs, ys);
            
            obj.x = [obj.x, xs + obj.cursor0.x];
            obj.y = [obj.y, ys + obj.cursor0.y];
            obj.x0 = [obj.x0, xs + obj.cursor0.x];
            obj.y0 = [obj.y0, ys + obj.cursor0.y];
        end
        
        function obj = move(obj, varargin)
            % CAD.move(x, y)
            % Move pointer to absolute (x, y) coordinates.
            
            switch numel(varargin)
                case 0
                    k = find(~isnan(obj.x0) & ~isnan(obj.y0), 1, 'last');
                    [obj.cursor0.x, obj.cursor0.y] = deal(obj.x0(k), obj.y0(k));
                case 2
                    [obj.cursor0.x, obj.cursor0.y] = deal(varargin{1}, varargin{2});
            end
        end
        
        function obj = shift(obj, dx, dy)
            % CAD.shift(dx, dy)
            % Move pointer by an amount (dx, dy).
            
            obj.move(obj.cursor0.x + dx, obj.cursor0.y + dy);
        end
        
        function obj = append(obj, x, y, x0, y0)
            % CAD.append(x, y, x0, y0)
            % Append data with and without kerf relative to cursor.
            if nargin == 1
                obj.x = [obj.x, obj.cursor0.x];
                obj.y = [obj.y, obj.cursor0.y];
                obj.x0 = [obj.x, obj.cursor0.x];
                obj.y0 = [obj.y, obj.cursor0.y];
            else
                obj.x = [obj.x, x + obj.cursor0.x];
                obj.y = [obj.y, y + obj.cursor0.y];
                obj.x0 = [obj.x0, x0 + obj.cursor0.x];
                obj.y0 = [obj.y0, y0 + obj.cursor0.y];
            end
        end
        
        function obj = pivot(obj, varargin)
            obj.pivotIndex = numel(obj.x0) + 1;
            if nargin > 1
                [obj.xPivot, obj.yPivot] = deal(varargin{:});
            else
                [obj.xPivot, obj.yPivot] = deal(obj.cursor0.x, obj.cursor0.y);
            end
        end
        
        function obj = begin(obj)
            obj.beginIndex = numel(obj.x0) + 1;
        end
        
        function obj = rotate(obj, angle)
            % CAD.rotate(angle)
            % Rotate drawing starting on pivot.
            
            % CAD selection.
            xs0 = obj.x0(obj.pivotIndex:end);
            ys0 = obj.y0(obj.pivotIndex:end);
            
            % Rotate reference drawing.
            [xs, ys] = rotate(angle, xs0 - obj.xPivot, ys0 - obj.yPivot);
            obj.x0(obj.pivotIndex:end) = xs + obj.xPivot;
            obj.y0(obj.pivotIndex:end) = ys + obj.yPivot;
            
            % Rotate drawing with kerf.
            xs = obj.x(obj.pivotIndex:end);
            ys = obj.y(obj.pivotIndex:end);
            [xs, ys] = rotate(angle, xs - obj.xPivot, ys - obj.yPivot);
            obj.x(obj.pivotIndex:end) = xs + obj.xPivot;
            obj.y(obj.pivotIndex:end) = ys + obj.yPivot;
        end
        
        function obj = close(obj)
            % CAD.close()
            % Close drawing by joining last and first points.
            
            if numel(obj.x) > 0
                obj.x = [obj.x, obj.x(obj.beginIndex)];
                obj.y = [obj.y, obj.y(obj.beginIndex)];

                obj.x0 = [obj.x0, obj.x0(obj.beginIndex)];
                obj.y0 = [obj.y0, obj.y0(obj.beginIndex)];
            end
        end
        
        function obj = cut(obj)
            % CAD.cut()
            % Interrupt drawing.
            
            obj.x = [obj.x, NaN];
            obj.y = [obj.y, NaN];
            
            obj.x0 = [obj.x0, NaN];
            obj.y0 = [obj.y0, NaN];
            
            obj.begin();
        end
        
        function export(obj, filename, container)
            % SVG drawings.
            xlims = [min(obj.x, [], 'omitnan'), max(obj.x, [], 'omitnan')];
            ylims = [min(obj.y, [], 'omitnan'), max(obj.y, [], 'omitnan')];
            dims = [diff(xlims), diff(ylims)];
            if nargin == 3
                svg = sprintf('<rect x="0" y="0" width="%.4f" height="%.4f"/>\r\n', container(1), container(2));
            else
                svg = '';
            end
            k = unique([0, find(isnan(obj.x)), numel(obj.x) + 1]);
            n = numel(k);
            for i = 1:n-1
                range = k(i) + 1:k(i+1) - 1;
                if numel(range) >= 2
                    svg = sprintf('%s\t<path d="M%.4f,%.4f%s"></path>\r\n', svg, obj.x(range(1)), obj.y(range(1)), sprintf(' L%.4f,%.4f', [obj.x(range(2:end)); obj.y(range(2:end))]));
                end
            end
            xmlHeader = '<?xml version="1.0" encoding="utf-8"?>';
            svgHeader = 'xmlns="http://www.w3.org/2000/svg"';
            viewBox = sprintf(' viewBox="%.4f %.4f %.4f %.4f"', xlims(1), ylims(1), dims(1), dims(2));
            svg = sprintf('%s\r\n<svg %s width="%.4fmm" height="%.4fmm"%s>\r\n<g>\r\n%s</g>\r\n</svg>', xmlHeader, svgHeader, dims(1), dims(2), viewBox, svg);
            fid = fopen(filename, 'w');
            fprintf(fid, svg);
            fclose(fid);
        end
    end
    
    methods (Static)
        function [x, y] = Tooth(widths, levels, scale, ends, kerf, protrude, kerfModifier)
            % [x, y] = CAD.Tooth(widths, levels, scale, ends, kerf, <protrude>);
            % 
            % Example:
            %     scale = 2;
            %     levels = [0.5, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1];
            %     widths = ones(size(levels));
            %     ends = [true, true];
            %     kerf = 0.1;
            %     protrude = true;
            %     [x, y] = CAD.Tooth(widths, levels, scale, ends, kerf, protrude);
            %     plot(x, y, '-x');
            
            if numel(kerf) == 1
                kerf = [kerf, kerf];
            end
            
            % Find level changes.
            deltas = [0, diff(levels)];
            fall = find(deltas < 0);
            rise = find(deltas > 0);
            
            if nargin < 7
                kerfModifier = [1, 1];
            end
            
            % Kerf is added at peaks and subtracted at valleys.
            widths(fall) = widths(fall) - kerf(1);
            widths(fall - 1) = widths(fall - 1) + kerf(1);
            widths(rise) = widths(rise) + kerf(1);
            widths(rise - 1) = widths(rise - 1) - kerf(1);
            
            % Start with 3 points per trace (vertical + horizontal lines).
            nStates = numel(levels);
            dx = [zeros(2, nStates); widths];
            dy = [deltas; zeros(2, nStates)];
            
            % Keep all three points when there is a state change. Keep last point otherwise.
            dk = [deltas ~= 0; deltas ~= 0; true(size(levels))];
            dx = dx(dk)';
            dy = dy(dk)';
            
            % x/y are reflected by changes in dx/dy.
            x = [0, cumsum(dx)];
            y = cumsum([levels(1), dy]) * scale + kerf(2);
            
            % Outer kerf pushes outwards/inwards when teeth are protruding/intruding.
            if protrude
                x([1, end]) = x([1, end]) + [-kerf(1) * kerfModifier(1), +kerf(1) * kerfModifier(2)];
            else
                x([1, end]) = x([1, end]) + [+kerf(1) * kerfModifier(1), -kerf(1) * kerfModifier(2)];
                y = y - scale;
            end
            
            % Add outer, vertical lines when necessary and if requested.
            if ends(1) && y(1) ~= kerf(2)
                x = [x(1), x];
                y = [kerf(2), y];
            end
            if ends(end) && y(end) ~= kerf(2)
                x = [x, x(end)];
                y = [y, kerf(2)];
            end
        end
        
        function [x, y] = Slit(widths, levels, height, kerf)
            % [x, y] = CAD.Slit(widths, levels, height, kerf);
            %
            % Example:
            %     widths = [3, 1, 1, 1, 1, 1, 1];
            %     levels = [1, 0, 0, 1, 1, 0, 1];
            %     height = 1;
            %     kerf = 0.1;
            % 
            %     [x, y] = CAD.Slit(widths, levels, height, kerf);
            %     plot(x, y, '-x');
            
            if numel(kerf) == 1
                kerf = [kerf, kerf];
            end
            
            [from, to] = ranges(levels);
            widths = arrayfun(@(i) sum(widths(from(i):to(i))), 1:numel(from));
            b = cumsum(widths);
            a = [0, b(1:end - 1)];
            if levels(1)
                a = a(1:2:end);
                b = b(1:2:end);
            else
                a = a(2:2:end);
                b = b(2:2:end);
            end
            n = numel(a);
            x = arrayfun(@(i) [NaN, a(i) + kerf(1), a(i) + kerf(1), b(i) - kerf(1), b(i) - kerf(1), a(i) + kerf(1)], 1:n, 'UniformOutput', false);
            x = [x{:}];
            y = [NaN, +kerf(2), height - kerf(2), height - kerf(2), +kerf(2), +kerf(2)];
            y = repmat(y, 1, n);
        end
    end
end

function [x2, y2] = rotate(angle, x, y)
    cosR = cos(angle);
    sinR = sin(angle);
    x2 = x * cosR - y * sinR;
    y2 = y * cosR + x * sinR;
end

function [xs, ys, xEnd, yEnd] = toothInterface(code, n, width, heights, kerf, protrude)
    modifiers = code(2:end);
    direction = code(1);
    angles = [0, 90, 180, 270] / 180 * pi;
    angle = angles(ismember('ENWS', upper(direction)));
    mirror = ismember(direction, 'enws');

    kerf = abs(kerf);
    modifierL = modifiers(1);
    modifierR = modifiers(6);
    steps = modifiers(2:5);

    lineL = ismember(modifierL, '[|]');
    lineR = ismember(modifierR, '[|]');
    growL = ismember(modifierL, '[{}]');
    growR = ismember(modifierR, '[{}]');
    pushL = ismember(modifierL, ']}');
    pushR = ismember(modifierR, '[{');
    
    kerfModifier = [1, 1];
    if numel(modifiers) > 6
        if modifiers(7) == '-'
            kerfModifier(1) = -1;
        end
        if modifiers(8) == '-'
            kerfModifier(2) = -1;
        end
    end
    
    heightL = heights(1);
    heightC = heights(2);
    heightR = heights(3);
    scale = heightC;

    widths = repmat(width, 1, n);
    length = n * width;
    k = 0;
    if growL
        widths = [heightL, widths];
    end
    if growR
        widths = [widths, heightR];
        if pushR
            length = length + heightR;
        end
    end
    levels = false(size(widths));
    levels([1, 2, end - 1, end]) = steps(1:4) == '1';
    levels(3:end - 2) = mod(0:numel(levels) - 5, 2) == levels(2);
    [xs, ys] = CAD.Tooth(widths, levels, scale, [lineL, lineR], kerf, protrude, kerfModifier);
    if growL && ~pushL
        xs = xs - heightL;
    end

    % Rotate.
    if mirror
        ys = -ys;
    end

    [xs, ys] = rotate(angle, xs, ys);
    [xEnd, yEnd] = rotate(angle, length, 0);
end

function [xs, ys] = waveInterface(code, n, width, height, resolution, kerf)
    xs = linspace(0, 2 * n * pi, n * resolution);
    level = code(2);
    switch level
        case '0'
            angleOffset = -0.5 * pi;
            yShift = 1;
        case '1'
            angleOffset = +0.5 * pi;
            yShift = 1;
        case '/'
            angleOffset = 0;
            yShift = 0;
        case '\'
            angleOffset = pi;
            yShift = 0;
    end
    cosx = cos(xs + angleOffset);
    sinx = sin(xs + angleOffset);
    ys = sinx;

    dy = 1 ./ sqrt((cosx .* cosx) + 1);
    dx = -cosx .* dy;

    % Rotate.
    direction = code(1);
    if ismember(direction, 'enws')
        dx = -dx;
        dy = -dy;
    end
    ys = 0.5 * height * (ys + yShift) + kerf * dy;
    xs = 0.5 * xs / pi * width + kerf * dx;

    angles = [0, 90, 180, 270] / 180 * pi;
    angle = angles(ismember('ENWS', upper(direction)));
    [xs, ys] = rotate(angle, xs, ys);
end

function [xs, ys] = lineInterface(code, width, kerf)
    direction = code(1);
    
    if numel(code) == 1
        hKerf = [-kerf, +kerf];
    else
        if code(2) == '+'
            hKerf(1) = +abs(kerf);
        else
            hKerf(1) = -abs(kerf);
        end
        if code(3) == '+'
            hKerf(2) = +abs(kerf);
        else
            hKerf(2) = -abs(kerf);
        end
    end

    if ismember(direction, 'ENWS')
        vKerf = +kerf;
    else
        vKerf = -kerf;
    end

    angles = [0, 90, 180, 270] / 180 * pi;
    angle = angles(ismember('ENWS', upper(direction)));

    xs = [hKerf(1), width + hKerf(2)];
    ys = [+vKerf, +vKerf];
    [xs, ys] = rotate(angle, xs, ys);
end

function [xs, ys] = slitInterface(code, n, width, height, kerf)
        if numel(kerf) == 1
            kerf = [kerf, kerf];
        end
        
        % Template slit.
        xs = [NaN, +kerf(1), +kerf(1), width - kerf(1), width - kerf(1), +kerf(1)]';
        ys = [NaN, +kerf(2), height - kerf(2), height - kerf(2), +kerf(2), +kerf(2)]';

        level = code(2) == '1';
        if level
            n = ceil(n / 2);
        else
            n = floor(n / 2);
        end
        xs = xs + 2 * width * (0:n - 1);
        ys = repmat(ys, 1, n);
        xs = xs(:)';
        ys = ys(:)';

        % Offset according to level 1.
        if level == 0
            xs = xs + width;
        end

        % Cut.
        xs = [xs, NaN];
        ys = [ys, NaN];

        % Rotate.
        direction = code(1);
        if ismember(direction, 'enws')
            ys = -ys;
        end
        angles = [0, 90, 180, 270] / 180 * pi;
        angle = angles(ismember('ENWS', upper(direction)));
        [xs, ys] = rotate(angle, xs, ys);
end

function [xs, ys] = rectangleInterface(width, height, radius, resolution, kerf)
    mirrorX = sign(width) == -1;
    mirrorY = sign(height) == -1;
    width = abs(width);
    height = abs(height);
    
    if radius > 0 && resolution >= 2
        % Round corners.
        ss = linspace(-pi, -0.5 * pi, resolution)';
        ss = [ss, ss + 0.5 * pi, ss + 1.0 * pi, ss + 1.5 * pi];
        xs = radius * sin(ss);
        ys = radius * cos(ss);
        % Align corners and apply kerf.
        xs(:, [1, 2]) = xs(:, [1, 2]) + radius - kerf(1);
        xs(:, [3, 4]) = xs(:, [3, 4]) - radius + kerf(1);
        ys(:, [1, 4]) = ys(:, [1, 4]) + radius - kerf(2);
        ys(:, [2, 3]) = ys(:, [2, 3]) - radius + kerf(2);
        % Move corner 2 to N.
        ys(:, 2) = ys(:, 2) + height;
        % Move corner 3 to NE.
        xs(:, 3) = xs(:, 3) + width;
        ys(:, 3) = ys(:, 3) + height;
        % Move corner 4 to E.
        xs(:, 4) = xs(:, 4) + width;
        % Close drawing.
        xs = [xs(:); xs(1)]';
        ys = [ys(:); ys(1)]';
    else
        % Sharp corners.
        xs = [-kerf(1), -kerf(1), width + kerf(1), width + kerf(1), -kerf(1)];
        ys = [-kerf(2), height + kerf(2), height + kerf(2), -kerf(2), -kerf(2)];
    end

    % Mirror.
    if mirrorX
        xs = xs - width;
    end
    if mirrorY
        ys = ys - height;
    end

    % Cut.
    xs = [NaN, xs, NaN];
    ys = [NaN, ys, NaN];
end

function [x, y] = direction2coordinate(direction, width)
    switch direction
        case 'N'
            x = 0;
            y = +width;
        case 'E'
            x = +width;
            y = 0;
        case 'S'
            x = 0;
            y = -width;
        case 'W'
            x = -width;
            y = 0;
        case 'NW'
            x = -width;
            y = +width;
        case 'NE'
            x = +width;
            y = +width;
        case 'SE'
            x = +width;
            y = -width;
        case 'SW'
            x = -width;
            y = -width;
    end
end

function [xs, ys] = circleInterface(xs, ys, radius, resolution, kerf)
    % Generate/replicate.
    radius = radius + kerf;
    ts = [linspace(-pi, pi, resolution)'; NaN];
    xs = xs(:)' + radius * sin(ts);
    ys = ys(:)' + radius * cos(ts);
    xs = xs(:)';
    ys = ys(:)';
end

function [xs, ys] = arc(x2, y2, degrees, proportion, resolution, kerf)
    mirror = sign(degrees) == -1;
    degrees = abs(degrees);
    
    width = sqrt(x2 ^ 2 + y2 ^ 2);
    radius = width / (2 * sin(degrees / 2));
    theta0 = degrees / 2;
    theta1 = theta0 - 2 * abs(proportion) * theta0;
    ts = linspace(theta0, theta1, resolution) + pi / 2;
    xs = (radius + kerf) * cos(ts) + width / 2;
    ys = (radius + kerf) * sin(ts) - radius * cos(theta0);
    
    if mirror
        ys = -ys;
    end
    
    angle = atan2(y2, x2);
    [xs, ys] = rotate(angle, xs, ys);
end

function [from, to] = ranges(data)
    data = data(:);
    if isempty(data)
        from = [];
        to = [];
    else
        m = cat(1, find(diff(data)), numel(data));
        counts = cat(1, m(1), diff(m));
        to = cumsum(counts);
        from = [0; to(1:end - 1)] + 1;
    end
end