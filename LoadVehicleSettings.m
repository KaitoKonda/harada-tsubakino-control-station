function settings = LoadVehicleSettings(filename, selectedNames)
%LOADVEHICLESETTINGS Read and validate the single named vehicle registry.
    if nargin < 2
        selectedNames = strings(0,1);
    end
    expected = ["name","enabled","odometryProtocol","commandProtocol", ...
        "odometryType","coordinateMode","x0","y0","theta0","odometryTopic", ...
        "odometryMessageType","commandTopic","odometryPort","commandLocalPort", ...
        "commandTargetPort","vehicleIP","motiveName","motiveId"];
    opts = detectImportOptions(filename, 'TextType','string', 'VariableNamingRule','preserve');
    assert(all(ismember(expected, string(opts.VariableNames))), ...
        'Station:InvalidSettings', 'Vehicle registry is missing required named columns.');
    opts = setvartype(opts, cellstr(expected), 'string');
    rows = readtable(filename, opts);
    rows = rows(:, cellstr(expected));
    rows = standardizeMissing(rows, "");
    names = rows.name;
    assert(~isempty(names) && all(~ismissing(names)) && ...
        all(arrayfun(@(n) isvarname(char(n)), names)) && numel(unique(names)) == numel(names), ...
        'Station:InvalidSettings', 'Vehicle names must be unique valid MATLAB names.');
    enabled = str2double(rows.enabled);
    assert(all(ismember(enabled,[0 1])), 'Station:InvalidSettings', 'enabled must be 0 or 1.');
    settings = struct([]);
    % Validate every row before opening any communication resources.
    for k = 1:height(rows)
        s = struct();
        for field = expected
            value = rows.(field)(k);
            if ismissing(value)
                value = "";
            end
            s.(field) = value;
        end
        s.enabled = logical(enabled(k));
        s.initialPose = str2double([s.x0 s.y0 s.theta0]);
        s = rmfield(s, {'x0','y0','theta0'});
        assert(all(isfinite(s.initialPose)), 'Station:InvalidSettings', ...
            'Initial pose must contain finite numbers for %s.', s.name);
        assert(ismember(s.odometryProtocol,["ROS","UDP"]) && ...
            ismember(s.commandProtocol,["ROS","UDP"]), 'Station:InvalidSettings', ...
            'Only ROS and UDP are supported for %s.', s.name);
        assert(ismember(s.odometryType,["position&orientation","speed&angularVelocity"]), ...
            'Station:InvalidSettings', 'Unsupported odometry type for %s.', s.name);
        assert(ismember(s.coordinateMode,["global","initial"]), 'Station:InvalidSettings', ...
            'coordinateMode must be global or initial for %s.', s.name);
        assert(s.odometryType ~= "speed&angularVelocity" || s.coordinateMode == "initial", ...
            'Station:InvalidSettings', 'Velocity integration requires initial coordinates for %s.', s.name);
        if s.odometryProtocol == "ROS"
            validTopic(s.odometryTopic, s.name);
            types = "nav_msgs/Odometry";
            if s.odometryType == "speed&angularVelocity"
                types = ["nav_msgs/Odometry","geometry_msgs/Twist"];
            end
            assert(ismember(s.odometryMessageType,types), 'Station:InvalidSettings', ...
                'Message type cannot supply the configured odometry for %s.', s.name);
        end
        if s.commandProtocol == "ROS"
            validTopic(s.commandTopic, s.name);
        end
        motiveIdText=s.motiveId;
        for field = ["odometryPort","commandLocalPort","commandTargetPort","motiveId"]
            s.(field) = str2double(s.(field));
        end
        if s.odometryProtocol == "UDP"
            validPort(s.odometryPort, s.name);
        end
        if s.commandProtocol == "UDP"
            validPort(s.commandLocalPort, s.name);
            validPort(s.commandTargetPort, s.name);
            assert(strlength(s.vehicleIP)>0, 'Station:InvalidSettings', ...
                'vehicleIP is required for %s.', s.name);
        end
        assert(strlength(motiveIdText)==0 || (isfinite(s.motiveId) && s.motiveId>=0 && ...
            fix(s.motiveId)==s.motiveId), 'Station:InvalidSettings', 'Invalid Motive ID for %s.',s.name);
        if strlength(s.motiveName)>0 || ~isnan(s.motiveId)
            assert(s.odometryProtocol=="ROS" && s.odometryType=="position&orientation", ...
                'Station:InvalidSettings', 'Motive requires ROS position input for %s.',s.name);
        end
        if k==1
            settings=s;
        else
            settings(k)=s;
        end
    end
    selectedNames = string(selectedNames(:));
    if isempty(selectedNames)
        settings = settings([settings.enabled]);
    else
        assert(numel(unique(selectedNames))==numel(selectedNames) && ...
            all(ismember(selectedNames,names)), 'Station:UnknownVehicle', ...
            'Requested vehicle names must exist and be unique.');
        [~, indexes] = ismember(selectedNames,names);
        settings = settings(indexes);
    end
    assert(~isempty(settings), 'Station:NoVehicles', 'No vehicles selected.');
    ports = [];
    commandTopics = strings(0,1);
    for s = settings
        if s.odometryProtocol == "UDP"
            ports(end+1) = s.odometryPort; %#ok<AGROW>
        end
        if s.commandProtocol == "UDP"
            ports(end+1) = s.commandLocalPort; %#ok<AGROW>
        else
            commandTopics(end+1) = s.commandTopic; %#ok<AGROW>
        end
    end
    assert(numel(unique(ports))==numel(ports), 'Station:InvalidSettings', ...
        'Selected vehicles reuse a local UDP port.');
    assert(numel(unique(commandTopics))==numel(commandTopics), 'Station:InvalidSettings', ...
        'Selected vehicles reuse a command topic.');
end

function validTopic(topic, name)
    assert(strlength(topic)>1 && startsWith(topic,"/") && ...
        isempty(regexp(char(topic),'[^a-zA-Z0-9_/]','once')), ...
        'Station:InvalidSettings', 'Use an absolute ROS topic for %s.', name);
end

function validPort(port, name)
    assert(isfinite(port) && port>=1 && port<=65535 && fix(port)==port, ...
        'Station:InvalidSettings', 'Invalid UDP port for %s.', name);
end
