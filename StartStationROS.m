function StartStationROS(config)
%STARTSTATIONROS Start/reuse only a ROS session with known matching settings.
% Call this helper for preflight topic inspection, then call main in the same session.
    persistent activeConfig
    try
        rosinit(char(config.masterURI), 'NodeHost', char(config.nodeHost));
        activeConfig = config;
    catch exception
        try
            rosnode('list');
        catch
            rethrow(exception)
        end
        assert(~isempty(activeConfig) && isequal(activeConfig,config), ...
            'Station:ROSConfigMismatch', ...
            'Existing ROS settings are unknown or different. Run rosshutdown, then StartStationROS(config.ros).');
    end
end
