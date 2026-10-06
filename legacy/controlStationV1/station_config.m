function config = station_config
%STATION_CONFIG Shared settings. Paths are relative to this repository.
% Edit ros.nodeHost to the control PC address reachable from the rover network.
    root = fileparts(mfilename('fullpath'));
    config.vehicleFile = fullfile(root, 'vehicles.csv');
    config.ros.masterURI = "http://localhost:11311";
    config.ros.nodeHost = "192.168.11.53";
    config.rateHz = 20;
    config.durationSeconds = 250;
    config.connectionTimeoutSeconds = 5;
    config.odometryTimeoutSeconds = 0.25;
    config.controller = @ControllerStop;
    % Application limits, not a substitute for vehicle-specific limits.
    config.maxSpeed = 0.2;
    config.maxAngularVelocity = 0.5;
    config.logDirectory = fullfile(root, 'logs');
end
