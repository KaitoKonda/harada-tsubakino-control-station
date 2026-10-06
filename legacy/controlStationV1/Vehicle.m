classdef Vehicle < handle
%VEHICLE Normalized state with independent odometry and command transports.
% Simulation never opens ROS or UDP resources.
    properties
        name string = ""
        position (2,1) double = [0;0]
        orientation (1,1) double = 0
        speed (1,1) double = 0
        angularVelocity (1,1) double = 0
    end
    properties (SetAccess=private)
        settings
        mode string = "simulation"
        lastCommand (1,2) double = [0 0]
        odometryTimeoutSeconds double = 0.25
    end
    properties (Access=private)
        ROSSubscriber
        ROSPublisher
        UDPReceiver
        UDPSender
        clock
        observation = []
        observationTime double = -Inf
        sampleNumber double = 0
        appliedSample double = -1
        previousPoseTime double = NaN
        lastROSStamp double = NaN
        poseRotation double = eye(2)
        poseTranslation double = [0;0]
        yawOffset double = 0
        simulationPose double = [0 0 0]
        simulationTime double = 0
        integrationReady logical = false
        deleting logical = false
    end
    methods
        function obj = Vehicle(settings, mode, timeout)
            if nargin<2, mode="experiment"; end
            if nargin<3, timeout=0.25; end
            obj.settings = settings;
            obj.name = settings.name;
            obj.mode = mode;
            obj.odometryTimeoutSeconds = timeout;
            obj.clock = tic;
            obj.simulationPose = settings.initialPose;
            obj.position = settings.initialPose(1:2).';
            obj.orientation = settings.initialPose(3);
            if mode=="simulation"
                obj.simulate(0);
                return
            end
            assert(mode=="experiment",'Station:InvalidMode','Unknown execution mode.');
            switch settings.odometryProtocol
                case "ROS"
                    obj.ROSSubscriber = rossubscriber(char(settings.odometryTopic), ...
                        char(settings.odometryMessageType), ...
                        @(~,msg) obj.acceptROSMessage(msg), 'DataFormat','struct');
                case "UDP"
                    obj.UDPReceiver = udpport("datagram","IPV4", ...
                        "LocalPort",settings.odometryPort, "ByteOrder","big-endian");
            end
            switch settings.commandProtocol
                case "ROS"
                    obj.ROSPublisher = rospublisher(char(settings.commandTopic), ...
                        'geometry_msgs/Twist', 'DataFormat','struct');
                case "UDP"
                    obj.UDPSender = udpport("datagram","IPV4", ...
                        "LocalPort",settings.commandLocalPort, "ByteOrder","big-endian");
            end
        end

        function send(obj, command)
            assert(isnumeric(command) && isreal(command) && numel(command)==2 && ...
                all(isfinite(command(:))), 'Station:InvalidCommands','Invalid command for %s.',obj.name);
            command = double(command(:).');
            if obj.mode=="simulation"
                obj.lastCommand = command;
                return
            end
            if isempty(obj.settings), return; end
            if obj.settings.commandProtocol=="ROS"
                if isempty(obj.ROSPublisher), return; end
                msg = rosmessage(obj.ROSPublisher);
                msg.Linear.X = command(1);
                msg.Angular.Z = command(2);
                send(obj.ROSPublisher,msg);
            else
                if isempty(obj.UDPSender), return; end
                write(obj.UDPSender,command,"double", ...
                    obj.settings.vehicleIP,obj.settings.commandTargetPort);
            end
            obj.lastCommand = command;
        end

        function odometry = receive(obj)
            if obj.mode=="experiment" && obj.settings.odometryProtocol=="UDP"
                count = obj.UDPReceiver.NumDatagramsAvailable;
                if count>0
                    packets = read(obj.UDPReceiver,count,"uint8");
                    for k=1:numel(packets)
                        bytes = uint8(packets(k).Data);
                        % Preserve datagram boundaries; malformed packets do not refresh the timeout.
                        if numel(bytes)~=24, continue; end
                        values = typecast(bytes(:),'double');
                        [~,~,endian] = computer;
                        if endian=='L', values=swapbytes(values); end
                        obj.acceptObservation(obj.parseUDP(values),toc(obj.clock));
                    end
                end
            end
            odometry = obj.observation;
            if obj.mode=="experiment" && toc(obj.clock)-obj.observationTime>obj.odometryTimeoutSeconds
                odometry = [];
            end
        end

        function acceptROSMessage(obj, msg)
            % Called on message arrival, including headerless Twist and zero-stamp publishers.
            % A positive stamp must progress: repeated stamped frames are not fresh measurements.
            if isfield(msg,'Header')
                stamp = double(msg.Header.Stamp.Sec)+double(msg.Header.Stamp.Nsec)*1e-9;
                if ~isfinite(stamp) || stamp<0, return; end
                if stamp>0
                    if stamp==obj.lastROSStamp, return; end
                    obj.lastROSStamp = stamp;
                end
            end
            obj.acceptObservation(obj.parseROS(msg),toc(obj.clock));
        end

        function calibrate(obj)
            odometry = obj.receive();
            assert(~isempty(odometry),'Calibrate:NoFreshOdometry', ...
                'No fresh odometry for %s.',obj.name);
            obj.poseRotation = eye(2);
            obj.poseTranslation = [0;0];
            obj.yawOffset = 0;
            if obj.settings.odometryType=="position&orientation"
                if obj.settings.coordinateMode=="initial"
                    obj.yawOffset = obj.settings.initialPose(3)-odometry.orientation;
                    a = obj.yawOffset;
                    obj.poseRotation = [cos(a) -sin(a);sin(a) cos(a)];
                    obj.poseTranslation = obj.settings.initialPose(1:2).'-obj.poseRotation*odometry.position;
                end
                obj.position = obj.poseRotation*odometry.position+obj.poseTranslation;
                obj.orientation = odometry.orientation+obj.yawOffset;
                obj.previousPoseTime = obj.observationTime;
                obj.appliedSample = obj.sampleNumber;
            else
                obj.position = obj.settings.initialPose(1:2).';
                obj.orientation = obj.settings.initialPose(3);
            end
            obj.speed = 0;
            obj.angularVelocity = 0;
            obj.integrationReady = false;
        end

        function fresh = update(obj, dt)
            validateattributes(dt,{'numeric'},{'scalar','real','finite','nonnegative'});
            if obj.mode=="simulation"
                obj.simulate(dt);
            end
            odometry = obj.receive();
            fresh = ~isempty(odometry);
            if ~fresh
                obj.integrationReady = false;
                return
            end
            if obj.settings.odometryType=="position&orientation"
                if obj.appliedSample==obj.sampleNumber, return; end
                p = obj.poseRotation*odometry.position+obj.poseTranslation;
                a = odometry.orientation+obj.yawOffset;
                elapsed = obj.observationTime-obj.previousPoseTime;
                if isfinite(elapsed) && elapsed>0
                    % Signed forward speed and shortest angular difference.
                    delta = p-obj.position;
                    obj.speed = dot(delta,[cos(a);sin(a)])/elapsed;
                    obj.angularVelocity = atan2(sin(a-obj.orientation),cos(a-obj.orientation))/elapsed;
                else
                    obj.speed=0;
                    obj.angularVelocity=0;
                end
                obj.position = p;
                obj.orientation = a;
                obj.previousPoseTime = obj.observationTime;
                obj.appliedSample = obj.sampleNumber;
            else
                oldSpeed = obj.speed;
                oldAngular = obj.angularVelocity;
                oldYaw = obj.orientation;
                obj.speed = odometry.speed;
                obj.angularVelocity = odometry.angularVelocity;
                % Never integrate an unobserved outage interval on reconnection.
                if obj.integrationReady
                    obj.orientation = oldYaw+(oldAngular+obj.angularVelocity)*dt/2;
                    obj.position = obj.position+dt/2*( ...
                        oldSpeed*[cos(oldYaw);sin(oldYaw)]+ ...
                        obj.speed*[cos(obj.orientation);sin(obj.orientation)]);
                end
                obj.integrationReady = true;
            end
        end

        function state = snapshot(obj)
            state = [obj.position.' obj.orientation obj.speed obj.angularVelocity];
        end

        function delete(obj)
            if obj.deleting, return; end
            obj.deleting = true;
            try
                obj.send([0 0]);
            catch exception
                warning('Station:StopFailed','Stop failed for %s: %s',obj.name,exception.message);
            end
            for field = ["ROSSubscriber","ROSPublisher","UDPReceiver","UDPSender"]
                try
                    resource = obj.(field);
                    if ~isempty(resource), delete(resource); end
                catch exception
                    warning('Station:CleanupFailed','Cleanup failed for %s: %s',obj.name,exception.message);
                end
                obj.(field) = [];
            end
        end
    end
    methods (Access=private)
        function acceptObservation(obj, value, time)
            if isempty(value), return; end
            obj.observation = value;
            obj.observationTime = time;
            obj.sampleNumber = obj.sampleNumber+1;
        end

        function value = parseROS(obj,msg)
            value = [];
            if obj.settings.odometryType=="position&orientation"
                p = msg.Pose.Pose.Position;
                q = msg.Pose.Pose.Orientation;
                quaternion = double([q.W q.X q.Y q.Z]);
                if ~all(isfinite(quaternion)) || norm(quaternion)<eps, return; end
                quaternion=quaternion/norm(quaternion);
                w=quaternion(1); x=quaternion(2); y=quaternion(3); z=quaternion(4);
                pose = double([p.X;p.Y]);
                yaw = atan2(2*(w*z+x*y),1-2*(y*y+z*z));
                if ~all(isfinite(pose)), return; end
                value=struct('position',pose,'orientation',yaw);
            else
                if isfield(msg,'Twist')
                    twist=msg.Twist.Twist;
                else
                    twist=msg;
                end
                v=double(twist.Linear.X);
                w=double(twist.Angular.Z);
                if all(isfinite([v w]))
                    value=struct('speed',v,'angularVelocity',w);
                end
            end
        end

        function value = parseUDP(obj,values)
            value=[];
            if ~all(isfinite(values)), return; end
            if obj.settings.odometryType=="position&orientation"
                value=struct('position',values(1:2),'orientation',values(3));
            else
                value=struct('speed',values(2),'angularVelocity',values(3));
            end
        end

        function simulate(obj,dt)
            v=obj.lastCommand(1);
            w=obj.lastCommand(2);
            a=obj.simulationPose(3);
            if abs(w)<1e-10
                obj.simulationPose(1:2)=obj.simulationPose(1:2)+v*dt*[cos(a) sin(a)];
            else
                obj.simulationPose(1:2)=obj.simulationPose(1:2)+ ...
                    v/w*[sin(a+w*dt)-sin(a), cos(a)-cos(a+w*dt)];
            end
            obj.simulationPose(3)=a+w*dt;
            obj.simulationTime=obj.simulationTime+dt;
            if obj.settings.odometryType=="position&orientation"
                value=struct('position',obj.simulationPose(1:2).','orientation',obj.simulationPose(3));
            else
                value=struct('speed',v,'angularVelocity',w);
            end
            obj.acceptObservation(value,obj.simulationTime);
        end
    end
end
