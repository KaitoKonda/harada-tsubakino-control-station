classdef MotiveRosBridge < handle
    %MOTIVEROSBRIDGE Poll NatNet rigid bodies and publish ROS Odometry.

    properties (SetAccess = private)
        Config
        NatNetClient
        Publishers
        RigidBodyIds
        LastFrameNumber double = NaN
    end

    methods
        function obj = MotiveRosBridge(config)
            obj.Config = config;
            obj.validateConfig();

            if exist('natnet', 'class') ~= 8
                error('MotiveRosBridge:NatNetMissing', ...
                    ['NatNet MATLAB wrapper was not found. Add natnet.m, NatNetML.dll, and ' ...
                     'NatNetLib.dll from the OptiTrack MATLAB plugin to the MATLAB path.'])
            end

            obj.NatNetClient = natnet();
            obj.NatNetClient.HostIP = char(config.serverIP);
            obj.NatNetClient.ClientIP = char(config.clientIP);
            obj.NatNetClient.ConnectionType = char(config.connectionType);
            obj.NatNetClient.connect();
            if ~obj.NatNetClient.IsConnected
                error('MotiveRosBridge:ConnectionFailed', ...
                    ['NatNet could not connect to Motive. Check serverIP, clientIP, ' ...
                     'Unicast settings, Data Streaming, and the firewall.'])
            end

            bodyCount = numel(config.rigidBodies);
            obj.Publishers = cell(1, bodyCount);
            for index = 1:bodyCount
                obj.Publishers{index} = rospublisher( ...
                    char(config.rigidBodies(index).topic), 'nav_msgs/Odometry');
            end
            obj.RigidBodyIds = obj.resolveRigidBodyIds();
        end

        function publishedCount = update(obj)
            frame = obj.NatNetClient.getFrame();
            publishedCount = 0;
            if isempty(frame)
                return
            end

            [frameNumber, rigidBodies] = MotiveFrameAdapter.unpack(frame);
            if frameNumber == obj.LastFrameNumber
                return
            end
            obj.LastFrameNumber = frameNumber;

            rigidBodyCount = numel(rigidBodies);
            for bodyIndex = 1:rigidBodyCount
                body = rigidBodies(bodyIndex);
                mappingIndex = find(obj.RigidBodyIds == double(body.ID), 1);
                if isempty(mappingIndex) || ~logical(body.Tracked)
                    continue
                end

                position = [double(body.x), double(body.y), double(body.z)];
                quaternion = [double(body.qx), double(body.qy), ...
                              double(body.qz), double(body.qw)];
                obj.publishPose(mappingIndex, position, quaternion);
                publishedCount = publishedCount + 1;
            end
        end

        function delete(obj)
            if ~isempty(obj.NatNetClient)
                try
                    obj.NatNetClient.disconnect();
                catch
                end
            end
        end
    end

    methods (Access = private)
        function validateConfig(obj)
            required = {'serverIP', 'clientIP', 'connectionType', 'frameId', 'rigidBodies'};
            for index = 1:numel(required)
                if ~isfield(obj.Config, required{index})
                    error('MotiveRosBridge:InvalidConfig', 'Missing config field: %s', required{index})
                end
            end
            if strlength(obj.Config.serverIP) == 0 || strlength(obj.Config.clientIP) == 0
                error('MotiveRosBridge:NetworkNotConfigured', ...
                    ['Set serverIP (Motive PC) and clientIP (this laptop''s wired Motive-network IP) ' ...
                     'in motive_config.m before connecting.'])
            end
        end

        function ids = resolveRigidBodyIds(obj)
            mappings = obj.Config.rigidBodies;
            ids = [mappings.id];
            unresolved = isnan(ids);
            if ~any(unresolved)
                return
            end

            descriptions = obj.NatNetClient.getModelDescription();
            if ~isfield(descriptions, 'RigidBody')
                error('MotiveRosBridge:NoRigidBodies', 'Motive did not report any rigid-body descriptions.')
            end

            rigidBodies = descriptions.RigidBody;
            for mappingIndex = find(unresolved)
                wantedName = string(mappings(mappingIndex).name);
                for descriptionIndex = 1:numel(rigidBodies)
                    description = rigidBodies(descriptionIndex);
                    if string(description.Name) == wantedName
                        ids(mappingIndex) = double(description.ID);
                        break
                    end
                end
                if isnan(ids(mappingIndex))
                    error('MotiveRosBridge:RigidBodyNotFound', ...
                        'Rigid body "%s" was not found in Motive.', wantedName)
                end
            end
        end

        function publishPose(obj, mappingIndex, positionMotive, quaternionMotive)
            [positionROS, quaternionROS] = MotiveCoordinateTransform.toROS( ...
                positionMotive, quaternionMotive);
            mapping = obj.Config.rigidBodies(mappingIndex);

            message = rosmessage(obj.Publishers{mappingIndex});
            message.Header.Stamp = rostime('now');
            message.Header.FrameId = char(obj.Config.frameId);
            message.ChildFrameId = char(mapping.childFrameId);
            message.Pose.Pose.Position.X = positionROS(1);
            message.Pose.Pose.Position.Y = positionROS(2);
            message.Pose.Pose.Position.Z = positionROS(3);
            message.Pose.Pose.Orientation.X = quaternionROS(1);
            message.Pose.Pose.Orientation.Y = quaternionROS(2);
            message.Pose.Pose.Orientation.Z = quaternionROS(3);
            message.Pose.Pose.Orientation.W = quaternionROS(4);
            send(obj.Publishers{mappingIndex}, message);
        end
    end
end
