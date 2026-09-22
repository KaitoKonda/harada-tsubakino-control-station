function config = motive_config
%MOTIVE_CONFIG Site-specific settings for the Motive to ROS bridge.
%
% Keep serverIP and clientIP empty until the facility network is known.
% clientIP is the laptop address on the WIRED Motive network. rosNodeHost is
% the laptop address on the Wi-Fi/rover network; these are normally different.

    config.serverIP = "";
    config.clientIP = "";
    config.motiveVersion = ""; % Documentation only; NatNet negotiates the protocol.
    config.connectionType = "Unicast";

    config.rosMasterURI = "http://localhost:11311";
    config.rosNodeHost = "192.168.11.53";
    config.pollRateHz = 120;
    config.frameId = "mocap";

    % Publish the controller-facing localization estimate. This is separate
    % from the rover's onboard OTOS sensor topic.
    config.rigidBodies = struct( ...
        'name', {"pi1", "pi2", "pi3"}, ...
        'id', {NaN, NaN, NaN}, ...
        'topic', {"/pi1/localization/odom", "/pi2/localization/odom", "/pi3/localization/odom"}, ...
        'childFrameId', {"pi1/base_link", "pi2/base_link", "pi3/base_link"});
end
