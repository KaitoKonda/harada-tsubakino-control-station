function result = main(mode, options)
%MAIN One entry point for simulated and physical vehicles.
% main("simulation")
% main("experiment", Vehicles="pi1")
% result = main("simulation", ShowUI=false, RealTime=false, Duration=2)
    arguments
        mode (1,1) string {mustBeMember(mode,["simulation","experiment"])} = "simulation"
        options.Vehicles string = strings(0,1)
        options.Config (1,1) struct = station_config()
        options.Controller = []
        options.Duration = []
        options.ShowUI (1,1) logical = true
        options.RealTime (1,1) logical = true
        options.Log (1,1) logical = true
    end
    config=options.Config;
    if ~isempty(options.Controller), config.controller=options.Controller; end
    if ~isempty(options.Duration), config.durationSeconds=options.Duration; end
    ValidateStationConfig(config);
    assert(mode=="simulation" || (options.ShowUI && options.RealTime), ...
        'Station:ExperimentUIRequired','Physical experiments require the start/stop window and real-time pacing.');
    settings=LoadVehicleSettings(config.vehicleFile,options.Vehicles);
    controller=config.controller;
    names=string({settings.name});
    result=struct('mode',mode,'startedAt',string(datetime('now')), ...
        'configuration',config,'vehicleSettings',settings,'vehicleNames',names, ...
        'status',"starting",'error',"",'time',zeros(0,1), ...
        'states',zeros(0,5,numel(names)),'commands',zeros(0,2,numel(names)), ...
        'fresh',false(0,numel(names)),'sent',false(0,numel(names)), ...
        'shutdownErrors',strings(0,1),'logFile',"");
    result.configuration.controller=string(func2str(controller));
    result.stateColumns=["x","y","yaw","speed","angularVelocity"];
    result.commandColumns=["speed","angularVelocity"];
    if options.Log
        if ~isfolder(config.logDirectory), mkdir(config.logDirectory); end
        result.logFile=string(tempname(config.logDirectory))+".mat";
    end
    window=[];
    session=StationRun(result,options.Log);
    cleanup=onCleanup(@() session.finish());
    try
        usesROS=any([settings.odometryProtocol]=="ROS" | [settings.commandProtocol]=="ROS");
        if mode=="experiment" && usesROS
            StartStationROS(config.ros);
        end
        vehicles=RegisterVehicles(settings,mode,config.odometryTimeoutSeconds);
        session.vehicles=vehicles;
        EstablishConnection(vehicles,config);
        Calibrate(vehicles);
        if options.ShowUI
            window=createWindow(mode,names);
            session.window=window;
        end
        if mode=="experiment"
            session.result.status="standby";
            previous=tic;
            while ~isStarted(window)
                if isStopped(window)
                    session.result.status="cancelled";
                    session.finish();
                    result=session.result;
                    return
                end
                dt=toc(previous);
                previous=tic;
                errors=StopVehicles(vehicles);
                assert(isempty(errors),'Station:StopFailed','Could not maintain zero commands in standby.');
                for name=names
                    vehicles.(name).update(dt);
                end
                pause(1/config.rateHz);
            end
        end
        session.result.status="running";
        period=1/config.rateHz;
        elapsed=0;
        clock=tic;
        nextReport=0;
        step=0;
        while elapsed<config.durationSeconds
            stepClock=tic;
            if options.ShowUI && isStopped(window)
                session.result.status="stopped";
                break
            end
            if mode=="simulation"
                dt=min(period,config.durationSeconds-elapsed);
                elapsed=elapsed+dt;
            else
                now=toc(clock);
                dt=now-elapsed;
                elapsed=now;
            end
            step=step+1;
            session.result.time(step,1)=elapsed;
            session.result.sent(step,:)=false;
            session.result.commands(step,:,:)=zeros(1,2,numel(names));
            for i=1:numel(names)
                vehicle=vehicles.(names(i));
                session.result.fresh(step,i)=vehicle.update(dt);
                session.result.states(step,:,i)=vehicle.snapshot();
            end
            if all(session.result.fresh(step,:))
                commands=ValidateCommands(controller(vehicles),vehicles,config);
            else
                % A dropout ends the run; restoration cannot restart motion.
                commands=ControllerStop(vehicles);
                session.result.status="odometry_lost";
                session.result.error="No fresh odometry from: "+strjoin(names(~session.result.fresh(step,:)),", ");
            end
            for i=1:numel(names)
                session.result.commands(step,:,i)=commands.(names(i));
            end
            for i=1:numel(names)
                vehicles.(names(i)).send(commands.(names(i)));
                session.result.sent(step,i)=true;
            end
            if session.result.status=="odometry_lost", break; end
            if elapsed>=nextReport
                fprintf('%s: %.1f / %.1f s (%d vehicles)\n',mode,elapsed,config.durationSeconds,numel(names));
                nextReport=elapsed+1;
            end
            if options.RealTime
                pause(max(0,period-toc(stepClock)));
            else
                drawnow limitrate;
            end
        end
        if session.result.status=="running", session.result.status="completed"; end
    catch exception
        session.result.status="error";
        session.result.error=string(exception.identifier)+": "+string(exception.message);
        session.finish();
        rethrow(exception)
    end
    session.finish();
    result=session.result;

end

function window=createWindow(mode,names)
    window=figure('Name','Control station','NumberTitle','off', ...
        'MenuBar','none','ToolBar','none','Position',[200 200 480 180], ...
        'CloseRequestFcn',@(src,~) setappdata(src,'stop',true));
    setappdata(window,'stop',false);
    setappdata(window,'started',mode=="simulation");
    uicontrol(window,'Style','text','Position',[20 135 440 25], ...
        'String',char(mode+" | "+strjoin(names,", ")));
    if mode=="experiment"
        guidance='Startで制御を開始します。Stopまたは窓を閉じると中止します。';
    else
        guidance='シミュレーション実行中です。Stopまたは窓を閉じると停止します。';
    end
    uicontrol(window,'Style','text','Position',[20 85 440 40],'String',guidance);
    start=uicontrol(window,'Style','pushbutton','String','Start', ...
        'Position',[60 25 140 45],'Callback',@(src,~) beginRun(src,window));
    if mode=="simulation", set(start,'Enable','off'); end
    uicontrol(window,'Style','pushbutton','String','Stop', ...
        'Position',[240 25 140 45],'Callback',@(~,~) setappdata(window,'stop',true));
end

function beginRun(button,window)
    setappdata(window,'started',true);
    set(button,'Enable','off');
end

function stopped=isStopped(window)
    drawnow limitrate;
    stopped=~isgraphics(window) || getappdata(window,'stop');
end

function started=isStarted(window)
    started=isgraphics(window) && getappdata(window,'started');
end
