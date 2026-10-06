% StationWindow：利用者の操作を状態に変える。

classdef StationWindow < handle
    properties (SetAccess = private)
        figureHandle = []
    end
    properties (Access = private)
        started logical = false
        stopRequested logical = false
    end

    methods
        function obj = StationWindow(mode, names)
            % 画面を作り、対象車両名と現在の段階を表示する。
            % 開始時は started=false、stopRequested=false としておく。
            % 接続と座標初期化が終わってから画面を作り、Start を表示する。
            % この画面から車両へ指令を送らず、状態変更だけを伝える。
            obj.started = string(mode) == "simulation";
            obj.figureHandle = figure('Name', 'Control station', ...
                'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                'Position', [200 200 480 180], ...
                'CloseRequestFcn', @(~,~) obj.requestStop());
            uicontrol(obj.figureHandle, 'Style', 'text', ...
                'Position', [20 135 440 25], ...
                'String', char(string(mode) + " | " + strjoin(string(names), ", ")));
            if string(mode) == "experiment"
                guidance = 'Startで制御を開始します。Stopまたは閉じると中止します。';
            else
                guidance = 'シミュレーション中です。Stopまたは閉じると停止します。';
            end
            uicontrol(obj.figureHandle, 'Style', 'text', ...
                'Position', [20 85 440 40], 'String', guidance);
            startButton = uicontrol(obj.figureHandle, 'Style', 'pushbutton', ...
                'String', 'Start', 'Position', [60 25 140 45], ...
                'Callback', @(button,~) obj.requestStart(button));
            if obj.started, set(startButton, 'Enable', 'off'); end
            uicontrol(obj.figureHandle, 'Style', 'pushbutton', ...
                'String', 'Stop', 'Position', [240 25 140 45], ...
                'Callback', @(~,~) obj.requestStop());
        end

        % StationRunner から問い合わせられたら、現在の二つの値を返す。
        function value = isStarted(obj)
            drawnow limitrate;
            value = obj.started;
        end

        % 画面が既に消えていれば stopRequested=true として返す。
        function value = shouldStop(obj)
            drawnow limitrate;
            value = obj.stopRequested || ~isgraphics(obj.figureHandle);
        end

        % 実行終了を告げられたら、残っている画面を閉じる。
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

    methods (Access = private)
        % 実機の待機段階で Start が押されたら started=true にする。
        function requestStart(obj, button)
            obj.started = true;
            set(button, 'Enable', 'off');
        end

        % Stop が押されたら stopRequested=true にする。
        % 画面の閉じる操作でも stopRequested=true にする。
        function requestStop(obj)
            obj.stopRequested = true;
        end
    end
end
