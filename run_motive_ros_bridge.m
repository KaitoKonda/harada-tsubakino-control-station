function run_motive_ros_bridge(config)
%RUN_MOTIVE_ROS_BRIDGE Run the Motive-to-ROS bridge until interrupted.
%
%   run_motive_ros_bridge
%   run_motive_ros_bridge(config)

    if nargin < 1
        config = motive_config();
    end

    if strlength(config.serverIP) == 0 || strlength(config.clientIP) == 0
        error('MotiveRosBridge:NetworkNotConfigured', ...
            ['Set serverIP (Motive PC) and clientIP (this laptop''s wired Motive-network IP) ' ...
             'in motive_config.m before connecting.'])
    end

    startedRosHere = false;
    try
        rosinit(char(config.rosMasterURI), 'NodeHost', char(config.rosNodeHost));
        startedRosHere = true;
    catch exception
        % Reuse a working global ROS node, but do not hide real startup errors.
        try
            rosnode('list');
            warning('Reusing the existing MATLAB ROS node. motive_config.m was not reapplied.')
        catch
            rethrow(exception)
        end
    end

    bridge = MotiveRosBridge(config);
    cleanup = onCleanup(@() localCleanup(bridge, startedRosHere));
    rate = rosrate(config.pollRateHz);

    fprintf('Motive bridge connected: %s -> ROS (%s)\n', ...
        config.serverIP, config.rosNodeHost);
    fprintf('Press Ctrl+C to stop.\n');
    while true
        bridge.update();
        waitfor(rate);
    end
end

function localCleanup(bridge, startedRosHere)
    delete(bridge);
    if startedRosHere
        try
            rosshutdown;
        catch
        end
    end
end
