function tests = testStationRos
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
        fullfile(root, 'tests', 'helpers')));
    core = ros.Core(11549);
    testCase.addTeardown(@() delete(core));
    config = struct('masterUri', "http://localhost:11549", ...
        'nodeHost', "127.0.0.1");
    shared.ensureRosSession(config);
    testCase.addTeardown(@() rosshutdown);
end

function testPositionInputAndCommandOutput(testCase)
    stationSettings = shared.stationConfig();
    stationSettings.ros.masterUri = "http://localhost:11549";
    stationSettings.ros.nodeHost = "127.0.0.1";
    settings = shared.resolveVehicleSettings(shared.vehicleCatalog(), shared.experimentConfig(), ...
        stationSettings, "experiment", "pi1");
    settings.odometryInput.topic = "/station_new_test/pose";
    settings.commandOutput.topic = "/station_new_test/command";
    vehicle = station.Vehicle(settings, "experiment", 0.25);
    publisher = rospublisher(char(settings.odometryInput.topic), ...
        'nav_msgs/Odometry', 'DataFormat', 'struct');
    subscriber = rossubscriber(char(settings.commandOutput.topic), ...
        'geometry_msgs/Twist', 'DataFormat', 'struct');
    cleanup = onCleanup(@() release(vehicle, publisher, subscriber)); %#ok<NASGU>
    pause(1);
    message = rosmessage(publisher);
    message.Header.Stamp.Sec = uint32(1);
    message.Pose.Pose.Position.X = 4;
    message.Pose.Pose.Position.Y = 5;
    message.Pose.Pose.Orientation.W = 1;
    for index = 1:100
        send(publisher, message);
        if vehicle.hasFreshObservation(), break; end
        pause(0.02);
    end
    verifyTrue(testCase, vehicle.hasFreshObservation());
    vehicle.calibrate();
    verifyEqual(testCase, vehicle.position, [4;5]);
    received = [];
    for index = 1:30
        vehicle.send([0.1 -0.2]);
        pause(0.05);
        received = subscriber.LatestMessage;
        if ~isempty(received), break; end
    end
    verifyNotEmpty(testCase, received);
    verifyEqual(testCase, received.Linear.X, 0.1);
    verifyEqual(testCase, received.Angular.Z, -0.2);
    pause(0.3);
    verifyFalse(testCase, vehicle.update(0));
end

function testMotiveOdometryPublisher(testCase)
    topic = '/station_new_test/motive';
    subscriber = rossubscriber(topic, 'nav_msgs/Odometry');
    publisher = bridge.RosOdometryPublisher(topic);
    cleanup = onCleanup(@() releasePublisher(publisher, subscriber)); %#ok<NASGU>
    pause(1);
    for frameNumber = 10:30
        verifyTrue(testCase, publisher.publish([1 2 3], [0 0 0 1], ...
            "mocap", "pi1/base_link", frameNumber));
        pause(0.05);
        if ~isempty(subscriber.LatestMessage), break; end
    end
    message = subscriber.LatestMessage;
    verifyNotEmpty(testCase, message);
    verifyEqual(testCase, message.Pose.Pose.Position.X, 1);
    verifyEqual(testCase, message.Pose.Pose.Position.Y, 2);
    verifyEqual(testCase, message.Pose.Pose.Orientation.W, 1);
    verifyFalse(testCase, publisher.publish([1 2 3], [0 0 0 1], ...
        "mocap", "pi1/base_link", frameNumber));
end

function testOtosPose2DInput(testCase)
    catalog = shared.vehicleCatalog();
    experiment = shared.experimentConfig();
    settings = shared.resolveVehicleSettings(catalog, experiment, ...
        shared.stationConfig(), "simulation", "pi3");
    settings.odometryInput.topic = "/station_new_test/otos";
    source = station.RosOdometrySource(settings.odometryInput, tic);
    publisher = rospublisher(char(settings.odometryInput.topic), ...
        'geometry_msgs/Pose2D', 'DataFormat', 'struct');
    cleanup = onCleanup(@() releaseSource(source, publisher)); %#ok<NASGU>
    pause(1);
    message = rosmessage(publisher);
    message.X = 1.5;
    message.Y = -2.0;
    message.Theta = 0.4;
    sample = [];
    for index = 1:50
        send(publisher, message);
        pause(0.02);
        sample = source.read();
        if ~isempty(sample), break; end
    end
    verifyNotEmpty(testCase, sample);
    verifyEqual(testCase, sample.value.position, [1.5;-2.0]);
    verifyEqual(testCase, sample.value.orientation, 0.4);
end

function testOlderStampedOdometryIsIgnored(testCase)
    settings = shared.resolveVehicleSettings(shared.vehicleCatalog(), ...
        shared.experimentConfig(), shared.stationConfig(), "simulation", "pi1");
    settings.odometryInput.topic = "/station_new_test/stamp_order";
    source = station.RosOdometrySource(settings.odometryInput, tic);
    publisher = rospublisher(char(settings.odometryInput.topic), ...
        'nav_msgs/Odometry', 'DataFormat', 'struct');
    cleanup = onCleanup(@() releaseSource(source, publisher)); %#ok<NASGU>
    pause(1);

    message = rosmessage(publisher);
    message.Header.Stamp.Sec = uint32(10);
    message.Pose.Pose.Position.X = 10;
    message.Pose.Pose.Orientation.W = 1;
    first = [];
    for index = 1:50
        send(publisher, message);
        pause(0.02);
        first = source.read();
        if ~isempty(first), break; end
    end
    verifyNotEmpty(testCase, first);
    verifyEqual(testCase, first.value.position(1), 10);

    for stamp = [9 10]
        message.Header.Stamp.Sec = uint32(stamp);
        message.Pose.Pose.Position.X = stamp;
        send(publisher, message);
        pause(0.1);
        verifyEmpty(testCase, source.read());
    end

    message.Header.Stamp.Sec = uint32(11);
    message.Pose.Pose.Position.X = 11;
    next = [];
    for index = 1:50
        send(publisher, message);
        pause(0.02);
        next = source.read();
        if ~isempty(next), break; end
    end
    verifyNotEmpty(testCase, next);
    verifyEqual(testCase, next.value.position(1), 11);
    verifyGreaterThan(testCase, next.number, first.number);
end

function testWheelOdometryVelocityInput(testCase)
    experiment = shared.experimentConfig();
    experiment.vehicleSettings.pi3.odometrySource = "wheelOdometry";
    settings = shared.resolveVehicleSettings(shared.vehicleCatalog(), experiment, ...
        shared.stationConfig(), "simulation", "pi3");
    settings.odometryInput.topic = "/station_new_test/wheel";
    source = station.RosOdometrySource(settings.odometryInput, tic);
    publisher = rospublisher(char(settings.odometryInput.topic), ...
        'nav_msgs/Odometry', 'DataFormat', 'struct');
    cleanup = onCleanup(@() releaseSource(source, publisher)); %#ok<NASGU>
    pause(1);
    message = rosmessage(publisher);
    message.Twist.Twist.Linear.X = 0.12;
    message.Twist.Twist.Angular.Z = -0.34;
    sample = [];
    for index = 1:50
        send(publisher, message);
        pause(0.02);
        sample = source.read();
        if ~isempty(sample), break; end
    end
    verifyNotEmpty(testCase, sample);
    verifyEqual(testCase, sample.value.speed, 0.12);
    verifyEqual(testCase, sample.value.angularVelocity, -0.34);
end

function testBridgeFromFrameToRos(testCase)
    stationSettings = shared.stationConfig();
    settings = shared.resolveVehicleSettings(shared.vehicleCatalog(), shared.experimentConfig(), ...
        stationSettings, "simulation", "pi1");
    settings.odometryInput.topic = "/station_new_test/bridge";
    source = FakeNatNetSource("pi1", 5);
    subscriber = rossubscriber(char(settings.odometryInput.topic), ...
        'nav_msgs/Odometry');
    bridgeInstance = bridge.MotiveRosBridge(stationSettings.motive, settings, source);
    cleanup = onCleanup(@() releaseBridge(bridgeInstance, subscriber)); %#ok<NASGU>
    pause(1);
    message = [];
    for index = 1:30
        stats = bridgeInstance.update();
        pause(0.05);
        message = subscriber.LatestMessage;
        if ~isempty(message), break; end
    end
    verifyNotEmpty(testCase, message);
    verifyEqual(testCase, stats.publishedCount, 1);
    verifyEqual(testCase, message.Pose.Pose.Position.X, 1);
    verifyEqual(testCase, message.Pose.Pose.Position.Y, -3);
    verifyEqual(testCase, message.Pose.Pose.Position.Z, 2);
    source.body.Tracked = false;
    stats = bridgeInstance.update();
    verifyEqual(testCase, stats.matchedCount, 1);
    verifyEqual(testCase, stats.publishedCount, 0);
end

function testExistingRosSessionMustMatch(testCase)
    config = struct('masterUri', "http://localhost:11549", ...
        'nodeHost', "127.0.0.1");
    shared.ensureRosSession(config);
    config.nodeHost = "127.0.0.2";
    verifyError(testCase, @() shared.ensureRosSession(config), ...
        'Station:RosConfigMismatch');
end

function release(vehicle, publisher, subscriber)
    vehicle.close();
    delete(publisher);
    delete(subscriber);
end

function releasePublisher(publisher, subscriber)
    publisher.close();
    delete(subscriber);
end

function releaseBridge(bridge, subscriber)
    bridge.close();
    delete(subscriber);
end

function releaseSource(source, publisher)
    source.close();
    delete(publisher);
end
