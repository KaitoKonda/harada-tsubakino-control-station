function tests = testBridgeDiagnostics
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tests','helpers')));
end

function [instance, source, publisher, logger, file] = fixture(testCase, detail)
    if nargin < 2, detail = false; end
    source = FakeNatNetSource("testVehicle", 3);
    publisher = FakeMotivePublisher();
    settings = struct('name',"testVehicle", 'odometrySource',"motive", ...
        'motive',struct('name',"testVehicle",'id',NaN), ...
        'odometryInput',struct('topic',"/test/motive"));
    config = struct('frameId',"mocap", 'logIntervalSeconds',1, ...
        'staleWarningSeconds',0.5, 'logPoseDetails',detail);
    instance = bridge.MotiveRosBridge(config,settings,source,@(~) publisher);
    folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    logger = bridge.BridgeDiagnostics(config,folder);
    logger.configure(instance.mappings);
    file = logger.logPath;
    testCase.addTeardown(@() instance.close());
    testCase.addTeardown(@() logger.close());
end

function testDuplicatesDoNotErasePublishedInterval(testCase)
    [instance, source, publisher, logger, file] = fixture(testCase, true);
    logger.observe(instance.update(), 10);
    source.advanceFrame = false;
    stats = instance.update();
    verifyEqual(testCase, stats.frameStatus, "duplicate");
    verifyEmpty(testCase, stats.vehicles);
    logger.observe(stats, 10.1);
    source.advanceFrame = true;
    logger.observe(instance.update(), 10.2);
    source.advanceFrame = false;
    logger.observe(instance.update(), 11.1);
    logger.close();
    output = fileread(file);
    verifySubstring(testCase, output, 'polls=3 newFrames=1 duplicates=2 empty=0');
    verifySubstring(testCase, output, 'published=1 untracked=0 missing=0 invalid=0');
    verifySubstring(testCase, output, 'secondsSinceLastNewFrame=0.900');
    verifySubstring(testCase, output, 'secondsSinceLastPublish=0.900');
    verifySubstring(testCase, output, 'motive[m]=[1 2 3] ros[m]=[1 -3 2]');
    verifyEqual(testCase, publisher.frames, [1 2]);
    verifyEqual(testCase, publisher.positions{1}, [1 -3 2]);
    verifySubstring(testCase, output, '[END] polls=4 newFrames=2 duplicates=2 empty=0 invalidBodies=0 published=2');
end

function testReasonsTransitionsAndRecovery(testCase)
    [instance, source, ~, logger, file] = fixture(testCase);
    good = source.body;
    logger.observe(instance.update(),10);
    source.body.Tracked = false;
    stats = instance.update();
    verifyEqual(testCase, stats.vehicles.status,"untracked");
    logger.observe(stats,10.1);
    logger.observe(instance.update(),10.2);
    source.body = good;
    source.body.ID = 7;
    logger.observe(instance.update(),10.3);
    source.body = good;
    source.body.qw = 0;
    stats = instance.update();
    verifyEqual(testCase, stats.vehicles.status,"invalid");
    logger.observe(stats,10.4);
    source.body = good;
    logger.observe(instance.update(),10.5);
    logger.close();
    output = fileread(file);
    verifyEqual(testCase, count(string(output),'tracked=false'),1);
    verifySubstring(testCase, output,'missing from frame; receivedIDs=7');
    verifySubstring(testCase, output,'invalid quaternion; norm=0');
    verifySubstring(testCase, output,'publishing recovered');
    verifySubstring(testCase, output,'published=1 untracked=2 missing=1 invalid=1');
end

function testEmptyStaleRecoveryAndNever(testCase)
    [instance, source, ~, logger, file] = fixture(testCase);
    source.returnEmpty = true;
    stats = instance.update();
    verifyEqual(testCase,stats.frameStatus,"empty");
    logger.observe(stats,10);
    logger.observe(stats,10.1);
    source.returnEmpty = false;
    logger.observe(instance.update(),10.2);
    source.advanceFrame = false;
    logger.observe(instance.update(),10.3);
    logger.close();
    output = fileread(file);
    verifySubstring(testCase,output,'secondsSinceLastNewFrame=never');
    verifySubstring(testCase,output,'secondsSinceLastPublish=never');
    verifyEqual(testCase,count(string(output),'NatNet frame is not advancing'),1);
    verifySubstring(testCase,output,'NatNet frame updates recovered');
    verifySubstring(testCase,output,'[END] polls=4 newFrames=1 duplicates=1 empty=2');
end

function testInvalidBodyRetainsIdAndDoesNotLeakPreviousId(testCase)
    source = FakeNatNetSource("testVehicle",3);
    raw = rmfield(source.body,'Tracked');
    raw(2) = raw(1);
    raw(2).ID = [];
    decoded = bridge.decodeNatNetFrame(struct('iFrame',1,'nRigidBodies',2,'RigidBodies',raw));
    verifyEqual(testCase,decoded.invalidCount,2);
    verifyEqual(testCase,decoded.invalidBodies(1).id,3);
    verifyTrue(testCase,isnan(decoded.invalidBodies(2).id));
    verifyEqual(testCase,decoded.invalidBodies(2).index,2);
    verifyEqual(testCase,decoded.receivedIds,3);
    verifySubstring(testCase,string(decoded.invalidReasons(1)),'Tracked');
end

function testTwoVehiclesHaveIndependentOutcomes(testCase)
    [instance, ~, publisher, logger, ~] = fixture(testCase);
    instance.close(); logger.close();
    source = FakeNatNetSource("one",3);
    source.model.RigidBody(2) = struct('Name','two','ID',4);
    source.model.RigidBodyCount = 2;
    source.body(2) = source.body(1);
    source.body(2).ID = 4;
    source.body(2).Tracked = false;
    settings = struct('name',"one",'odometrySource',"motive", ...
        'motive',struct('name',"one",'id',3),'odometryInput',struct('topic',"/one"));
    settings(2) = settings(1);
    settings(2).name = "two";
    settings(2).motive = struct('name',"two",'id',4);
    settings(2).odometryInput.topic = "/two";
    instance = bridge.MotiveRosBridge(struct('frameId',"mocap"),settings,source,@(~) FakeMotivePublisher());
    testCase.addTeardown(@() instance.close());
    stats = instance.update();
    verifyEqual(testCase,[stats.vehicles.status],["published","untracked"]);
    verifyEqual(testCase,stats.publishedCount,1);
    source.body = source.body(2);
    stats = instance.update();
    verifyEqual(testCase,[stats.vehicles.status],["missing","untracked"]);
    verifyTrue(testCase,publisher.closed);
end

function testExceptionAndFinalFlushAreSaved(testCase)
    [instance, ~, publisher, logger, file] = fixture(testCase);
    logger.observe(instance.update(),10);
    publisher.fail = true;
    try
        instance.update();
        verifyFail(testCase,'Expected simulated send failure.');
    catch exception
        verifyEqual(testCase,exception.identifier,'Test:PublishFailed');
        logger.logException(exception,"ROS publish");
    end
    logger.close(); logger.close();
    output = fileread(file);
    verifySubstring(testCase,output,'stage=ROS publish identifier=Test:PublishFailed');
    verifySubstring(testCase,output,'FakeMotivePublisher');
    verifyEqual(testCase,count(string(output),'[END]'),1);
    verifySubstring(testCase,output,'published=1');
end

function testStartupErrorIsSavedWithoutNetwork(testCase)
    settings = shared.stationConfig();
    folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    settings.logDirectory = folder;
    settings.motive.serverIp = "";
    experiment = struct('selectedVehicleNames',"notInCatalog",'vehicleSettings',struct());
    lastwarn('');
    verifyError(testCase,@() runMotiveRosBridge(settings,experiment), 'Station:UnknownVehicle');
    [~, warningId] = lastwarn;
    verifyEmpty(testCase,warningId);
    logs = dir(fullfile(folder,'motiveBridge_*.log'));
    verifyNumElements(testCase,logs,1);
    output = fileread(fullfile(logs(1).folder,logs(1).name));
    verifySubstring(testCase,output,'[START] NatNet');
    verifySubstring(testCase,output,'stage=configuration');
    verifySubstring(testCase,output,'[END]');
end
