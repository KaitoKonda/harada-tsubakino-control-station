classdef Vehicle < handle

    properties
        name         string
        protocol     string
        odometryType string
        position        (2,1) double = zeros(2,1)
        speed           (1,1) double = 0
        orientation     (1,1) double = 0
        angularVelocity (1,1) double = 0
        positionOffset    (2,1) double = zeros(2,1)
        orientationOffset (1,1) double = 0
        ROSSubscriber
        ROSPublisher
        UDPReceiver
        UDPSender
        receiveRaw function_handle
        receive    function_handle
        send       function_handle
    end

    methods
        % コンストラクタ
        % settings row format:
        % [name, protocol, odometryType, x0, y0, theta0, arg1, arg2, arg3, ...]
        function obj = Vehicle(settings)
            obj.name         = settings(1);
            obj.protocol     = settings(2);
            obj.odometryType = settings(3);
            obj.positionOffset     = double(settings(4:5));
            obj.orientationOffset  = double(settings(6));
            args = settings(7:end);

            switch obj.protocol
                case 'ROS'  % ROSで通信する場合

                    ROSSubscriberTopic = sprintf('/%s/%s', obj.name, args(1));
                    ROSPublisherTopic  = sprintf('/%s/%s', obj.name, args(2));
                    ROSSubscriberMessageType = args(3);

                    obj.ROSSubscriber = rossubscriber(ROSSubscriberTopic, ROSSubscriberMessageType);
                    obj.ROSPublisher  = rospublisher(ROSPublisherTopic, 'geometry_msgs/Twist');

                    % protocol-specific raw receiver + protocol-agnostic odometry receiver
                    obj.receiveRaw = @obj.ROSReceiveRaw;
                    obj.receive    = @obj.ReceiveOdometry;
                    obj.send       = @(command) obj.ROSPublish(command);

                case 'UDP'  % UDPで通信する場合

                    UDPReceiverPort = double(args(1));
                    UDPSenderLocalPort = double(args(2));

                    % New format (recommended):
                    %   arg1=UDPReceiverPort, arg2=UDPSenderLocalPort, arg3=UDPCommandTargetPort, arg4=VehicleIP
                    % Backward compatible format:
                    %   arg1=UDPReceiverPort, arg2=UDPSenderPort(as both local and target), arg3=VehicleIP
                    if numel(args) >= 4 && strlength(args(4)) > 0
                        UDPCommandTargetPort = double(args(3));
                        UDPVehicleIP = args(4);
                    elseif numel(args) >= 3 && strlength(args(3)) > 0
                        UDPCommandTargetPort = double(args(2));
                        UDPVehicleIP = args(3);
                    else
                        error('Invalid UDP settings for %s', obj.name)
                    end

                    obj.UDPReceiver = udpport('LocalPort', UDPReceiverPort, 'ByteOrder', 'big-endian');
                    obj.UDPSender   = udpport('LocalPort', UDPSenderLocalPort, 'ByteOrder', 'big-endian');
                    configureTerminator(obj.UDPReceiver, 'LF')
                    configureTerminator(obj.UDPSender, 'LF')

                    % protocol-specific raw receiver + protocol-agnostic odometry receiver
                    obj.receiveRaw = @obj.UDPReceiveRaw;
                    obj.receive    = @obj.ReceiveOdometry;
                    obj.send       = @(command) obj.UDPSend(UDPVehicleIP, UDPCommandTargetPort, command);

                case 'TCP'
                    
                otherwise
                    error('Invalid communication protocol for %s', obj.name)
            end
        end

        % 位置と姿勢を表示
        % Per-object cleanup for communication resources.
        function delete(obj)

            % Command halt.
            obj.send([0, 0])
            
            if ~isempty(obj.UDPReceiver)
                try
                    delete(obj.UDPReceiver);
                catch
                end
            end

            if ~isempty(obj.UDPSender)
                try
                    delete(obj.UDPSender);
                catch
                end
            end
        end

        function print(obj)
            fprintf('%s :\n', obj.name)
            fprintf('   position    : %f\n', obj.position(1))
            fprintf('                 %f\n', obj.position(2))
            fprintf('   orientation : %f\n', obj.orientation)
        end

        % ROSでオドメトリを受信
        % Unified receive entry point:
        % 1) get raw payload using current protocol
        % 2) parse payload according to selected odometryType
        function odometry = ReceiveOdometry(obj)
            odometryRaw = obj.receiveRaw();

            if isempty(odometryRaw)
                odometry = [];
                return
            end

            switch obj.protocol
                case 'ROS'
                    odometry = obj.ParseROSOdometry(odometryRaw);
                case 'UDP'
                    odometry = obj.ParseUDPOdometry(odometryRaw);
                otherwise
                    error('Invalid communication protocol for %s', obj.name)
            end
        end

        function odometryRaw = ROSReceiveRaw(obj)
            odometryRaw = obj.ROSSubscriber.LatestMessage;
        end

        % Parse ROS message into a normalized odometry struct.
        % protocol and odometryType are intentionally decoupled here.
        function odometry = ParseROSOdometry(obj, odometryRaw)
            switch obj.odometryType
                case 'position&orientation'
                    switch odometryRaw.MessageType
                        case 'nav_msgs/Odometry'
                            position    = odometryRaw.Pose.Pose.Position;
                            orientation = odometryRaw.Pose.Pose.Orientation;
                            orientation = quat2eul([orientation.W orientation.X orientation.Y orientation.Z]);

                            odometry.position = [position.X; position.Y];
                            odometry.orientation = orientation(1);
                        otherwise
                            error('MessageType %s cannot provide %s for %s', odometryRaw.MessageType, obj.odometryType, obj.name)
                    end

                case 'speed&angularVelocity'
                    switch odometryRaw.MessageType
                        case 'nav_msgs/Odometry'
                            linear  = odometryRaw.Twist.Twist.Linear;
                            angular = odometryRaw.Twist.Twist.Angular;
                        case 'geometry_msgs/Twist'
                            linear  = odometryRaw.Linear;
                            angular = odometryRaw.Angular;
                        otherwise
                            error('MessageType %s cannot provide %s for %s', odometryRaw.MessageType, obj.odometryType, obj.name)
                    end

                    % Use planar speed magnitude so message layout does not leak to update().
                    odometry.speed = norm([linear.X, linear.Y], 2);
                    odometry.angularVelocity = angular.Z;

                otherwise
                    error('Invalid odometryType for %s', obj.name)
            end
        end

        % ROSで指令値を送信
        function ROSPublish(obj, command)
            message = rosmessage('geometry_msgs/Twist');
            message.Linear.X  = command(1);
            message.Angular.Z = command(2);
            send(obj.ROSPublisher, message)
        end

        % UDPでオドメトリを受信
        % Read the latest UDP packet.
        % Packet size depends on odometryType definition.
        function odometryRaw = UDPReceiveRaw(obj)
            packetSize = obj.ExpectedUDPPacketSize();
            bytesPerPacket = packetSize * 8; % double = 8 bytes
            bytesAvailable = obj.UDPReceiver.NumBytesAvailable;

            % Non-blocking read: return empty when no full packet has arrived yet.
            if bytesAvailable < bytesPerPacket
                odometryRaw = [];
                return
            end

            % If multiple packets are queued, consume all complete packets and keep the latest.
            packetCount = floor(bytesAvailable / bytesPerPacket);
            data = read(obj.UDPReceiver, packetCount * packetSize, 'double');
            odometryRaw = data(end - packetSize + 1:end);
        end

        % Parse UDP payload into the same normalized odometry struct as ROS.
        function odometry = ParseUDPOdometry(obj, odometryRaw)
            switch obj.odometryType
                case 'position&orientation'
                    payload = odometryRaw(end-2:end);
                    odometry.position = payload(1:2);
                    odometry.orientation = payload(3);

                case 'speed&angularVelocity'
                    payload = odometryRaw(end-1:end);
                    odometry.speed = payload(1);
                    odometry.angularVelocity = payload(2);

                otherwise
                    error('Invalid odometryType for %s', obj.name)
            end
        end

        function packetSize = ExpectedUDPPacketSize(obj)
            % Keep this function explicit so UDP layout changes are isolated here.
            switch obj.odometryType
                case 'position&orientation'
                    packetSize = 3;
                case 'speed&angularVelocity'
                    packetSize = 3;
                otherwise
                    error('Invalid odometryType for %s', obj.name)
            end
        end

        % UDPで指令値を送信
        function UDPSend(obj, vehicleIP, commandTargetPort, command)
            write(obj.UDPSender, command, 'double', vehicleIP, commandTargetPort)
        end

        % 状態を更新
        % Update vehicle state from normalized odometry.
        % This method is independent from transport protocol.
        function obj = update(obj, rate)

            freq = rate.DesiredRate;
            odometry = obj.receive();

            % Skip update when odometry is dropped or unavailable.
            if isempty(odometry)
                return
            end
            
            switch obj.odometryType
                case 'position&orientation' % 位置と姿勢を取得する場合

                    if ~isstruct(odometry) || ~isfield(odometry, 'position') || ~isfield(odometry, 'orientation')
                        return
                    end
                    positionPrev    = obj.position;
                    orientationPrev = obj.orientation;
                    obj.position    = odometry.position + obj.positionOffset;
                    obj.orientation = odometry.orientation + obj.orientationOffset;

                    obj.speed           = norm(obj.position - positionPrev, 2) * freq;
                    obj.angularVelocity = (obj.orientation - orientationPrev) * freq;

                case 'speed&angularVelocity' % 速度と角速度を取得する場合

                    if ~isstruct(odometry) || ~isfield(odometry, 'speed') || ~isfield(odometry, 'angularVelocity')
                        return
                    end
                    speedPrev           = obj.speed;
                    angularVelocityPrev = obj.angularVelocity;
                    orientationPrev     = obj.orientation;
                    obj.speed           = odometry.speed;
                    obj.angularVelocity = odometry.angularVelocity;

                    % Trapezoidal integration for smoother discrete-time estimation.
                    obj.orientation = obj.orientation + (obj.angularVelocity + angularVelocityPrev) / 2 / freq;
                    obj.position    = obj.position    + (obj.speed * [cos(obj.orientation); sin(obj.orientation)]...
                        + speedPrev * [cos(orientationPrev); sin(orientationPrev)]) / 2 / freq;
                    
                otherwise
                    error('Invalid odometryType for %s', obj.name)
            end

        end

    end

end
