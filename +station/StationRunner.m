% StationRunner：一回の運転を進める。

classdef StationRunner < handle
    properties (SetAccess = private)
        vehicles = struct()
        controlWindow = []
        positionMap = []
        logger
        status string = "starting"
        errorText string = ""
    end
    properties (Access = private)
        mode string
        station
        experiment
        settings
        names string
        showUi logical
        waitForNextCycle logical
        finished logical = false
    end

    methods
        function obj = StationRunner(mode, stationSettings, experiment, settings, options)
            % 確定済み設定を受け取り、空の実行結果と RunLogger を作る。
            obj.mode = string(mode);
            obj.station = stationSettings;
            obj.experiment = experiment;
            obj.settings = settings;
            obj.names = string({settings.name});
            obj.showUi = logical(options.showUi);
            obj.waitForNextCycle = logical(options.waitForNextCycle);
            obj.logger = station.RunLogger(mode, stationSettings, experiment, settings, options.saveRunLog);
        end

        function result = run(obj)
            % 後のどの段階で失敗しても最後に停止処理へ入れるよう、終了処理を登録する。
            cleanup = onCleanup(@() obj.finish()); %#ok<NASGU>
            try
                % 実機で ROS を使うときだけ、既存接続の設定を調べて接続する。
                % マスターが使えるようになったら、利用者がローバを起動するまで待つ。
                % Enter 後に Vehicle を作るため、接続待ちの制限時間はここでは進まない。
                if obj.mode == "experiment" && ...
                        any(arrayfun(@(s) s.odometryInput.protocol == "ros" || ...
                        s.commandOutput.protocol == "ros", obj.settings))
                    shared.ensureRosSession(obj.station.ros);
                    fprintf('ROS マスターに接続しました。ローバと必要なブリッジを起動してください。\n');
                    input('起動を確認したら Enter キーを押してください: ', 's');
                end
                % 選択順に Vehicle を作る。途中の一台で失敗したら、作成済みの全台を閉じる。
                for setting = obj.settings
                    obj.vehicles.(char(setting.name)) = station.Vehicle(setting, obj.mode, ...
                        obj.station.odometryTimeoutSeconds);
                end
                if obj.mode == "experiment"
                    obj.waitForConnections();
                end
                % 全台に期限内の有効な状態が揃ったら、各 Vehicle の calibrate を呼ぶ。
                % simulation では模擬車両から初期測定を一回作り、待たずに calibrate する。
                for name = obj.names
                    obj.vehicles.(char(name)).calibrate();
                end
                % 画面を作り、実機なら standby に入る。
                if obj.showUi
                    obj.controlWindow = station.StationWindow(obj.mode, obj.names);
                    obj.positionMap = station.PositionMap(obj.names);
                    obj.updatePositionMap();
                end
                if obj.mode == "experiment"
                    obj.waitForStart();
                    if obj.status == "cancelled"
                        obj.finish();
                        result = obj.logger.result;
                        return
                    end
                end
                % simulation では実機接続も待機操作も行わず、初期化後に running に進む。
                obj.status = "running";
                obj.controlLoop();
                if obj.status == "running", obj.status = "completed"; end
            catch exception
                obj.status = "error";
                obj.errorText = string(exception.identifier) + ": " + exception.message;
                obj.finish();
                rethrow(exception)
            end
            obj.finish();
            % 実行結果を runControlStation へ返す。車両による指令受領までは保証しない。
            result = obj.logger.result;
        end

        function finish(obj)
            if obj.finished, return; end
            obj.finished = true;
            if ismember(obj.status, ["starting", "standby", "running"])
                obj.status = "interrupted";
            end
            % 終了処理では全台にゼロ指令を個別に試みる。
            % 一台の失敗を記録しても残りの車両を必ず試す。
            shutdownErrors = obj.stopAll();
            for name = obj.names
                field = char(name);
                if ~isfield(obj.vehicles, field), continue; end
                try
                    shutdownErrors = [shutdownErrors; ...
                        obj.vehicles.(field).close()]; %#ok<AGROW>
                catch exception
                    shutdownErrors(end+1,1) = name + ": close: " + ...
                        string(exception.message); %#ok<AGROW>
                end
            end
            % 操作用の別ウィンドウなどがあれば、制御器固有の終了処理を呼ぶ。
            if isfield(obj.experiment, 'cleanupController')
                try
                    obj.experiment.cleanupController();
                catch exception
                    shutdownErrors(end+1,1) = "controller: close: " + ...
                        string(exception.message); %#ok<AGROW>
                end
            end
            % 次に全資源と画面を閉じ、RunLogger へ終了理由とエラーを渡す。
            if ~isempty(obj.controlWindow), obj.controlWindow.close(); end
            if ~isempty(obj.positionMap), obj.positionMap.close(); end
            obj.logger.finish(obj.status, obj.errorText, shutdownErrors);
        end

        function delete(obj)
            obj.finish();
        end
    end

    methods (Access = private)
        % 接続待ちでは、各車両へゼロ指令を試み、状態入力を一台ずつ読む。
        % 制限時間を超えたら届かなかった車両名を示し、運転を始めず終了する。
        function waitForConnections(obj)
            started = tic;
            ready = false(1, numel(obj.names));
            while toc(started) < obj.station.connectionTimeoutSeconds
                errors = obj.stopAll();
                assert(isempty(errors), 'Station:StopFailed', ...
                    'Could not maintain zero commands during connection.');
                for index = 1:numel(obj.names)
                    ready(index) = obj.vehicles.(char(obj.names(index))).hasFreshObservation();
                end
                if all(ready), return; end
                pause(1/obj.station.controlRateHz);
            end
            error('Station:ConnectionTimeout', ...
                'No fresh odometry from: %s', strjoin(obj.names(~ready), ', '));
        end

        % standby 中はゼロ指令と状態更新を繰り返す。
        % Stop または画面を閉じる操作なら cancelled として終了する。
        % Start が押されたときだけ、時刻をゼロにして running に進む。
        function waitForStart(obj)
            obj.status = "standby";
            previous = tic;
            while ~obj.controlWindow.isStarted()
                if obj.controlWindow.shouldStop()
                    obj.status = "cancelled";
                    return
                end
                errors = obj.stopAll();
                assert(isempty(errors), 'Station:StopFailed', ...
                    'Could not maintain zero commands in standby.');
                dt = toc(previous);
                previous = tic;
                for name = obj.names
                    odometryFresh = obj.vehicles.(char(name)).update(dt);
                    assert(odometryFresh, 'Station:OdometryLost', ...
                        'Odometry lost during standby for %s.', name);
                end
                obj.updatePositionMap();
                pause(1/obj.station.controlRateHz);
            end
        end

        function controlLoop(obj)
            period = 1/obj.station.controlRateHz;
            elapsed = 0;
            started = tic;
            nextReport = 0;
            % running の一周期では、まず経過時間と前回からの時間差を求める。
            % Stop、予定時間到達、状態喪失、例外のいずれかでループを抜ける。
            while elapsed < obj.station.durationSeconds
                stepClock = tic;
                if obj.showUi && obj.controlWindow.shouldStop()
                    obj.status = "stopped";
                    break
                end
                if obj.mode == "simulation"
                    dt = min(period, obj.station.durationSeconds - elapsed);
                    elapsed = elapsed + dt;
                else
                    now = toc(started);
                    dt = now - elapsed;
                    elapsed = now;
                end
                count = numel(obj.names);
                states = zeros(1,5,count);
                odometryFresh = false(1,count);
                commandsArray = zeros(1,2,count);
                commandSent = false(1,count);
                % 選択順に全 Vehicle を update し、状態と odometryFresh を結果へ記録する。
                for index = 1:count
                    vehicle = obj.vehicles.(char(obj.names(index)));
                    odometryFresh(index) = vehicle.update(dt);
                    states(1,:,index) = vehicle.snapshot();
                end
                if obj.showUi, obj.positionMap.update(states); end
                % 一台でも odometryFresh が偽なら、その車両名を記録して odometryLost とする。
                if ~all(odometryFresh)
                    obj.status = "odometryLost";
                    obj.errorText = "No fresh odometry from: " + ...
                        strjoin(obj.names(~odometryFresh), ", ");
                    obj.logger.record(elapsed, states, odometryFresh, commandsArray, commandSent);
                    break
                end
                % そうでなければ制御則を一回呼び、全指令を validateCommands に渡す。
                % 検査に失敗した場合はこの周期の通常指令を一台にも送らない。
                commands = station.validateCommands( ...
                    obj.experiment.controller(obj.vehicles), obj.names, obj.station);
                for index = 1:count
                    % 検査に成功した場合だけ選択順に指令を送り、送信結果を記録する。
                    commandsArray(1,:,index) = commands.(char(obj.names(index)));
                end
                for index = 1:count
                    name = char(obj.names(index));
                    try
                        commandSent(index) = obj.vehicles.(name).send(commands.(name));
                    catch exception
                        obj.logger.record(elapsed, states, odometryFresh, commandsArray, commandSent);
                        rethrow(exception)
                    end
                end
                obj.logger.record(elapsed, states, odometryFresh, commandsArray, commandSent);
                if elapsed >= nextReport
                    fprintf('%s: %.1f / %.1f s (%d vehicles)\n', ...
                        obj.mode, elapsed, obj.station.durationSeconds, count);
                    % 次の表示は実行開始からの次の整数秒に合わせる。
                    nextReport = floor(elapsed) + 1;
                end
                % 続行する場合だけ、次の周期までの残り時間を待つ。
                if obj.waitForNextCycle
                    pause(max(0, period - toc(stepClock)));
                else
                    drawnow limitrate;
                end
            end
        end

        function errors = stopAll(obj)
            errors = strings(0,1);
            for name = obj.names
                field = char(name);
                if ~isfield(obj.vehicles, field), continue; end
                try
                    obj.vehicles.(field).send([0 0]);
                catch exception
                    errors(end+1,1) = name + ": " + ...
                        string(exception.message); %#ok<AGROW>
                end
            end
        end

        function updatePositionMap(obj)
            % 待機中にも位置を表示する。初回は calibrate 後の状態を描く。
            if isempty(obj.positionMap), return; end
            states = zeros(1,5,numel(obj.names));
            for index = 1:numel(obj.names)
                states(1,:,index) = obj.vehicles.(char(obj.names(index))).snapshot();
            end
            obj.positionMap.update(states);
        end
    end
end
