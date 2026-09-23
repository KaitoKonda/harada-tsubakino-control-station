function run_motive_ros_bridge(config, station)
%RUN_MOTIVE_ROS_BRIDGE Publish Motive poses until Ctrl+C.
% run_motive_ros_bridge(motive_config(), station_config())
    if nargin<1, config=motive_config(); end
    if nargin<2, station=station_config(); end
    if strlength(config.serverIP)==0 || strlength(config.clientIP)==0
        error('MotiveRosBridge:NetworkNotConfigured', ...
            'Set serverIP (Motive PC) and clientIP (control PC wired address) in motive_config.m.')
    end
    if isempty(config.rigidBodies)
        config.rigidBodies=MotiveMappings(LoadVehicleSettings(station.vehicleFile));
    end
    StartStationROS(station.ros);
    bridge=MotiveRosBridge(config);
    cleanup=onCleanup(@() delete(bridge));
    fprintf('Motive bridge connected: %s -> ROS (%s). Press Ctrl+C to stop.\n', ...
        config.serverIP,station.ros.nodeHost);
    while true
        step=tic;
        bridge.update();
        pause(max(0,1/config.pollRateHz-toc(step)));
    end
    % The shared ROS master stays alive. Run rosshutdown after all users stop.
end
