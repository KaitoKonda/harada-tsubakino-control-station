function launch_dummy_vehicles(managerIP, desktopIP, masterURI, rateHz)
% LAUNCH_DUMMY_VEHICLES Start dummy vehicles from vehicles.xlsx settings.
% Each dummy is launched in a separate MATLAB process so multiple vehicles
% can run concurrently.
%
% Example:
%   launch_dummy_vehicles("127.0.0.1","192.168.24.26","http://localhost:11311",20)

    if nargin < 1 || strlength(managerIP) == 0
        managerIP = "127.0.0.1";
    end
    if nargin < 2 || strlength(desktopIP) == 0
        desktopIP = "192.168.24.26";
    end
    if nargin < 3 || strlength(masterURI) == 0
        masterURI = "http://localhost:11311";
    end
    if nargin < 4 || isempty(rateHz)
        rateHz = 20;
    end

    settings = readmatrix("vehicles.xlsx", "OutputType", "string", "Range", "A2");
    if isempty(settings)
        error("No vehicle settings found in vehicles.xlsx")
    end

    cwd = pwd;
    launched = 0;

    for i = 1:size(settings, 1)
        vehicleName = settings(i, 1);
        protocol = settings(i, 2);
        odometryType = settings(i, 3);
        args = settings(i, 7:end);

        switch protocol
            case "UDP"
                odometryPort = double(args(1));

                % New format:
                % arg1=UDPReceiverPort, arg2=UDPSenderLocalPort, arg3=UDPCommandTargetPort, arg4=VehicleIP
                % Old format:
                % arg1=UDPReceiverPort, arg2=UDPSenderPort(as both local and target), arg3=VehicleIP
                if numel(args) >= 4 && strlength(args(4)) > 0
                    commandPort = double(args(3));
                else
                    commandPort = double(args(2));
                end

                runExpr = sprintf([ ...
                    'try; cd(''%s''); dummy_udp_vehicle(''%s'',%d,%d,''%s'',%g);' ...
                    ' catch ME; disp(getReport(ME,''extended'')); end'], ...
                    escapeQuote(cwd), escapeQuote(managerIP), odometryPort, commandPort, ...
                    escapeQuote(odometryType), rateHz);

                launchOne(vehicleName, runExpr);
                launched = launched + 1;

            case "ROS"
                odomTopicSuffix = args(1);
                commandTopicSuffix = args(2);
                messageType = args(3);

                runExpr = sprintf([ ...
                    'try; cd(''%s''); dummy_ros_vehicle(''%s'',''%s'',''%s'',''%s'',''%s'',%g,''%s'',''%s'');' ...
                    ' catch ME; disp(getReport(ME,''extended'')); end'], ...
                    escapeQuote(cwd), escapeQuote(vehicleName), escapeQuote(odomTopicSuffix), ...
                    escapeQuote(commandTopicSuffix), escapeQuote(odometryType), ...
                    escapeQuote(messageType), rateHz, escapeQuote(desktopIP), escapeQuote(masterURI));

                launchOne(vehicleName, runExpr);
                launched = launched + 1;

            otherwise
                fprintf("Skip %s: unsupported protocol %s\n", vehicleName, protocol);
        end
    end

    fprintf("Launched %d dummy vehicle process(es).\n", launched);
end

function launchOne(vehicleName, runExpr)
    if ispc
        cmd = sprintf('start "dummy_%s" matlab -nosplash -nodesktop -r "%s"', ...
            char(vehicleName), runExpr);
    else
        cmd = sprintf('matlab -nosplash -nodesktop -r "%s" &', runExpr);
    end
    [status, out] = system(cmd);
    if status ~= 0
        error("Failed to launch dummy for %s: %s", vehicleName, out)
    end
end

function out = escapeQuote(in)
    out = strrep(char(in), '''', '''''');
end
