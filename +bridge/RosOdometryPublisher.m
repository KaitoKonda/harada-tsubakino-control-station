% RosOdometryPublisher：変換済みの位置を ROS に載せる。

classdef RosOdometryPublisher < handle
    properties (SetAccess = private)
        topic string
        publisher = []
        lastFrameNumber double = NaN
    end

    methods
        function obj = RosOdometryPublisher(topic)
            obj.topic = string(topic);
            % 対象トピックを受け取り、nav_msgs/Odometry publisher を作る。
            obj.publisher = rospublisher(char(obj.topic), 'nav_msgs/Odometry');
        end

        % publish が位置、姿勢、親/子フレーム名、新しいフレーム番号を受け取る。
        function sent = publish(obj, position, quaternion, frameId, childFrameId, frameNumber)
            sent = false;
            % 同じフレーム番号の再送でないかを確認する。
            % 成功した番号を覚え、同じ番号に新しい時刻を付けて再配信しない。
            if frameNumber == obj.lastFrameNumber, return; end
            % 新しい ROS メッセージを作り、Header.Stamp と両フレーム名を入れる。
            % 現行版は ROS 現在時刻を使う。計測時刻を使う変更は実測後に決める。
            message = rosmessage(obj.publisher);
            message.Header.Stamp = rostime('now');
            message.Header.FrameId = char(frameId);
            message.ChildFrameId = char(childFrameId);
            % Pose.Pose に位置と姿勢を入れる。
            % 計測していない速度を推定値として Twist へ書き込まない。
            message.Pose.Pose.Position.X = position(1);
            message.Pose.Pose.Position.Y = position(2);
            message.Pose.Pose.Position.Z = position(3);
            message.Pose.Pose.Orientation.X = quaternion(1);
            message.Pose.Pose.Orientation.Y = quaternion(2);
            message.Pose.Pose.Orientation.Z = quaternion(3);
            message.Pose.Pose.Orientation.W = quaternion(4);
            % send を呼び、その呼び出しの成功または失敗をブリッジへ返す。
            send(obj.publisher, message);
            obj.lastFrameNumber = frameNumber;
            sent = true;
        end

        % close が呼ばれたら publisher を解放し、共有 ROS マスターは止めない。
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
