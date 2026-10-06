function tests=test_StationROS
% Optional ROS Toolbox integration tests, isolated from the normal master.
    tests=functiontests(localfunctions);
end

function setupOnce(testCase)
    core=ros.Core(11539);
    testCase.addTeardown(@() delete(core));
    config=struct('masterURI',"http://localhost:11539",'nodeHost',"127.0.0.1");
    StartStationROS(config);
    testCase.addTeardown(@() rosshutdown);
    testCase.TestData.config=config;
end

function testROSHeaderlessReceptionAndCommandPublication(testCase)
    s=LoadVehicleSettings(station_config().vehicleFile,"pi1");
    s.odometryType="speed&angularVelocity";
    s.coordinateMode="initial";
    s.odometryMessageType="geometry_msgs/Twist";
    s.odometryTopic="/station_test/state";
    s.commandTopic="/station_test/command";
    v=Vehicle(s,"experiment",0.15);
    pub=rospublisher(char(s.odometryTopic),'geometry_msgs/Twist','DataFormat','struct');
    sub=rossubscriber(char(s.commandTopic),'geometry_msgs/Twist','DataFormat','struct');
    cleaner=onCleanup(@() release(v,pub,sub));
    pause(1);
    msg=rosmessage(pub);
    msg.Linear.X=-0.1;
    msg.Angular.Z=0.2;
    waitForState(pub,msg,v);
    verifyTrue(testCase,v.update(0));
    verifyEqual(testCase,v.speed,-0.1);
    verifyEqual(testCase,v.angularVelocity,0.2);
    v.send([0.1 -0.2]);
    received=receive(sub,2);
    verifyEqual(testCase,received.Linear.X,0.1);
    verifyEqual(testCase,received.Angular.Z,-0.2);
    pause(0.2);
    verifyEmpty(testCase,v.receive());
end

function testROSPositionInputWithUDPOutput(testCase)
    s=LoadVehicleSettings(station_config().vehicleFile,"pi1");
    s.odometryTopic="/station_test/pose";
    s.commandProtocol="UDP";
    s.vehicleIP="127.0.0.1";
    probe=udpport("datagram","IPV4");
    s.commandLocalPort=probe.LocalPort;
    rx=udpport("datagram","IPV4","ByteOrder","big-endian");
    s.commandTargetPort=rx.LocalPort;
    delete(probe);
    v=Vehicle(s,"experiment",0.25);
    pub=rospublisher(char(s.odometryTopic),'nav_msgs/Odometry','DataFormat','struct');
    cleaner=onCleanup(@() release(v,pub,rx));
    pause(1);
    msg=rosmessage(pub);
    msg.Header.Stamp.Sec=uint32(1);
    msg.Pose.Pose.Position.X=4;
    msg.Pose.Pose.Position.Y=5;
    msg.Pose.Pose.Orientation.W=1;
    waitForState(pub,msg,v);
    v.calibrate();
    verifyEqual(testCase,v.position,[4;5]);
    v.send([0.1 0.2]);
    started=tic;
    while rx.NumDatagramsAvailable==0 && toc(started)<1, pause(0.01); end
    packet=read(rx,1,"double");
    verifyEqual(testCase,packet.Data,[0.1 0.2]);
end

function testExistingSessionSettingsMustMatch(testCase)
    StartStationROS(testCase.TestData.config);
    changed=testCase.TestData.config;
    changed.nodeHost="127.0.0.2";
    verifyError(testCase,@() StartStationROS(changed),'Station:ROSConfigMismatch');
end

function waitForState(pub,msg,v)
    started=tic;
    while isempty(v.receive()) && toc(started)<3
        send(pub,msg);
        pause(0.02);
    end
    assert(~isempty(v.receive()),'Test:ROSStateMissing','No local ROS state arrived.');
end

function release(v,pub,other)
    delete(v);
    delete(pub);
    delete(other);
end
