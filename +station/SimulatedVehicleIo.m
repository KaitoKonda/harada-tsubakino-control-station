% SimulatedVehicleIo：PC 内の模擬車両を進める。

classdef SimulatedVehicleIo < handle
    properties (SetAccess = private)
        pose (1,3) double
        command (1,2) double = [0 0]
        currentTime double = 0
        sampleNumber double = 0
    end
    properties (Access = private)
        kind string
        deliveredNumber double = -1
    end

    methods
        function obj = SimulatedVehicleIo(settings)
            % 初期位置と方位を保持し、最後の指令を [0, 0] にする。
            % 滑り、センサ雑音、通信遅延は計算に含めない。
            obj.pose = double(settings.initialState);
            obj.kind = string(settings.odometryInput.kind);
            obj.step(0);
        end

        % send が呼ばれたら、受け取った速度と角速度を次の更新用に保持する。
        function sent = send(obj, command)
            obj.command = double(command(:).');
            sent = true;
        end

        % step(dt) が呼ばれたら、その指令で dt 秒分の平面運動を計算する。
        function step(obj, dt)
            validateattributes(dt, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'nonnegative'});
            v = obj.command(1);
            w = obj.command(2);
            yaw = obj.pose(3);
            % 角速度が十分小さければ直進式、それ以外なら旋回式で位置を進める。
            if abs(w) < 1e-10
                obj.pose(1:2) = obj.pose(1:2) + v * dt * [cos(yaw) sin(yaw)];
            else
                obj.pose(1:2) = obj.pose(1:2) + v/w * ...
                    [sin(yaw+w*dt)-sin(yaw), cos(yaw)-cos(yaw+w*dt)];
            end
            % 方位と模擬時刻も進め、今回の状態を新測定として保持する。
            obj.pose(3) = yaw + w * dt;
            obj.currentTime = obj.currentTime + dt;
            obj.sampleNumber = obj.sampleNumber + 1;
        end

        % read が呼ばれたら、その新測定と模擬時刻を返す。
        % 同じ測定を続けて読んでも、新しい測定番号を作らない。
        function sample = read(obj)
            sample = [];
            if obj.deliveredNumber == obj.sampleNumber, return; end
            if obj.kind == "position"
                value = struct('position', obj.pose(1:2).', ...
                    'orientation', obj.pose(3));
            else
                value = struct('speed', obj.command(1), ...
                    'angularVelocity', obj.command(2));
            end
            sample = struct('value', value, 'receivedAt', obj.currentTime, ...
                'number', obj.sampleNumber);
            obj.deliveredNumber = obj.sampleNumber;
        end

        % close では保持している指令をゼロにし、外部通信は何もしない。
        function close(obj)
            obj.command = [0 0];
        end
    end
end
