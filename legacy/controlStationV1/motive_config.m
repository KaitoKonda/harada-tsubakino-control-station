function config = motive_config
%MOTIVE_CONFIG Only NatNet/Motive settings. Shared ROS settings live in station_config.
    config.serverIP = ""; % Motive PC, facility LAN
    config.clientIP = ""; % Control PC, wired facility LAN (not rover Wi-Fi)
    config.motiveVersion = ""; % Record only; NatNet negotiates its protocol.
    config.connectionType = "Unicast";
    config.pollRateHz = 120;
    config.frameId = "mocap";
    % Empty means derive enabled Motive mappings from vehicles.csv.
    % Set explicitly only for a temporary standalone bridge test.
    config.rigidBodies = [];
end
