% Vehicle：一台の状態と入出力を束ねる。

classdef Vehicle < handle
    properties (SetAccess = private)
        name string
        settings
        mode string
        source = []
        sink = []
        estimator = []
    end
    properties (Dependent)
        position
        orientation
        speed
        angularVelocity
    end
    properties (Access = private)
        clock
        closed logical = false
    end

    methods
        function obj = Vehicle(settings, mode, timeout)
            % 確定済みの一台分の設定と mode を受け取る。
            obj.name = string(settings.name);
            obj.settings = settings;
            obj.mode = string(mode);
            obj.clock = tic;
            try
                % simulation なら SimulatedVehicleIo を一つ作り、入力と出力で共有する。
                if obj.mode == "simulation"
                    simulator = station.SimulatedVehicleIo(settings);
                    obj.source = simulator;
                    obj.sink = simulator;
                else
                    % experiment なら、指定された方式の状態入力源と指令出力先を別々に作る。
                    switch string(settings.odometryInput.protocol)
                        case "ros"
                            obj.source = station.RosOdometrySource(settings.odometryInput, obj.clock);
                        case "udp"
                            obj.source = station.UdpOdometrySource(settings.odometryInput, obj.clock);
                    end
                    switch string(settings.commandOutput.protocol)
                        case "ros"
                            obj.sink = station.RosCommandSink(settings.commandOutput);
                        case "udp"
                            obj.sink = station.UdpCommandSink(settings.commandOutput);
                    end
                end
                % その後 StateEstimator を作り、初期位置と状態入力名を渡す。
                obj.estimator = station.StateEstimator(settings, timeout);
            % 途中で作成に失敗したら、先に開いた入力や出力を閉じて失敗を返す。
            catch exception
                obj.close();
                rethrow(exception)
            end
        end

        function poll(obj)
            sample = obj.source.read();
            if ~isempty(sample), obj.estimator.accept(sample); end
        end

        function [fresh, details] = hasFreshObservation(obj)
            obj.poll();
            details = obj.odometryDiagnostics();
            fresh = details.fresh;
        end

        function details = odometryDiagnostics(obj)
            details = obj.estimator.diagnostics(obj.now());
            if isa(obj.source, 'station.RosOdometrySource')
                details.ros = obj.source.diagnostics();
            end
        end

        % calibrate が呼ばれたら、入力源から届いた最新の有効な測定を調べる。
        % 測定がなければ失敗とし、あれば StateEstimator に基準を決めさせる。
        function calibrate(obj)
            obj.poll();
            obj.estimator.calibrate(obj.now());
        end

        % update(dt) では simulation なら最初に模擬車両を dt だけ進める。
        % 入力源から新しい測定を受け取り、あれば StateEstimator に渡す。
        % その時点の鮮度と [x, y, yaw, speed, angularVelocity] を返す。
        function [fresh, details] = update(obj, dt)
            if obj.mode == "simulation", obj.source.step(dt); end
            obj.poll();
            now = obj.now();
            fresh = obj.estimator.update(dt, now);
            if nargout > 1
                details = obj.estimator.diagnostics(now);
                if isa(obj.source, 'station.RosOdometrySource')
                    details.ros = obj.source.diagnostics();
                end
            end
        end

        function state = snapshot(obj)
            state = obj.estimator.snapshot();
        end

        % send(command) では二要素の指令を選択済みの出力先へ渡す。
        % 全台分の妥当性は StationRunner が送信前に検査済みとする。
        function sent = send(obj, command)
            assert(isnumeric(command) && isreal(command) && numel(command) == 2 && ...
                all(isfinite(command(:))), 'Station:InvalidCommands', ...
                'Invalid command for %s.', obj.name);
            sent = obj.sink.send(double(command(:).'));
        end

        % close ではゼロ指令を試み、入力源と出力先を両方閉じる。
        % 同じ SimulatedVehicleIo を二重に閉じず、失敗は車両名付きで上位へ返す。
        function errors = close(obj)
            errors = strings(0,1);
            if obj.closed, return; end
            obj.closed = true;
            if ~isempty(obj.sink)
                try
                    obj.sink.send([0 0]);
                catch exception
                    errors(end+1) = obj.name + ": stop: " + exception.message; %#ok<AGROW>
                end
            end
            if ~isempty(obj.source)
                try
                    obj.source.close();
                catch exception
                    errors(end+1) = obj.name + ": source: " + exception.message; %#ok<AGROW>
                end
            end
            if ~isempty(obj.sink) && ~isequal(obj.sink, obj.source)
                try
                    obj.sink.close();
                catch exception
                    errors(end+1) = obj.name + ": sink: " + exception.message; %#ok<AGROW>
                end
            end
            obj.source = [];
            obj.sink = [];
        end

        function delete(obj)
            obj.close();
        end

        function value = get.position(obj), value = obj.estimator.position; end
        function value = get.orientation(obj), value = obj.estimator.orientation; end
        function value = get.speed(obj), value = obj.estimator.speed; end
        function value = get.angularVelocity(obj), value = obj.estimator.angularVelocity; end
    end

    methods (Access = private)
        function time = now(obj)
            if obj.mode == "simulation"
                time = obj.source.currentTime;
            else
                time = toc(obj.clock);
            end
        end
    end
end
