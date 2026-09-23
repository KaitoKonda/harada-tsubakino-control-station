function dummy_ros_vehicle(vehicleName, odomTopicSuffix, commandTopicSuffix, odometryType, messageType, rateHz, desktopIP, masterURI)
%DUMMY_ROS_VEHICLE Standalone local ROS transport test; main simulation needs no ROS.
% dummy_ros_vehicle("pi1","localization/odom","rover_drive","position&orientation", ...
%     "nav_msgs/Odometry",20,"127.0.0.1","http://localhost:11311")
    if nargin<1, vehicleName="pi1"; end
    if nargin<2, odomTopicSuffix="localization/odom"; end
    if nargin<3, commandTopicSuffix="rover_drive"; end
    if nargin<4, odometryType="position&orientation"; end
    if nargin<5
        if odometryType=="position&orientation"
            messageType="nav_msgs/Odometry";
        else
            messageType="geometry_msgs/Twist";
        end
    end
    if nargin<6, rateHz=20; end
    if nargin<7, desktopIP="127.0.0.1"; end
    if nargin<8, masterURI="http://localhost:11311"; end
    validateattributes(rateHz,{'numeric'},{'scalar','positive','finite'});
    StartStationROS(struct('masterURI',string(masterURI),'nodeHost',string(desktopIP)));
    odomTopic=sprintf('/%s/%s',vehicleName,odomTopicSuffix);
    commandTopic=sprintf('/%s/%s',vehicleName,commandTopicSuffix);
    state=containers.Map({'command','timer'},{[0 0],[]});
    odomPub=rospublisher(odomTopic,messageType,'DataFormat','struct');
    commandSub=rossubscriber(commandTopic,'geometry_msgs/Twist', ...
        @(~,msg) recordCommand(state,msg),'DataFormat','struct');
    cleaner=onCleanup(@() release(odomPub,commandSub));
    fprintf('Dummy ROS: %s -> %s. Ctrl+C to stop.\n',commandTopic,odomTopic);
    x=0; y=0; theta=0;
    previous=tic;
    while true
        step=tic;
        dt=toc(previous);
        previous=tic;
        command=state('command');
        received=state('timer');
        if isempty(received) || toc(received)>0.25
            command=[0 0];
        end
        speed=command(1);
        yawRate=command(2);
        x=x+speed*cos(theta)*dt;
        y=y+speed*sin(theta)*dt;
        theta=theta+yawRate*dt;
        msg=rosmessage(odomPub);
        if messageType=="nav_msgs/Odometry"
            stamp=rostime('now');
            msg.Header.Stamp.Sec=stamp.Sec;
            msg.Header.Stamp.Nsec=stamp.Nsec;
            msg.Header.FrameId='odom';
            msg.ChildFrameId=char(string(vehicleName)+"/base_link");
            msg.Pose.Pose.Position.X=x;
            msg.Pose.Pose.Position.Y=y;
            msg.Pose.Pose.Orientation.W=cos(theta/2);
            msg.Pose.Pose.Orientation.Z=sin(theta/2);
            msg.Twist.Twist.Linear.X=speed;
            msg.Twist.Twist.Angular.Z=yawRate;
        elseif messageType=="geometry_msgs/Twist"
            msg.Linear.X=speed;
            msg.Angular.Z=yawRate;
        else
            error('Station:InvalidSettings','Unsupported dummy ROS message type.');
        end
        send(odomPub,msg);
        pause(max(0,1/rateHz-toc(step)));
    end
end

function recordCommand(state,msg)
    command=[msg.Linear.X msg.Angular.Z];
    if all(isfinite(command))
        state('command')=command;
        state('timer')=tic();
    end
end

function release(pub,sub)
    delete(sub);
    delete(pub);
end
