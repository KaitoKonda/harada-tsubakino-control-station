function dummy_ros_vehicle(vehicleName, odomTopicSuffix, commandTopicSuffix, odometryType, messageType, rateHz, desktopIP, masterURI)
% DUMMY_ROS_VEHICLE ROS dummy vehicle for manager-side integration tests.
%
% Example (position mode):
%   dummy_ros_vehicle("pi1","localization/odom","rover_drive","position&orientation","nav_msgs/Odometry",20,"192.168.24.26","http://localhost:11311")
%
% Example (speed mode):
%   dummy_ros_vehicle("pi1","localization/odom","rover_drive","speed&angularVelocity","geometry_msgs/Twist",20,"192.168.24.26","http://localhost:11311")

    if nargin < 1 || strlength(vehicleName) == 0
        vehicleName = "dummy1";
    end
    if nargin < 2 || strlength(odomTopicSuffix) == 0
        odomTopicSuffix = "localization/odom";
    end
    if nargin < 3 || strlength(commandTopicSuffix) == 0
        commandTopicSuffix = "rover_drive";
    end
    if nargin < 4 || strlength(odometryType) == 0
        odometryType = "position&orientation";
    end
    if nargin < 5 || strlength(messageType) == 0
        if odometryType == "position&orientation"
            messageType = "nav_msgs/Odometry";
        else
            messageType = "geometry_msgs/Twist";
        end
    end
    if nargin < 6 || isempty(rateHz)
        rateHz = 20;
    end
    if nargin < 7 || strlength(desktopIP) == 0
        desktopIP = "192.168.24.26";
    end
    if nargin < 8 || strlength(masterURI) == 0
        masterURI = "http://localhost:11311";
    end

    startedRosHere = false;
    try
        rosinit(masterURI, "NodeHost", desktopIP);
        startedRosHere = true;
    catch
        % Reuse existing ROS node in this MATLAB session.
    end

    odomTopic = sprintf('/%s/%s', vehicleName, odomTopicSuffix);
    commandTopic = sprintf('/%s/%s', vehicleName, commandTopicSuffix);

    odomPub = rospublisher(odomTopic, messageType);
    commandSub = rossubscriber(commandTopic, "geometry_msgs/Twist");
    cleaner = onCleanup(@() localCleanup(startedRosHere));

    fprintf("Dummy ROS vehicle started: pub=%s (%s), sub=%s\n", odomTopic, messageType, commandTopic);
    fprintf("Press Ctrl+C to stop.\n");

    dt = 1 / rateHz;
    r = rosrate(rateHz);

    x = 0;
    y = 0;
    theta = 0;
    speed = 0.5;
    yawRate = 0.3;

    while true
        cmd = commandSub.LatestMessage;
        if ~isempty(cmd)
            speed = cmd.Linear.X;
            yawRate = cmd.Angular.Z;
        end

        x = x + speed * cos(theta) * dt;
        y = y + speed * sin(theta) * dt;
        theta = theta + yawRate * dt;

        switch messageType
            case "nav_msgs/Odometry"
                msg = rosmessage("nav_msgs/Odometry");
                q = eul2quat([theta 0 0], "ZYX"); % [w x y z]

                msg.Header.Stamp = rostime('now');
                msg.Header.FrameId = 'odom';
                msg.ChildFrameId = char(vehicleName + "/base_link");

                msg.Pose.Pose.Position.X = x;
                msg.Pose.Pose.Position.Y = y;
                msg.Pose.Pose.Orientation.W = q(1);
                msg.Pose.Pose.Orientation.X = q(2);
                msg.Pose.Pose.Orientation.Y = q(3);
                msg.Pose.Pose.Orientation.Z = q(4);

                msg.Twist.Twist.Linear.X = speed;
                msg.Twist.Twist.Linear.Y = 0;
                msg.Twist.Twist.Angular.Z = yawRate;

            case "geometry_msgs/Twist"
                msg = rosmessage("geometry_msgs/Twist");
                msg.Linear.X = speed;
                msg.Linear.Y = 0;
                msg.Angular.Z = yawRate;

            otherwise
                error("Unsupported messageType: %s", messageType)
        end

        send(odomPub, msg);
        waitfor(r);
    end
end

function localCleanup(startedRosHere)
    if startedRosHere
        try
            rosshutdown;
        catch
        end
    end
end
