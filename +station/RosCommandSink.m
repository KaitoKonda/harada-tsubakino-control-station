% RosCommandSink：ROS へ指令を送る。

classdef RosCommandSink < handle
    properties (SetAccess = private)
        publisher = []
    end

    methods
        function obj = RosCommandSink(config)
            % 選択された指令トピックで Twist publisher を作る。
            obj.publisher = rospublisher(char(config.topic), ...
                'geometry_msgs/Twist', 'DataFormat', 'struct');
        end

        % send が [speed, angularVelocity] を受け取ったらメッセージを一つ作る。
        % ゼロ指令も同じ send を通して送る。
        function sent = send(obj, command)
            message = rosmessage(obj.publisher);
            % speed を Linear.X、angularVelocity を Angular.Z に入れる。
            % 他の速度成分はゼロのままにして送信する。
            message.Linear.X = command(1);
            message.Angular.Z = command(2);
            % ROS の送信呼び出しが成功したか失敗したかを Vehicle へ返す。
            % 車両の受領を ROS の送信成功から推定しない。
            send(obj.publisher, message);
            sent = true;
        end

        % close が呼ばれたら publisher を解放し、ROS マスターは止めない。
        function close(obj)
            if ~isempty(obj.publisher)
                delete(obj.publisher);
                obj.publisher = [];
            end
        end

        function delete(obj)
            obj.close();
        end
    end
end
