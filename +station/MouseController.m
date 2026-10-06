% MouseController：別ウィンドウの押下状態から全車両分の指令を作る。

classdef MouseController < handle
    properties (SetAccess = private)
        speed (1,1) double
        angularSpeed (1,1) double
        maxHoldSeconds (1,1) double
        figureHandle = []
    end
    properties (Access = private)
        vehicleNames string = strings(1,0)
        selected logical = false(1,0)
        direction string = ""
        directionNames string = ["forward", "backward", "left", "right"]
        directionBounds double = [185 125 70 45; 185 15 70 45; ...
            105 70 70 45; 265 70 70 45]
        statusHandle = []
        pressClock = []
        closed logical = false
    end

    methods
        function obj = MouseController(speed, angularSpeed, maxHoldSeconds)
            if nargin < 1, speed = 0.05; end
            if nargin < 2, angularSpeed = 0.2; end
            if nargin < 3, maxHoldSeconds = 10; end
            validateattributes(speed, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'positive'}, mfilename, 'speed');
            validateattributes(angularSpeed, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'positive'}, mfilename, 'angularSpeed');
            validateattributes(maxHoldSeconds, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'positive'}, mfilename, 'maxHoldSeconds');
            obj.speed = double(speed);
            obj.angularSpeed = double(angularSpeed);
            obj.maxHoldSeconds = double(maxHoldSeconds);
        end

        function commands = commands(obj, vehicles)
            % 通常の制御器と同じく、選択中の全車両に対する指令を毎周期返す。
            names = string(fieldnames(vehicles)).';
            if isempty(obj.vehicleNames)
                obj.vehicleNames = names;
                obj.selected = false(size(names));
                if ~obj.closed, obj.openWindow(); end
            else
                assert(isequal(sort(names), sort(obj.vehicleNames)), ...
                    'Station:ManualVehicleChanged', ...
                    'Selected vehicles changed while manual control was running.');
            end
            if obj.closed || isempty(obj.figureHandle) || ...
                    ~isgraphics(obj.figureHandle)
                commands = station.stopController(vehicles);
                return
            end
            % 解放イベントを取り逃がしても、連続押下の上限後はゼロへ戻す。
            if obj.direction ~= "" && ~isempty(obj.pressClock) && ...
                    toc(obj.pressClock) >= obj.maxHoldSeconds
                obj.direction = "";
                obj.pressClock = [];
                obj.updateStatus();
            end
            commands = station.MouseController.buildCommands(vehicles, ...
                obj.vehicleNames(obj.selected), obj.direction, ...
                obj.speed, obj.angularSpeed);
        end

        function close(obj)
            % 画面を閉じる前に方向と送信先を消し、以後の再表示を防ぐ。
            obj.direction = "";
            obj.pressClock = [];
            obj.selected(:) = false;
            obj.closed = true;
            if ~isempty(obj.figureHandle) && isgraphics(obj.figureHandle)
                delete(obj.figureHandle);
            end
            obj.figureHandle = [];
            obj.statusHandle = [];
        end

        function delete(obj)
            obj.close();
        end
    end

    methods (Static)
        function commands = buildCommands(vehicles, selectedNames, direction, speed, angularSpeed)
            % 全車両をゼロで始め、選択中の車両だけへ同じ方向指令を設定する。
            commands = station.stopController(vehicles);
            names = string(fieldnames(vehicles));
            selectedNames = string(selectedNames(:));
            assert(all(ismember(selectedNames, names)), ...
                'Station:ManualVehicleChanged', ...
                'Manual selection includes a vehicle outside this run.');
            switch string(direction)
                case "forward"
                    value = [speed 0];
                case "backward"
                    value = [-speed 0];
                case "left"
                    value = [0 angularSpeed];
                case "right"
                    value = [0 -angularSpeed];
                otherwise
                    return
            end
            for name = selectedNames.'
                commands.(char(name)) = value;
            end
        end
    end

    methods (Access = private)
        function openWindow(obj)
            % 実験の Start 後、制御器が初めて呼ばれたときだけ画面を作る。
            count = numel(obj.vehicleNames);
            columns = 3;
            rows = ceil(count / columns);
            height = 275 + 35 * rows;
            obj.figureHandle = figure('Name', 'Manual drive', ...
                'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                'Units', 'pixels', 'Position', [700 220 440 height], ...
                'Resize', 'off', ...
                'WindowButtonMotionFcn', @(~,~) obj.mouseMoved(), ...
                'WindowButtonUpFcn', @(~,~) obj.mouseUp(), ...
                'CloseRequestFcn', @(~,~) obj.close());
            uicontrol(obj.figureHandle, 'Style', 'text', 'Units', 'pixels', ...
                'Position', [20 height-35 400 25], ...
                'String', sprintf('送信先を選択。方向は押下中だけ（連続 %.0f 秒まで）。', ...
                    obj.maxHoldSeconds));
            for index = 1:count
                column = mod(index-1, columns);
                row = floor((index-1) / columns);
                uicontrol(obj.figureHandle, 'Style', 'togglebutton', ...
                    'Units', 'pixels', ...
                    'Position', [20+140*column height-80-35*row 120 30], ...
                    'String', char(obj.vehicleNames(index)), 'Value', 0, ...
                    'Callback', @(button,~) obj.toggleVehicle(index, button));
            end
            labels = {'前進', '後退', '左旋回', '右旋回'};
            for index = 1:numel(labels)
                direction = obj.directionNames(index);
                uicontrol(obj.figureHandle, 'Style', 'pushbutton', ...
                    'Units', 'pixels', 'Position', obj.directionBounds(index,:), ...
                    'String', labels{index}, 'Enable', 'inactive', ...
                    'ButtonDownFcn', @(~,~) obj.mouseDown(direction));
            end
            uicontrol(obj.figureHandle, 'Style', 'pushbutton', ...
                'Units', 'pixels', 'Position', [185 70 70 45], ...
                'String', '停止', 'Callback', @(~,~) obj.mouseUp());
            obj.statusHandle = uicontrol(obj.figureHandle, 'Style', 'text', ...
                'Units', 'pixels', 'Position', [20 185 400 30], ...
                'String', '送信先: なし | 指令: 停止');
        end

        function toggleVehicle(obj, index, button)
            % 送信先を変えた瞬間に前の方向入力を破棄する。
            obj.selected(index) = logical(get(button, 'Value'));
            obj.direction = "";
            obj.pressClock = [];
            obj.updateStatus();
        end

        function mouseDown(obj, direction)
            if obj.closed || ~isgraphics(obj.figureHandle), return; end
            obj.direction = "";
            obj.pressClock = [];
            if string(get(obj.figureHandle, 'SelectionType')) == "normal"
                obj.direction = direction;
                obj.pressClock = tic;
            end
            obj.updateStatus();
        end

        function mouseMoved(obj)
            % 押した方向ボタンからポインターが外れたら即座に指令を解除する。
            if obj.direction == "" || ~isgraphics(obj.figureHandle), return; end
            index = find(obj.directionNames == obj.direction, 1);
            point = get(obj.figureHandle, 'CurrentPoint');
            if ~obj.inside(point, obj.directionBounds(index,:))
                obj.direction = "";
                obj.pressClock = [];
                obj.updateStatus();
            end
        end

        function mouseUp(obj)
            obj.direction = "";
            obj.pressClock = [];
            obj.updateStatus();
        end

        function updateStatus(obj)
            if isempty(obj.statusHandle) || ~isgraphics(obj.statusHandle), return; end
            activeNames = obj.vehicleNames(obj.selected);
            if isempty(activeNames)
                targetText = "なし";
            else
                targetText = strjoin(activeNames, ", ");
            end
            if obj.direction == "", directionText = "停止";
            else, directionText = obj.direction;
            end
            set(obj.statusHandle, 'String', ...
                char("送信先: " + targetText + " | 指令: " + directionText));
        end

        function result = inside(~, point, bounds)
            result = point(1) >= bounds(1) && ...
                point(1) <= bounds(1)+bounds(3) && ...
                point(2) >= bounds(2) && point(2) <= bounds(2)+bounds(4);
        end
    end
end
