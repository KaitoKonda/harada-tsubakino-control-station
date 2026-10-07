% RosOdometrySource：ROS から測定を受け取る。

classdef RosOdometrySource < handle
    properties (SetAccess = private)
        subscriber = []
    end
    properties (Access = private)
        config
        clock
        latest = []
        sampleNumber double = 0
        deliveredNumber double = 0
        lastStamp double = NaN
        receivedCount double = 0
        rejectedStampCount double = 0
        rejectedValueCount double = 0
        lastMessageAt double = -Inf
    end

    methods
        function obj = RosOdometrySource(config, clock)
            obj.config = config;
            obj.clock = clock;
            % 選択されたトピックとメッセージ型を読み、subscriber を作る。
            obj.subscriber = rossubscriber(char(config.topic), ...
                char(config.messageType), @(~, message) obj.acceptMessage(message), ...
                'DataFormat', 'struct');
        end

        % Vehicle が read したら、前回の read 以降に新測定がある場合だけ返す。
        % 何も届いていなければ「新測定なし」を返す。
        function sample = read(obj)
            sample = [];
            if obj.sampleNumber == obj.deliveredNumber, return; end
            sample = obj.latest;
            obj.deliveredNumber = obj.sampleNumber;
        end

        function details = diagnostics(obj)
            details = struct('receivedCount', obj.receivedCount, ...
                'acceptedCount', obj.sampleNumber, ...
                'rejectedStampCount', obj.rejectedStampCount, ...
                'rejectedValueCount', obj.rejectedValueCount, ...
                'lastMessageAtSeconds', obj.lastMessageAt, ...
                'lastAcceptedStamp', obj.lastStamp);
        end

        % close が呼ばれたら subscriber を解放する。ROS 全体は止めない。
        function close(obj)
            if ~isempty(obj.subscriber)
                delete(obj.subscriber);
                obj.subscriber = [];
            end
        end

        function delete(obj)
            obj.close();
        end
    end

    methods (Access = private)
        % 有効な時刻ヘッダーが前回以前なら、新測定にしない。
        % ヘッダーがないメッセージは、受け取った実時刻で新旧を区別する。
        function acceptMessage(obj, message)
            obj.receivedCount = obj.receivedCount + 1;
            obj.lastMessageAt = toc(obj.clock);
            stamp = NaN;
            if isfield(message, 'Header')
                stamp = double(message.Header.Stamp.Sec) + ...
                    double(message.Header.Stamp.Nsec) * 1e-9;
                if ~isfinite(stamp) || stamp < 0 || ...
                        (stamp > 0 && stamp <= obj.lastStamp)
                    obj.rejectedStampCount = obj.rejectedStampCount + 1;
                    return
                end
            end
            % メッセージが届いたら、設定された位置入力か速度入力かを確認する。
            % 有効な測定だけを値、受信時刻、測定番号として保持する。
            value = obj.parseMessage(message);
            if isempty(value)
                obj.rejectedValueCount = obj.rejectedValueCount + 1;
                return
            end
            if isfinite(stamp) && stamp > 0, obj.lastStamp = stamp; end
            obj.sampleNumber = obj.sampleNumber + 1;
            obj.latest = struct('value', value, ...
                'receivedAt', toc(obj.clock), 'number', obj.sampleNumber);
        end

        function value = parseMessage(obj, message)
            value = [];
            % Pose2D は x、y、theta を直接読む。Odometry は位置とクォータニオンを読む。
            if string(obj.config.kind) == "position"
                if string(obj.config.messageType) == "geometry_msgs/Pose2D"
                    pose = double([message.X; message.Y; message.Theta]);
                    if all(isfinite(pose))
                        value = struct('position', pose(1:2), ...
                            'orientation', pose(3));
                    end
                    return;
                end
                % 非有限な値またはゼロ長のクォータニオンは採用しない。
                position = message.Pose.Pose.Position;
                orientation = message.Pose.Pose.Orientation;
                q = double([orientation.W orientation.X ...
                    orientation.Y orientation.Z]);
                p = double([position.X; position.Y]);
                if ~all(isfinite([q p.'])) || norm(q) <= eps, return; end
                q = q / norm(q);
                yaw = atan2(2*(q(1)*q(4)+q(2)*q(3)), ...
                    1-2*(q(3)^2+q(4)^2));
                value = struct('position', p, 'orientation', yaw);
            else
                % Odometry または Twist の速度入力なら前進速度と角速度を読む。
                if isfield(message, 'Twist')
                    twist = message.Twist.Twist;
                else
                    twist = message;
                end
                speed = double(twist.Linear.X);
                angular = double(twist.Angular.Z);
                if all(isfinite([speed angular]))
                    value = struct('speed', speed, 'angularVelocity', angular);
                end
            end
        end
    end
end
