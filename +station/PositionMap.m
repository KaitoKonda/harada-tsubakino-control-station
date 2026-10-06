% PositionMap：車両の推定位置と向きを共通の二次元座標軸に表示する。

classdef PositionMap < handle
    properties (SetAccess = private)
        figureHandle = []
    end
    properties (Access = private)
        axesHandle = []
        names string
        markers = []
        headings = []
        labels = []
    end

    methods
        function obj = PositionMap(names)
            % 一台につき点、進行方向の矢印、車両名を一組ずつ作る。
            % 画面を閉じても制御は止めず、以後の描画だけをやめる。
            obj.names = string(names);
            obj.figureHandle = figure('Name', 'Vehicle position map', ...
                'NumberTitle', 'off', 'Position', [700 200 640 560], ...
                'CloseRequestFcn', @(~,~) obj.close());
            obj.axesHandle = axes('Parent', obj.figureHandle);
            hold(obj.axesHandle, 'on');
            grid(obj.axesHandle, 'on');
            axis(obj.axesHandle, 'equal');
            xlabel(obj.axesHandle, 'x [m]');
            ylabel(obj.axesHandle, 'y [m]');
            title(obj.axesHandle, '車両の位置と向き');
            xlim(obj.axesHandle, [-2 2]);
            ylim(obj.axesHandle, [-2 2]);
            obj.markers = gobjects(1, numel(obj.names));
            obj.headings = gobjects(1, numel(obj.names));
            obj.labels = gobjects(1, numel(obj.names));
            colors = lines(numel(obj.names));
            for index = 1:numel(obj.names)
                color = colors(index,:);
                obj.markers(index) = plot(obj.axesHandle, NaN, NaN, 'o', ...
                    'MarkerSize', 10, 'LineWidth', 1.5, ...
                    'MarkerEdgeColor', color, 'MarkerFaceColor', color);
                obj.headings(index) = quiver(obj.axesHandle, NaN, NaN, ...
                    NaN, NaN, 0, 'Color', color, 'LineWidth', 2, ...
                    'MaxHeadSize', 1.5);
                obj.labels(index) = text(obj.axesHandle, NaN, NaN, ...
                    char(obj.names(index)), 'Color', color, ...
                    'FontWeight', 'bold', 'Interpreter', 'none');
            end
            hold(obj.axesHandle, 'off');
        end

        function update(obj, states)
            % StationRunner が確定した状態 [x,y,theta,v,omega] を順番どおり受け取る。
            % 新しい点だけを移し、描画物を周期ごとに作り直さない。
            if isempty(obj.figureHandle) || ~isgraphics(obj.figureHandle)
                return
            end
            poses = reshape(states, 5, []).';
            assert(size(poses,1) == numel(obj.names) && ...
                all(isfinite(poses(:,1:3)), 'all'), ...
                'Station:InvalidMapState', 'Map states must contain finite poses for all vehicles.');
            for index = 1:numel(obj.names)
                x = poses(index,1);
                y = poses(index,2);
                theta = poses(index,3);
                set(obj.markers(index), 'XData', x, 'YData', y);
                set(obj.headings(index), 'XData', x, 'YData', y, ...
                    'UData', 0.35*cos(theta), 'VData', 0.35*sin(theta));
                set(obj.labels(index), 'Position', [x+0.15, y+0.15, 0]);
            end
            % 車両が表示範囲の端へ近づいたら、余白を付けて軸を広げる。
            % 縮小はしないので、走行中に画面の縮尺が揺れない。
            xRange = xlim(obj.axesHandle);
            yRange = ylim(obj.axesHandle);
            xValues = poses(:,1);
            yValues = poses(:,2);
            if min(xValues) < xRange(1)+0.5 || max(xValues) > xRange(2)-0.5
                xlim(obj.axesHandle, [min(xRange(1), min(xValues)-1), ...
                    max(xRange(2), max(xValues)+1)]);
            end
            if min(yValues) < yRange(1)+0.5 || max(yValues) > yRange(2)-0.5
                ylim(obj.axesHandle, [min(yRange(1), min(yValues)-1), ...
                    max(yRange(2), max(yValues)+1)]);
            end
            drawnow limitrate;
        end

        function close(obj)
            if ~isempty(obj.figureHandle) && isgraphics(obj.figureHandle)
                delete(obj.figureHandle);
            end
            obj.figureHandle = [];
        end

        function delete(obj)
            obj.close();
        end
    end
end
