function tests = test_Station
    tests=functiontests(localfunctions);
end

function testDefaultSimulationUsesEnabledRegistryWithoutROS(testCase)
    result=main("simulation",ShowUI=false,RealTime=false,Duration=0.15,Log=false);
    verifyEqual(testCase,result.vehicleNames,["pi1","pi2","pi3"]);
    verifyEqual(testCase,result.status,"completed");
    verifyTrue(testCase,all(result.fresh(:)));
    verifyTrue(testCase,all(result.sent(:)));
    verifyEqual(testCase,result.commands,zeros(size(result.commands)));
    verifyEqual(testCase,squeeze(result.states(end,1,:)).',[0 1 -1]);
end

function testSelectDisabledVehicleExplicitly(testCase)
    result=main("simulation",Vehicles="katchaka",ShowUI=false,RealTime=false, ...
        Duration=0.2,Controller=@movingController,Log=false);
    verifyEqual(testCase,result.vehicleNames,"katchaka");
    verifyGreaterThan(testCase,result.states(end,1,1),2);
end

function testSimulationMovesAndStops(testCase)
    s=LoadVehicleSettings(station_config().vehicleFile,"pi1");
    v=Vehicle(s,"simulation");
    cleanup=onCleanup(@() delete(v));
    v.calibrate();
    v.send([0.1 0]);
    v.update(1);
    verifyEqual(testCase,v.position,[0.1;0],'AbsTol',1e-12);
    v.send([0 0]);
    v.update(1);
    verifyEqual(testCase,v.position,[0.1;0],'AbsTol',1e-12);
    verifyEqual(testCase,v.speed,0,'AbsTol',1e-12);
end

function testConfigPathsIndependentOfCurrentFolder(testCase)
    folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    original=pwd;
    testCase.addTeardown(@() cd(original));
    addpath(original);
    cd(folder);
    result=main("simulation",Vehicles="pi2",ShowUI=false,RealTime=false,Duration=0.05,Log=false);
    verifyEqual(testCase,result.status,"completed");
end

function testInvalidCommandsRejectedAsBatch(testCase)
    vehicles=struct('pi1',[],'pi2',[]);
    config=station_config();
    verifyError(testCase,@() ValidateCommands(struct('pi1',[0 0]),vehicles,config), ...
        'Station:InvalidCommands');
    verifyError(testCase,@() ValidateCommands(struct('pi1',[0 0],'pi2',[NaN 0]),vehicles,config), ...
        'Station:InvalidCommands');
    verifyError(testCase,@() ValidateCommands(struct('pi1',[0 0],'pi2',[config.maxSpeed+1 0]),vehicles,config), ...
        'Station:CommandLimit');
end

function testUnknownAndDuplicateNamesRejected(testCase)
    config=station_config();
    verifyError(testCase,@() LoadVehicleSettings(config.vehicleFile,"missing"),'Station:UnknownVehicle');
    folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    file=fullfile(folder,'vehicles.csv');
    text=strrep(fileread(config.vehicleFile),'pi2,1,','pi1,1,');
    fid=fopen(file,'w');
    fwrite(fid,text);
    fclose(fid);
    verifyError(testCase,@() LoadVehicleSettings(file),'Station:InvalidSettings');
end

function testErrorRunSavesLogBeforeRethrow(testCase)
    config=station_config();
    config.logDirectory=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    verifyError(testCase,@() main("simulation",Config=config,ShowUI=false,RealTime=false, ...
        Duration=0.05,Controller=@badController),'Station:InvalidCommands');
    logs=dir(fullfile(config.logDirectory,'*.mat'));
    verifyNumElements(testCase,logs,1);
    data=load(fullfile(logs(1).folder,logs(1).name));
    verifyEqual(testCase,data.result.status,"error");
    verifyFalse(testCase,any(data.result.sent(:)));
    verifyEmpty(testCase,data.result.shutdownErrors);
end

function testExperimentCannotSkipExplicitStart(testCase)
    verifyError(testCase,@() main("experiment",ShowUI=false,Log=false),'Station:ExperimentUIRequired');
end

function testMotiveMappingsFollowRegistry(testCase)
    config=station_config();
    mappings=MotiveMappings(LoadVehicleSettings(config.vehicleFile,["pi3","pi1"]));
    verifyEqual(testCase,string({mappings.topic}),["/pi3/localization/odom","/pi1/localization/odom"]);
    verifyFalse(testCase,isfield(motive_config(),'rosNodeHost'));
end

function testUDPCommandsAndDatagramValidation(testCase)
    [v,tx,rx,cleanup]=udpVehicle("position&orientation","global"); %#ok<ASGLU>
    write(tx,[1 2 0.3],"double","127.0.0.1",v.settings.odometryPort);
    waitForPacket(v);
    value=v.receive();
    verifyEqual(testCase,value.position,[1;2]);
    v.send([0.1 -0.2]);
    start=tic;
    while rx.NumDatagramsAvailable==0 && toc(start)<1, pause(0.01); end
    packet=read(rx,1,"double");
    verifyEqual(testCase,packet.Data,[0.1 -0.2]);
    pause(0.15);
    write(tx,uint8(1:23),"uint8","127.0.0.1",v.settings.odometryPort);
    pause(0.02);
    verifyEmpty(testCase,v.receive());
end

function testHeaderlessROSExpiresAndPreservesReverseSpeed(testCase)
    [v,~,~,cleanup]=udpVehicle("speed&angularVelocity","initial"); %#ok<ASGLU>
    msg=twist(-0.1,0);
    v.acceptROSMessage(msg);
    v.update(0);
    v.update(0.2);
    verifyEqual(testCase,v.speed,-0.1);
    verifyEqual(testCase,v.position(1),1.98,'AbsTol',1e-12);
    pause(0.15);
    verifyEmpty(testCase,v.receive());
end

function testRepeatedPositiveStampDoesNotRefreshState(testCase)
    [v,~,~,cleanup]=udpVehicle("position&orientation","global"); %#ok<ASGLU>
    msg=pose(1,2,0);
    msg.Header.Stamp=struct('Sec',1,'Nsec',0);
    v.acceptROSMessage(msg);
    verifyNotEmpty(testCase,v.receive());
    pause(0.15);
    v.acceptROSMessage(msg);
    verifyEmpty(testCase,v.receive());
end

function testGlobalCoordinatesAndAngleWrap(testCase)
    [v,~,~,cleanup]=udpVehicle("position&orientation","global"); %#ok<ASGLU>
    v.acceptROSMessage(pose(10,20,pi-0.01));
    v.calibrate();
    verifyEqual(testCase,v.position,[10;20]);
    pause(0.02);
    v.acceptROSMessage(pose(10,20,-pi+0.01));
    v.update(0.02);
    verifyGreaterThan(testCase,v.angularVelocity,0);
    verifyLessThan(testCase,v.angularVelocity,2);
end

function testInitialCoordinatesRotateTranslationWithHeading(testCase)
    [v,~,~,cleanup]=udpVehicle("position&orientation","initial",[5 2 pi/2]); %#ok<ASGLU>
    v.acceptROSMessage(pose(10,20,0));
    v.calibrate();
    verifyEqual(testCase,v.position,[5;2],'AbsTol',1e-12);
    v.acceptROSMessage(pose(11,20,0));
    v.update(0.02);
    verifyEqual(testCase,v.position,[5;3],'AbsTol',1e-12);
    verifyEqual(testCase,v.orientation,pi/2,'AbsTol',1e-12);
end

function commands=movingController(vehicles)
    commands=ControllerStop(vehicles);
    for name=string(fieldnames(vehicles)).'
        commands.(name)=[0.1 0];
    end
end

function commands=badController(~)
    commands=struct();
end

function [v,tx,rx,cleanup]=udpVehicle(type,coordinates,initialPose)
    config=station_config();
    s=LoadVehicleSettings(config.vehicleFile,"katchaka");
    s.odometryType=type;
    s.coordinateMode=coordinates;
    if nargin>2, s.initialPose=initialPose; end
    probe=udpport("datagram","IPV4");
    s.odometryPort=probe.LocalPort;
    probe2=udpport("datagram","IPV4");
    s.commandLocalPort=probe2.LocalPort;
    rx=udpport("datagram","IPV4","ByteOrder","big-endian");
    s.commandTargetPort=rx.LocalPort;
    tx=udpport("datagram","IPV4","ByteOrder","big-endian");
    delete(probe);
    delete(probe2);
    v=Vehicle(s,"experiment",0.1);
    cleanup=onCleanup(@() cleanupUDP(v,tx,rx));
end

function cleanupUDP(v,tx,rx)
    delete(v);
    delete(tx);
    delete(rx);
end

function waitForPacket(v)
    start=tic;
    while isempty(v.receive()) && toc(start)<1, pause(0.01); end
end

function msg=twist(v,w)
    msg=struct('Linear',struct('X',v,'Y',0,'Z',0), ...
        'Angular',struct('X',0,'Y',0,'Z',w));
end

function msg=pose(x,y,yaw)
    msg.Pose.Pose.Position=struct('X',x,'Y',y,'Z',0);
    msg.Pose.Pose.Orientation=struct('W',cos(yaw/2),'X',0,'Y',0,'Z',sin(yaw/2));
end
