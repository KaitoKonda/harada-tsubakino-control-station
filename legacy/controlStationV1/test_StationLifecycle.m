function tests=test_StationLifecycle
    tests=functiontests(localfunctions);
end

function testOneFailedStopDoesNotSkipOtherVehicles(testCase)
    folder=fullfile(fileparts(mfilename('fullpath')),'tests','helpers');
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
    first=StopProbe();
    first.fail=true;
    second=StopProbe();
    cleaner=onCleanup(@() delete([first second]));
    warnings=warning('off','Station:StopFailed');
    restore=onCleanup(@() warning(warnings));
    errors=StopVehicles(struct('first',first,'second',second));
    verifyNumElements(testCase,errors,1);
    verifyEqual(testCase,first.calls,1);
    verifyEqual(testCase,second.calls,1);
end

function testClosingStandbyCancelsRatherThanStarting(testCase)
    result=localExperiment(testCase,"cancel");
    verifyEqual(testCase,result.status,"cancelled");
    verifyEmpty(testCase,result.time);
    verifyEmpty(testCase,result.shutdownErrors);
end

function testOdometryLossStopsAndEndsRun(testCase)
    result=localExperiment(testCase,"dropout");
    verifyEqual(testCase,result.status,"odometry_lost");
    verifyTrue(testCase,any(result.commands(:,1,1)>0));
    verifyEqual(testCase,result.commands(end,:,1),[0 0]);
    verifyTrue(testCase,all(result.sent(end,:)));
    verifyEmpty(testCase,result.shutdownErrors);
end

function result=localExperiment(testCase,action)
    folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    config=station_config();
    text=fileread(config.vehicleFile);
    probe=udpport("datagram","IPV4");
    odomPort=probe.LocalPort;
    probe2=udpport("datagram","IPV4");
    localPort=probe2.LocalPort;
    target=udpport("datagram","IPV4");
    tx=udpport("datagram","IPV4","ByteOrder","big-endian");
    text=strrep(text,'12345,23456,34567,127.0.0.1', ...
        sprintf('%d,%d,%d,127.0.0.1',odomPort,localPort,target.LocalPort));
    config.vehicleFile=fullfile(folder,'vehicles.csv');
    fid=fopen(config.vehicleFile,'w');
    fwrite(fid,text);
    fclose(fid);
    config.logDirectory=folder;
    config.durationSeconds=1;
    config.connectionTimeoutSeconds=2;
    config.odometryTimeoutSeconds=0.15;
    delete(probe);
    delete(probe2);
    visible=get(groot,'defaultFigureVisible');
    set(groot,'defaultFigureVisible','off');
    restore=onCleanup(@() set(groot,'defaultFigureVisible',visible));
    state=containers.Map({'started','seq'},{[],0});
    heartbeat=timer('ExecutionMode','fixedSpacing','Period',0.02, ...
        'TimerFcn',@(~,~) tick(tx,odomPort,state,action));
    cleaner=onCleanup(@() release(heartbeat,tx,target));
    start(heartbeat);
    result=main("experiment",Vehicles="katchaka",Config=config,Controller=@moving);
    stop(heartbeat);
end

function tick(tx,port,state,action)
    started=state('started');
    if isempty(started) || toc(started)<0.15
        state('seq')=state('seq')+1;
        write(tx,[state('seq') 0 0],"double","127.0.0.1",port);
    end
    windows=findall(groot,'Type','figure','Name','Control station');
    if isempty(windows), return; end
    window=windows(1);
    if action=="cancel"
        close(window);
    elseif isempty(started)
        button=findobj(window,'String','Start');
        if isempty(button), return; end
        callback=get(button,'Callback');
        callback(button,[]);
        state('started')=tic();
    end
end

function commands=moving(vehicles)
    commands=ControllerStop(vehicles);
    commands.katchaka=[0.1 0];
end

function release(heartbeat,tx,target)
    stop(heartbeat);
    delete(heartbeat);
    delete(tx);
    delete(target);
end
